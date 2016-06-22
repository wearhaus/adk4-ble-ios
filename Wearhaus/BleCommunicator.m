//
//  LockCommunicator.m
//
//
//  Created by Markus Millfjord on 2013-01-25.
//  Copyright (c) 2013 Millcode AB. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import <String.h>

#import <DDLogMacros.h>

#import "Manager.h"
#import "BleCommunicator.h"
#import "BleCentralManagerProtocolBody.h"

///////////////////////////////////////////
//Static defines, local enums, etc...

///////////////////////////////////////////
//Anonoumous extention/category, used to declare private stuff
@interface BleCommunicator ()

@end

///////////////////////////////////////////
//Actual class-implementation
@implementation BleCommunicator

#pragma mark - Constructors/initializers

- (id) initWithIdentifier:(NSString*)identifier protocol:(BleProtocol*)protocol
{
    //Kick super-initialization...
    if (self = [super init])
    {
        //And since that worked - proceed!
        _identifier = identifier;
        _capProtocol = protocol;
        
        //Return ourselves...
        return self;
    }
    
    return nil;
}

#pragma mark - Local utility methods

#pragma mark - Public methods

- (NSString*) rawQuery:(NSString*)query
{
    if (self.capProtocol)
    {
        NSData* response = [self.capProtocol inquire:query];
        
        //Return result...
        return [[NSString alloc] initWithData:response
                                     encoding:NSUTF8StringEncoding];
    }
    
    return nil;
}

- (NSString*) getAddress
{
    if (self.capProtocol)
    {
        NSData* response = [self.capProtocol inquire:@"GET ADDR"];
        
        //Return result...
        return [[NSString alloc] initWithData:response
                                     encoding:NSUTF8StringEncoding];
    }
    
    return nil;
}

- (NSString*) getName
{
    if (self.capProtocol)
    {
        NSData* response = [self.capProtocol inquire:@"GET NAME"];
        
        //Return result...
        return [[NSString alloc] initWithData:response
                                     encoding:NSUTF8StringEncoding];
    }
    
    return nil;
}

- (NSString*) getNameForRemoteAddress:(NSString *)address
{
    if (self.capProtocol)
    {
        NSData* response = [self.capProtocol inquire:@"GET DEVICE NAME"
                                             payload:[address dataUsingEncoding:NSUTF8StringEncoding]];
        
        //Return result...
        return [[NSString alloc] initWithData:response
                                     encoding:NSUTF8StringEncoding];
    }
    
    return nil;
}

- (NSString*) getVersion
{
    if (self.capProtocol)
    {
        NSData* response = [self.capProtocol inquire:@"GET VERSION"];
        
        //Return result...
        return [[NSString alloc] initWithData:response
                                     encoding:NSUTF8StringEncoding];
    }
    
    return nil;
}

- (void) doPeerSessionConnDisc
{
    if (self.capProtocol)
    {
        [self.capProtocol inquire:@"DO PEER SESSION CONNDISC"];
    }
}

- (void) doPeerSessionInquire
{
    if (self.capProtocol)
    {
        [self.capProtocol inquire:@"DO PEER SESSION INQUIRE"];
    }
}

- (void) doPeerSessionDisconnect
{
    if (self.capProtocol)
    {
        [self.capProtocol inquire:@"DO PEER SESSION DISCONNECT"];
    }
}

- (void) doResetPdl
{
    if (self.capProtocol)
    {
        [self.capProtocol inquire:@"DO RESET PDL"];
    }
}

- (NSString*) getSerial
{
    if (self.capProtocol)
    {
        NSData* response = [self.capProtocol inquire:@"GET SERIAL"];
        
        //Return result...
        return [[NSString alloc] initWithData:response
                                     encoding:NSUTF8StringEncoding];
    }
    
    return nil;
}


- (void) doSkipForward
{
    if (self.capProtocol)
    {
        [self.capProtocol inquire:@"DO SKIP FORWARD"];
    }
}

- (void) doSkipBackward
{
    if (self.capProtocol)
    {
        [self.capProtocol inquire:@"DO SKIP BACKWARD"];
    }
}

- (void) doPlay
{
    if (self.capProtocol)
    {
        [self.capProtocol inquire:@"DO PLAY"];
    }
}

- (void) doPause
{
    if (self.capProtocol)
    {
        [self.capProtocol inquire:@"DO PAUSE"];
    }
}

- (void) doStop
{
    if (self.capProtocol)
    {
        [self.capProtocol inquire:@"DO STOP"];
    }
}

- (NSNumber*) getBatteryVoltage
{
    if (self.capProtocol)
    {
        NSData* response = [self.capProtocol inquire:@"GET VBAT"];
        
        NSString* resultString = [[NSString alloc] initWithData:response
                                                       encoding:NSUTF8StringEncoding];
        
        //Return value...
        return @([resultString integerValue]);
    }
    
    return nil;
}

- (NSNumber*) getChargerVoltage
{
    if (self.capProtocol)
    {
        NSData* response = [self.capProtocol inquire:@"GET VCHG"];
        
        NSString* resultString = [[NSString alloc] initWithData:response
                                                       encoding:NSUTF8StringEncoding];
        
        //Return value...
        return @([resultString integerValue]);
    }
    
    return nil;
}

@end
