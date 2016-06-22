//
//  BleCentralManagerProtocolBody.m
//  Ble
//
//  Created by Markus Millfjord on 2015-07-11.
//  Copyright (c) 2015 Epickal AB. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import "BleCommunicator.h"
#import "BleCentralManagerProtocolBody.h"
#import "BleProtocolBody.h"

#include <sys/socket.h>
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>

#import <DDLog.h>
#import <DDLogMacros.h>

///////////////////////////////////////////
//Local constants

///////////////////////////////////////////
//Anonoumous extention/category, used to declare private stuff
@interface BleCentralManagerProtocolBody ()

@property (strong, nonatomic) NSData* lastInquireDataChunk;

@end

///////////////////////////////////////////
//Actual class-implementation
@implementation BleCentralManagerProtocolBody

#pragma mark - Constructors/initializers

- (id)initWithPeripheral:(CBPeripheral*)peripheral
  requestsCharacteristic:(CBCharacteristic*)characteristic
{
    //Kick super-initialization...
    if (self = [super init])
    {
        //And since that worked - proceed!
        _peripheral = peripheral;
        _characteristic = characteristic;
        
        _lastInquireDataChunk = nil;
        
        //Return ourselves...
        return self;
    }
    
    return nil;
}

#pragma mark - Local utility methods

- (BleProtocolBodyState) processInquireDataStream:(NSInputStream*)inputStream
{
    DDLogInfo(@"Processing data-stream for inquire to connected central!");
    
    while (inputStream && [inputStream hasBytesAvailable])
    {
        DDLogInfo(@"There's data avaiable to be sent -- great!");
        
        //Let's go!
        uint8_t buffer[20];
        NSInteger bytesRead = [inputStream read:buffer
                                      maxLength:20];
        DDLogInfo(@"Read %ld bytes from stream (max = %d)", bytesRead, 20);
        
        NSMutableData* data = [[NSMutableData alloc] initWithBytes:buffer length:bytesRead];
        
        //Send to peripheral!
        [self.peripheral writeValue:data
                  forCharacteristic:self.characteristic
                               type:CBCharacteristicWriteWithResponse];
    }
        
    //...and... if we get here -- we're finished!
    return BleProtocolBodyStateFinished;
}

@end