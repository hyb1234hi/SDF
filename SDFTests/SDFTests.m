//
//  SDFTests.m
//  SDFTests
//
//  Created by mconintet on 3/22/16.
//  Copyright © 2016 mconintet. All rights reserved.
//

#import "SDFServer.h"
#import <XCTest/XCTest.h>

@interface SDFTests : XCTestCase

@end

@implementation SDFTests

- (void)setUp
{
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testServer
{
    char *server, *username, *passwd;
    size_t len = 30;

    printf("Input your server address:\n");
    getline(&server, &len, stdin);

    printf("Input your SSH username:\n");
    getline(&username, &len, stdin);

    printf("Input your SSH password:\n");
    getline(&passwd, &len, stdin);

    NSString* s = [NSString stringWithCString:server encoding:NSUTF8StringEncoding];
    NSString* un = [NSString stringWithCString:username encoding:NSUTF8StringEncoding];
    NSString* pwd = [NSString stringWithCString:passwd encoding:NSUTF8StringEncoding];

    un = [un substringToIndex:[un length] - 1];
    pwd = [pwd substringToIndex:[pwd length] - 1];

    SDFServer* srv = [[SDFServer alloc]
                     initWithHost:@"127.0.0.1"
                             port:7575
                          sshHost:s
                          sshPort:22
                      sshUsername:un
                        sshPasswd:pwd
        maxConcurrentChannelCount:0];

    [srv start];

    while (1) {
        int c = getchar();
        if (c == 'q') {
            break;
        }
    }
}

- (void)testPerformanceExample
{
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
