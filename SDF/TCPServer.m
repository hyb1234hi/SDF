//
//  TCPServer.m
//  SDF
//
//  Created by mconintet on 3/18/16.
//  Copyright © 2016 mconintet. All rights reserved.
//

#import "Log.h"
#import "TCPServer.h"

NSString* sockAddr(int sock)
{
    struct sockaddr_in addr;
    socklen_t len = (socklen_t)sizeof(addr);
    NSString* ret = @":";

    if (-1 != getpeername(sock, (struct sockaddr*)&addr, &len)) {
        ret = [NSString stringWithFormat:@"%s:%d", inet_ntoa(addr.sin_addr), addr.sin_port];
    }
    else {
        LOGDEBUG(@"Unable to getpeername, reason: ");
    }
    return ret;
}

@interface TCPServer ()

@property (nonatomic, assign, getter=isExecuting) BOOL executing;
@property (nonatomic, assign, getter=isFinished) BOOL finished;

@property (nonatomic, assign) int sock;
@property (nonatomic, assign) CFSocketRef cfSock;

@property (nonatomic, assign) CFRunLoopRef rl;
@property (nonatomic, assign) CFRunLoopSourceRef rlSource;

@end

void cb_accept(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void* data, void* info)
{
    TCPServer* srv = (__bridge TCPServer*)info;
    CFSocketNativeHandle* sock = (CFSocketNativeHandle*)data;
    if (srv.delegate) {
        [srv.delegate server:srv accept:*sock];
    }
}

@implementation TCPServer

@synthesize executing = _executing;
@synthesize finished = _finished;

- (instancetype)initWithHost:(NSString*)host port:(UInt16)port
{
    self = [super init];
    if (!self)
        return nil;

    _host = host;
    _port = port;

    return self;
}

- (BOOL)startInternal
{
    @synchronized(self)
    {
        if (self.isCancelled) {
            self.finished = YES;
            return NO;
        }

        self.executing = YES;
    }

    LOGINFO(@"Server starting...");

    _rl = CFRunLoopGetCurrent();

    if (_delegate && [_delegate respondsToSelector:@selector(server:event:)]) {
        if (NO == [_delegate server:self event:TCPServerEventTypeStart]) {
            [self cancelInternal];
            return NO;
        }
    }

    _sock = socket(PF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (_sock == -1) {
        [self cancelInternal];
        return NO;
    }

    struct sockaddr_in sin;
    memset(&sin, 0, sizeof(sin));

    sin.sin_len = sizeof(sin);
    sin.sin_family = AF_INET;
    sin.sin_addr.s_addr = inet_addr([_host UTF8String]);
    sin.sin_port = htons(_port);

    int sockopt = 1;
    setsockopt(_sock, SOL_SOCKET, SO_REUSEADDR, &sockopt, sizeof(sockopt));
    if (-1 == bind(_sock, (struct sockaddr*)&sin, sizeof(sin))) {
        LOGERR(@"Unable to bind %@:%d", _host, _port);
        [self cancelInternal];
        return NO;
    }

    if (-1 == listen(_sock, 256)) {
        LOGERR(@"Unable to listen %@:%d", _host, _port);
        [self cancelInternal];
        return NO;
    }

    CFSocketContext ctx;
    ctx.version = 0;
    ctx.info = (__bridge void*)(self);
    ctx.retain = CFRetain;
    ctx.release = CFRelease;
    ctx.copyDescription = NULL;

    _cfSock = CFSocketCreateWithNative(kCFAllocatorDefault, _sock, kCFSocketAcceptCallBack, cb_accept, &ctx);
    if (_cfSock == NULL) {
        LOGERR(@"Unable to create CFSocket");
        [self cancelInternal];
        return NO;
    }

    CFOptionFlags cfsockopt = CFSocketGetSocketFlags(_cfSock);
    cfsockopt |= kCFSocketCloseOnInvalidate | kCFSocketAutomaticallyReenableReadCallBack;
    CFSocketSetSocketFlags(_cfSock, cfsockopt);

    _rlSource = CFSocketCreateRunLoopSource(kCFAllocatorDefault, _cfSock, 0);
    if (_rlSource == NULL) {
        LOGERR(@"Unable to create runloop source");
        [self cancelInternal];
        return NO;
    }

    CFRunLoopAddSource(_rl, _rlSource, kCFRunLoopCommonModes);
    LOGINFO(@"Server is running at: [%@:%d]", _host, _port);
    return YES;
}

- (void)main
{
    if (YES == [self startInternal]) {
        CFRunLoopRun();
    }
}

- (void)cancelInternal
{
    if (self.finished) {
        return;
    }

    LOGINFO(@"Server stopping...");

    if (_delegate) {
        [_delegate server:self event:TCPServerEventTypeStop];
    }

    [super cancel];

    self.executing = NO;
    self.finished = YES;

    if (_rl) {
        CFRunLoopStop(_rl);
    }
    if (_cfSock) {
        CFSocketInvalidate(_cfSock);
    }
    else if (_sock != -1) {
        close(_sock);
    }

    LOGINFO(@"Server stopped");
}

- (void)cancel
{
    @synchronized(self)
    {
        [self cancelInternal];
    }
}

@end
