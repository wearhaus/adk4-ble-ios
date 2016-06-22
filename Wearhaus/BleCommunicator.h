//
//  LockCommunicator.h
//  Millcode
//
//  Created by Markus Millfjord on 2013-01-25.
//  Copyright (c) 2013 Millcode AB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BleProtocol.h"

@interface BleCommunicator : NSObject

@property (strong, nonatomic) BleProtocol *capProtocol;
@property (strong, nonatomic) NSString *identifier;

- (id) initWithIdentifier:(NSString*)identifier protocol:(BleProtocol*)protocol;

- (NSString*) rawQuery:(NSString*)query;

- (NSString*) getAddress;
- (NSString*) getName;
- (NSString*) getNameForRemoteAddress:(NSString*)address;
- (NSString*) getVersion;

- (void) doPeerSessionConnDisc;
- (void) doPeerSessionInquire;
- (void) doPeerSessionDisconnect;
- (void) doResetPdl;

- (NSString*) getSerial;

- (void) doSkipForward;
- (void) doSkipBackward;
- (void) doPlay;
- (void) doPause;
- (void) doStop;

- (NSNumber*) getBatteryVoltage;
- (NSNumber*) getChargerVoltage;

@end

