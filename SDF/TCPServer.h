//
//  TCPServer.h
//  SDF
//
//  Created by mconintet on 3/18/16.
//  Copyright © 2016 mconintet. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <arpa/inet.h>
#import <netinet/in.h>
#import <string.h>
#import <sys/socket.h>

NSString* sockAddr(int sock);

@class TCPServer;

typedef NS_ENUM(UInt8, TCPServerEventType) {
    TCPServerEventTypeStart = 0,
    TCPServerEventTypeStop = 1,
};

@protocol TCPServerDelegate <NSObject>

- (void)server:(TCPServer*)srv accept:(NSSocketNativeHandle)accept;

@optional
- (BOOL)server:(TCPServer*)srv event:(TCPServerEventType)event;

@end

@interface TCPServer : NSThread

@property (nonatomic, weak) id<TCPServerDelegate> delegate;

@property (nonatomic, strong, readonly) NSString* host;
@property (nonatomic, assign, readonly) UInt16 port;

- (instancetype)initWithHost:(NSString*)host port:(UInt16)port;

@end
