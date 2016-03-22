//
//  SDFChannel.m
//  SDF
//
//  Created by mconintet on 3/18/16.
//  Copyright © 2016 mconintet. All rights reserved.
//

#import "Log.h"
#import "SDFChannel.h"
#import "TCPServer.h"
#import <fcntl.h>

ssize_t reply(int sock, SDFCommand* cmd, REP_FIELD repf)
{
    UInt8 rep[] = {
        SOCKS_VER, repf, 0,
    };
    NSMutableData* d = [[NSMutableData alloc] initWithBytes:rep length:sizeof(rep)];

    if (cmd) {
        UInt8 atyp = cmd.atyp;
        [d appendBytes:&atyp length:1];

        if (ADDR_TYPE_DOMAIN == cmd.atyp) {
            const char* str = [cmd.addr UTF8String];
            UInt8 len = strlen(str);
            [d appendBytes:&len length:1];
            [d appendBytes:str length:len];
        }
        else if (ADDR_TYPE_IP4 == cmd.atyp) {
            struct in_addr addr;
            inet_pton(AF_INET, [cmd.addr UTF8String], &addr);
            [d appendBytes:&addr length:sizeof(addr)];
        }
        else if (ADDR_TYPE_IP6 == cmd.atyp) {
            struct in_addr addr;
            inet_pton(AF_INET6, [cmd.addr UTF8String], &addr);
            [d appendBytes:&addr length:sizeof(addr)];
        }
        UInt8 buf[2];
        buf[0] = cmd.port >> 8;
        buf[0] = cmd.port;
        [d appendBytes:buf length:2];
    }
    else {
        UInt8 buf[] = { ADDR_TYPE_IP4, 0, 0, 0, 0, 0, 0 };
        [d appendBytes:buf length:sizeof(buf)];
    }

    return send(sock, d.bytes, d.length, 0);
}

@implementation SDFCommand

@end

@interface SDFChannel ()

@property (nonatomic, assign) NSUInteger ID;

@property (nonatomic, weak) SDFServer* server;
@property (nonatomic, assign) int leftSock;
@property (nonatomic, assign) ssh_session sshSession;

@property (nonatomic, strong) SDFCommand* command;
@property (nonatomic, assign) ssh_channel sshChannel;

@end

@implementation SDFChannel

- (instancetype)initWithID:(NSUInteger)ID
                    server:(SDFServer*)server
                  leftSock:(int)leftSock;
{
    self = [super init];
    if (!self) {
        return nil;
    }

    _ID = ID;
    _server = server;
    _leftSock = leftSock;

    return self;
}

- (void)main
{
#pragma mark Handshake
    NSString* tag = [NSString stringWithFormat:@"[Handshake#%ld(%@)]", _ID, sockAddr(_leftSock)];
    LOGDEBUG(@"%@: BEGIN", tag);

    UInt8 buf[512] = { 0 };

    ssize_t len = recv(_leftSock, buf, 2, 0);
    if (2 != len) {
        LOGERR(@"%@: cannot read left sock", tag);
        goto _stop;
    }

    if (SOCKS_VER != buf[0]) {
        LOGERR(@"%@: unsupported version %d", tag, buf[0]);
        goto _stop;
    }

    int methodsCount = buf[1];
    len = recv(_leftSock, buf, methodsCount, 0);
    if (len != methodsCount) {
        LOGERR(@"%@: methods count does not math given", tag);
        goto _stop;
    }

    BOOL hasAuthMethod = NO;
    for (int i = 0; i < methodsCount; i++) {
        if (AUTH_TYPE_NOAUTH == buf[i]) {
            hasAuthMethod = YES;
            break;
        }
    }

    if (!hasAuthMethod) {
        LOGERR(@"%@: client does not support *AUTH_TYPE_NOAUTH*", tag);
        goto _stop;
    }

    UInt8 b[] = { SOCKS_VER, AUTH_TYPE_NOAUTH };
    len = send(_leftSock, b, 2, 0);
    if (2 != len) {
        LOGERR(@"%@: cannot send reply");
        goto _stop;
    }

    LOGDEBUG(@"%@: OK", tag);

#pragma mark ParseCMD
    tag = [NSString stringWithFormat:@"[ParseCMD#%ld(%@)]", _ID, sockAddr(_leftSock)];
    LOGDEBUG(@"%@: BEGIN", tag);

    len = recv(_leftSock, buf, 4, 0);
    if (4 != len) {
        LOGERR(@"%@: cannot read left sock", tag);
        goto _stop;
    }

    if (SOCKS_VER != buf[0]) {
        LOGERR(@"%@: unsupport version %d", tag, buf[0]);
        goto _stop;
    }

    if (CMD_TYPE_CONNECT != buf[1]) {
        LOGERR(@"%@: unsupport command type %d", tag, buf[1]);
        goto _stop;
    }

    if (0 != buf[2]) {
        LOGERR(@"%@: invalid RSV %d", tag, buf[2]);
        goto _stop;
    }

    _command = [[SDFCommand alloc] init];
    _command.type = CMD_TYPE_CONNECT;

    switch (buf[3]) {
    case ADDR_TYPE_IP4: {
        _command.atyp = ADDR_TYPE_IP4;

        len = recv(_leftSock, buf, 6, 0);
        if (6 != len) {
            LOGERR(@"%@: cannot read ipv4 address");
            goto _stop;
        }

        char str[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, buf, str, INET_ADDRSTRLEN);
        _command.addr = [NSString stringWithCString:str encoding:NSASCIIStringEncoding];

        _command.port = (UInt16)buf[4] << 8 | buf[5];
    } break;
    case ADDR_TYPE_DOMAIN: {
        _command.atyp = ADDR_TYPE_DOMAIN;

        len = recv(_leftSock, buf, 1, 0);
        if (1 != len) {
            LOGERR(@"%@: cannot read domain len", tag);
            goto _stop;
        }

        int strLen = buf[0];
        len = recv(_leftSock, buf, strLen + 2, 0);
        if (len != strLen + 2) {
            LOGERR(@"%@: cannot read domain", tag);
            goto _stop;
        }
        if (MAX_DOMAIN_LEN < strLen) {
            LOGERR(@"%@: domain too large - %d", tag, strLen);
            goto _stop;
        }

        char* str = (char*)calloc(strLen + 1, sizeof(char));
        memcpy(str, buf, strLen);
        _command.addr = [NSString stringWithCString:str encoding:NSUTF8StringEncoding];
        if (_command.addr == nil) {
            LOGERR(@"%@: deformed domain");
            goto _stop;
        }

        _command.port = (UInt16)buf[strLen] << 8 | buf[strLen + 1];
    } break;
    case ADDR_TYPE_IP6: {
        _command.atyp = ADDR_TYPE_IP6;

        len = recv(_leftSock, buf, 18, 0);
        if (18 != len) {
            LOGERR(@"%@: cannot read ipv6", tag);
            goto _stop;
        }

        char str[INET6_ADDRSTRLEN];
        inet_ntop(AF_INET6, buf, str, INET6_ADDRSTRLEN);
        _command.addr = [NSString stringWithCString:str encoding:NSUTF8StringEncoding];

        _command.port = (UInt16)buf[16] << 8 | buf[17];
    } break;
    default: {
        LOGERR(@"%@: unsupported address type");
        goto _stop;
    } break;
    }

    if (-1 == reply(_leftSock, _command, REP_FIELD_SUCCEEDED)) {
        LOGERR(@"%@: cannot send reply");
        goto _stop;
    }
    LOGDEBUG(@"%@: OK", tag);

#pragma mark Connect to SSH server
    if (NO == [self connectSSHServer]) {
        goto _stop;
    }

#pragma mark New channel
    tag = [NSString stringWithFormat:@"[NewSSHChannel#%ld(%@)]", _ID, sockAddr(_leftSock)];
    LOGDEBUG(@"%@: BEGIN to [%@:%d]", tag, _command.addr, _command.port);

    _sshChannel = ssh_channel_new(_sshSession);
    if (NULL == _sshChannel) {
        LOGERR(@"%@: cannot new ssh channel", tag);
        reply(_leftSock, _command, REP_FIELD_GENERAL_SERVER_FAILURE);
        goto _stop;
    }

    const char* addr = [_command.addr UTF8String];
    const char* host = [_server.host UTF8String];
    LOGDEBUG(@"%@: ssh_channel_open_forward [%s:%d] to [%s:%d]",
        tag, addr, _command.port, host, _server.port);

    while (1) {
        int rc = ssh_channel_open_forward(_sshChannel, addr,
            _command.port, host, _server.port);

        if (SSH_OK != rc) {
            if (SSH_AGAIN == rc) {
                continue;
            }
            else {
                LOGERR(@"%@: cannot open forward ssh channel - %s", tag, ssh_get_error(_sshSession));
                reply(_leftSock, _command, REP_FIELD_GENERAL_SERVER_FAILURE);
                goto _stop;
            }
        }
        else {
            break;
        }
    }

    if (!ssh_channel_is_open(_sshChannel)) {
        LOGERR(@"%@: channel is not open", tag);
        goto _stop;
    }
    LOGDEBUG(@"%@: OK", tag);

#pragma mark Exchange
    tag = [NSString stringWithFormat:@"[Exchange#%ld(%@)]", _ID, sockAddr(_leftSock)];
    LOGDEBUG(@"%@: BEGIN", tag);

    int flags = fcntl(_leftSock, F_GETFL, 0);
    if (-1 == flags) {
        LOGERR(@"%@: cannot get left sock flags");
        reply(_leftSock, _command, REP_FIELD_GENERAL_SERVER_FAILURE);
        goto _stop;
    }

    flags |= O_NONBLOCK;
    if (-1 == fcntl(_leftSock, F_SETFL, flags)) {
        LOGERR(@"%@: cannot set left sock to non-blocking");
        reply(_leftSock, _command, REP_FIELD_GENERAL_SERVER_FAILURE);
        goto _stop;
    }

    struct fd_set readfds;

    struct timeval tv;
    tv.tv_sec = 1;
    tv.tv_usec = 0;

    int maxfd = _leftSock;
    int sshfd = ssh_get_fd(_sshSession);
    if (maxfd < sshfd) {
        maxfd = sshfd;
    }

    while (1) {
        FD_ZERO(&readfds);

        FD_SET(_leftSock, &readfds);
        FD_SET(sshfd, &readfds);

        int len = select(maxfd + 1, &readfds, NULL, NULL, &tv);
        if (-1 == len) {
            LOGERR(@"%@: error occur when select %s", tag, strerror(errno));
            goto _stop;
        }

        if (len == 0) {
            continue;
        }

        if (FD_ISSET(_leftSock, &readfds)) {
            while (1) {
                UInt8 buf[512];
                ssize_t len = recv(_leftSock, buf, sizeof(buf), 0);
                if (0 == len) {
                    LOGDEBUG(@"%@: closed by left", tag);
                    goto _stop;
                }
                else if (-1 == len) {
                    if (EAGAIN == errno) {
                        break;
                    }
                    else {
                        LOGDEBUG(@"%@: error occur when read left - %s", tag, strerror(errno));
                        goto _stop;
                    }
                }
                else {
                    if (SSH_ERROR == ssh_channel_write(_sshChannel, buf, (uint32_t)len)) {
                        LOGERR(@"%@: cannot write to ssh channel - %s", tag, ssh_get_error(_sshSession));
                        goto _stop;
                    }
                }
            }
        }

        if (FD_ISSET(sshfd, &readfds)) {
            while (1) {
                UInt8 buf[512];
                int len = ssh_channel_read_nonblocking(_sshChannel, buf, sizeof(buf), 0);
                if (SSH_AGAIN == len || 0 == len) {
                    break;
                }
                else if (SSH_ERROR == len) {
                    LOGDEBUG(@"%@: error occur when read channel - %s", tag, ssh_get_error(_sshSession));
                    goto _stop;
                }
                else if (send(_leftSock, buf, (uint32_t)len, 0) < 0) {
                    LOGERR(@"%@: cannot write to left sock - %s", tag, strerror(errno));
                    goto _stop;
                }

                if (ssh_channel_is_eof(_sshChannel)) {
                    LOGDEBUG(@"%@: closed by ssh server", tag);
                    goto _stop;
                }
            }
        }

        if (ssh_channel_is_closed(_sshChannel)) {
            LOGDEBUG(@"%@: ssh channel is closed", tag);
            goto _stop;
        }
    }
_stop:
    [self stop];
}

- (BOOL)connectSSHServer
{
    NSString* tag = [NSString stringWithFormat:@"[ConnectToSSH#%ld(%@:%d)]",
                              _ID, _server.sshHost, _server.sshPort];
    LOGDEBUG(@"%@: BEGIN", tag);

    _sshSession = ssh_new();
    if (NULL == _sshSession) {
        LOGERR(@"%@: Cannot create SSH session - %s", tag, ssh_get_error(_sshSession));
        return NO;
    }

    ssh_options_set(_sshSession, SSH_OPTIONS_HOST, [_server.sshHost UTF8String]);
    UInt16 port = _server.sshPort;
    ssh_options_set(_sshSession, SSH_OPTIONS_PORT, &port);
    ssh_options_set(_sshSession, SSH_OPTIONS_USER, [_server.sshUsername UTF8String]);

    int rc = ssh_connect(_sshSession);
    if (SSH_OK != rc) {
        LOGERR(@"%@: Cannot connect to SSH server - %s", tag, ssh_get_error(_sshSession));
        [self stop];
        return NO;
    }

    rc = ssh_userauth_password(_sshSession, NULL, [_server.sshPasswd UTF8String]);
    if (SSH_AUTH_ERROR == rc) {
        LOGERR(@"%@: Authentication failed - %s", tag, ssh_get_error(_sshSession));
        return NO;
    }

    ssh_set_blocking(_sshSession, 0);
    LOGDEBUG(@"%@: OK", tag);
    return YES;
}

- (void)stop
{
    NSString* tag = [NSString stringWithFormat:@"Channel#%lu(%@)", (unsigned long)_ID, sockAddr(_leftSock)];
    LOGDEBUG(@"%@ stopping...", tag);
    if (_leftSock != -1) {
        close(_leftSock);
        _leftSock = -1;
    }
    if (_sshSession) {
        ssh_disconnect(_sshSession);
        ssh_free(_sshSession);
        _sshSession = NULL;
    }
    LOGDEBUG(@"%@ stopped", tag);
}

@end
