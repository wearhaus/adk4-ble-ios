//
//  BleProtocolDelegate.h
//  Ble
//
//  Created by Markus Millfjord on 2014-12-18.
//  Copyright (c) 2014 Millcode AB. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BleProtocol.h"

@protocol BleProtocolDelegate <NSObject>

@optional

- (void) bleProtocol:(BleProtocol*)protocol
       didReceiveEvent:(BleProtocolEvent)event
               payload:(NSData*)payload
               comment:(NSString*)comment;

@end
