//
//  BleProtocol.h
//  Ble
//
//  Created by Markus Millfjord on 2014-12-18.
//  Copyright (c) 2014 Millcode AB. All rights reserved.
//

#import <Foundation/Foundation.h>

//Exportation of the Notification Observer params so that others (observers) know the names of the params they receive in their NSNotification object
extern NSString * const BleProtocolInquireSent;
extern NSString * const BleProtocolReceivedData;

extern NSString * const BleProtocolParamData;

typedef NS_ENUM(NSInteger, BleProtocolState) {
    BleProtocolStateIdle = 0,
    BleProtocolStatePending,
    BleProtocolStateSuccessful,
    BleProtocolStateFailed,
    BleProtocolStateTimeout
};

typedef NS_ENUM(NSInteger, BleProtocolEvent) {
    BleProtocolEventTbd1 = 0,
    BleProtocolEventTbd2
};

//Timeouts
#define CAP_PROTOCOL_COMM_DEFAULT_TIMEOUT  10  //Nbr of seconds for a command to be executed in the BLE-protocol

@protocol BleProtocolDelegate;
@protocol BleProtocolBody;

@interface BleProtocol : NSObject

@property (nonatomic, strong) id<BleProtocolDelegate> bleProtocolDelegate;

- (id) initWithBody:(id<BleProtocolBody>)body;

- (NSData*)inquire:(NSString*)command;

- (NSData*)inquire:(NSString*)command
           timeout:(dispatch_time_t)timeout;

- (NSData*)inquire:(NSString*)command
           payload:(NSData*)payload;

- (NSData*)inquire:(NSString*)command
           payload:(NSData*)payload
           timeout:(dispatch_time_t)timeout;

- (void)processInquireDataStream;
- (void)processResponseData:(NSData*)data;
- (void)processEventData:(NSData*)data;

@end
