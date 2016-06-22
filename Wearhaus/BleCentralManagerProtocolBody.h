//
//  BleCentralManagerProtocolBody.h
//  Ble
//
//  Created by Markus Millfjord on 2015-07-11.
//  Copyright (c) 2015 Epickal AB. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

#import "BleProtocolBody.h"

@interface BleCentralManagerProtocolBody : NSObject <BleProtocolBody>

@property (strong, nonatomic) CBPeripheral* peripheral;
@property (strong, nonatomic) CBCharacteristic* characteristic;

- (id)initWithPeripheral:(CBPeripheral*)peripheral
       requestsCharacteristic:(CBCharacteristic*)characteristic;

@end
