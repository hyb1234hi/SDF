//
//  SDFChannel.h
//  SDF
//
//  Created by mconintet on 3/18/16.
//  Copyright © 2016 mconintet. All rights reserved.
//

#import "SDFServer.h"
#import <Foundation/Foundation.h>

#define SOCKS_VER 5
#define MAX_DOMAIN_LEN 50

@class SDFServer;

typedef NS_ENUM(UInt8, AUTH_TYPE) {
    AUTH_TYPE_NOAUTH = 0X00,
    AUTH_TYPE_GSSAPI = 0X01,
    AUTH_TYPE_USERNAME = 0X02,
    AUTH_TYPE_IANA = 0X03,
    AUTH_TYPE_RESERVED = 0X80,
    AUTH_TYPE_NOACCEPTABLE = 0XFF,
};

typedef NS_ENUM(UInt8, CMD_TYPE) {
    CMD_TYPE_NONE = 0x00,
    CMD_TYPE_CONNECT = 0x01,
    CMD_TYPE_BIND = 0x02,
    CMD_TYPE_UDP = 0x03,
};

typedef NS_ENUM(UInt8, ADDR_TYPE) {
    ADDR_TYPE_NONE = 0x00,
    ADDR_TYPE_IP4 = 0x01,
    ADDR_TYPE_DOMAIN = 0x03,
    ADDR_TYPE_IP6 = 0x04,
};

typedef NS_ENUM(UInt8, REP_FIELD) {
    REP_FIELD_SUCCEEDED = 0X00,
    REP_FIELD_GENERAL_SERVER_FAILURE = 0X01,
    REP_FIELD_CONNNOT_ALLOWED_BY_RULESET = 0X02,
    REP_FIELD_NETWORK_UNREACHABLE = 0X03,
    REP_FIELD_HOST_UNREACHABL = 0X04,
    REP_FIELD_CONNECTION_REFUSED = 0X05,
    REP_FIELD_TTL_EXPIRED = 0X06,
    REP_FIELD_COMMAND_NOT_SUPPORTED = 0X07,
    REP_FIELD_ADDRESS_TYPE_NOT_SUPPORTED = 0X08
};

@interface SDFCommand : NSObject

@property (nonatomic, assign) CMD_TYPE type;
@property (nonatomic, assign) ADDR_TYPE atyp;

@property (nonatomic, strong) NSString* addr;
@property (nonatomic, assign) UInt16 port;

@end

@interface SDFChannel : NSOperation

- (instancetype)initWithID:(NSUInteger)ID
                    server:(SDFServer*)server
                  leftSock:(int)leftSock;

@end
