//
//  BleController.h
//  Ble
//
//  Created by Markus Millfjord on 2014-12-10.
//  Copyright (c) 2014 Millcode AB. All rights reserved.
//

#import <Foundation/Foundation.h>

@class BleCommunicator;

//Exportation of the Notification Observer params so that others (observers) know the names of the params they receive in their NSNotification object
extern NSString * const BleCommunicationControllerDiscoveryStarted;
extern NSString * const BleCommunicationControllerDiscoveryStopped;
extern NSString * const BleCommunicationControllerConnecting;
extern NSString * const BleCommunicationControllerConnected;
extern NSString * const BleCommunicationControllerDisconnecting;
extern NSString * const BleCommunicationControllerDisconnected;

//Service UUIDs
#define BLE_SERVICE_CAP_UUID                       @"FE382B9B-BD26-4FE3-9BBC-BA11032B5CBD"

//Characteristic UUIDs
#define BLE_CHARACTERISTIC_CAP_REQUESTS_UUID       @"19DF2D7B-C4D0-47FF-A8F4-61173F363A42"
#define BLE_CHARACTERISTIC_CAP_EVENTS_UUID         @"619A19CB-64D4-4728-81F4-3684AA7BCC66"

//Timeouts
#define MULTI_PERIHERAL_DISCOVERY_TIMEOUT  5        //Nbr of seconds to persue a discovery when looking for > 1 peripherals
#define MULTI_PERIHERAL_DISCOVERY_MAX_THRESHOLD  5  //Max number of units to "discover" before we automatically abort discovery and start to process the peripheral we've found

@interface BleCommunicationController : NSObject

@property (strong, nonatomic) NSString* serialNumber;
@property (strong, nonatomic) BleCommunicator* lastCommunicator;

- (BOOL) isConnected;
- (void) startDiscovery;
- (void) stopDiscovery;

@end
