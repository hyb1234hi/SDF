//
//  SDFServer.m
//  SDF
//
//  Created by mconintet on 3/18/16.
//  Copyright © 2016 mconintet. All rights reserved.
//

#import "Log.h"
#import "SDFChannel.h"
#import "SDFServer.h"

static NSUInteger seed = 0;

@interface SDFServer ()

@property (nonatomic, strong) NSOperationQueue* channelQueue;

@end

@implementation SDFServer

- (instancetype)initWithHost:(NSString*)host port:(UInt16)port
                     sshHost:(NSString*)sshHost
                     sshPort:(UInt16)sshPort
                 sshUsername:(NSString*)sshUsername
                   sshPasswd:(NSString*)sshPasswd
   maxConcurrentChannelCount:(NSUInteger)maxConcurrentChannelCount
{
    self = [super initWithHost:host port:port];
    if (!self) {
        return nil;
    }

    _sshHost = sshHost;
    _sshPort = sshPort;
    _sshUsername = sshUsername;
    _sshPasswd = sshPasswd;

    _channelQueue = [[NSOperationQueue alloc] init];
    _channelQueue.maxConcurrentOperationCount = maxConcurrentChannelCount ?: MAX_CONCURRENT_CHANNEL_COUNT;

    self.delegate = self;

    return self;
}

- (void)begin
{
    ssh_init();
}

- (void)end
{
    ssh_finalize();
    seed = 0;
}

- (BOOL)server:(TCPServer*)srv event:(TCPServerEventType)event
{
    if (TCPServerEventTypeStart == event) {
        [self begin];
    }
    else if (TCPServerEventTypeStop == event) {
        [self end];
    }
    return YES;
}

- (NSInteger)counter
{
    return ++seed;
}

- (void)server:(TCPServer*)srv accept:(NSSocketNativeHandle)accept
{
    SDFChannel* channel = [[SDFChannel alloc]
        initWithID:[self counter]
            server:self
          leftSock:accept];

    [_channelQueue addOperation:channel];
}

@end
