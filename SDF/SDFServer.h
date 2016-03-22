//
//  SDFServer.h
//  SDF
//
//  Created by mconintet on 3/18/16.
//  Copyright © 2016 mconintet. All rights reserved.
//

#import "TCPServer.h"
#import <Foundation/Foundation.h>

#define LIBSSH_LEGACY_0_4

#import "libssh.h"

#define MAX_CONCURRENT_CHANNEL_COUNT 50

@interface SDFServer : TCPServer <TCPServerDelegate>

@property (nonatomic, strong) NSString* sshHost;
@property (nonatomic, assign) UInt16 sshPort;

@property (nonatomic, strong) NSString* sshUsername;
@property (nonatomic, strong) NSString* sshPasswd;

- (instancetype)initWithHost:(NSString*)host port:(UInt16)port
                     sshHost:(NSString*)sshHost
                     sshPort:(UInt16)sshPort
                 sshUsername:(NSString*)sshUsername
                   sshPasswd:(NSString*)sshPasswd
   maxConcurrentChannelCount:(NSUInteger)maxConcurrentChannelCount;

@end
