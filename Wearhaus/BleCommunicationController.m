//
//  BleController.m
//  Ble
//
//  Created by Markus Millfjord on 2014-12-10.
//  Copyright (c) 2014 Millcode AB. All rights reserved.
//

#import "BleCommunicationController.h"
#import "BleCommunicator.h"

#import <CoreBluetooth/CoreBluetooth.h>

#import <DDLog.h>
#import <DDLogMacros.h>

#import "BleProtocol.h"
#import "BleProtocolDelegate.h"
#import "BleCentralManagerProtocolBody.h"

///////////////////////////////////////////
//Static defines, local enums, etc...

NSString * const BleCommunicationControllerDiscoveryStarted       = @"BleCommunicationControllerDiscoveryStarted";
NSString * const BleCommunicationControllerDiscoveryStopped       = @"BleCommunicationControllerDiscoveryStopped";
NSString * const BleCommunicationControllerConnecting             = @"BleCommunicationControllerConnecting";
NSString * const BleCommunicationControllerConnected              = @"BleCommunicationControllerConnected";
NSString * const BleCommunicationControllerDisconnecting          = @"BleCommunicationControllerDisconnecting";
NSString * const BleCommunicationControllerDisconnected           = @"BleCommunicationControllerDisconnected";

///////////////////////////////////////////
//Anonoumous extention/category, used to declare private stuff
@interface BleCommunicationController () <CBCentralManagerDelegate, CBPeripheralDelegate, BleProtocolDelegate>

@property (strong, nonatomic) CBMutableCharacteristic *protocolCharacteristic;

@property (strong, nonatomic) CBCentralManager *centralManager;
@property (strong, nonatomic) NSMutableOrderedSet* discoveredPeripherals;
@property (strong, nonatomic) NSNumber* discoveredPeripheralsThreshold;
@property (strong, nonatomic) CBPeripheral *currentPeripheral;

//A list of all currently subscribed communicators -- which might or might not include the Bles that have a matching serial number (since we need to store all communicators somewhere to be able to forward protocol data properly)
@property (strong, nonatomic) NSMutableArray *allCommunicators;

@property (assign, nonatomic, getter=isDiscovering) BOOL discovering;

- (void) handleCommunicatorDisconnected:(BleCommunicator *)communicator;

@end

///////////////////////////////////////////
//Actual class-implementation
@implementation BleCommunicationController

#pragma mark - Constructors/initializers

//Override default init-method (without arguments) so that we can initialize ourselves accordingly...
- (id)init
{
    //Kick super-initialization...
    if (self = [super init])
    {
        //And since that worked - proceed!
        
        //Initialize CB manager with ourselves as delegate/listener...
        _centralManager = nil;
        
        //No characteristic to start with...
        _protocolCharacteristic = nil;
        
        _allCommunicators = [NSMutableArray array];
        _lastCommunicator = nil;
        _discovering = NO;
        
        //Return ourselves...
        return self;
    }
    
    return nil;
}

#pragma mark - Common utility methods

- (BleCommunicator*) findCommunicatorByIdentifier:(NSString*)identifier
{
    for (BleCommunicator* communicator in self.allCommunicators)
        if ([communicator.identifier isEqual:identifier])
            return communicator;
    
    DDLogWarn(@"Failed finding matching comm with identifier %@", identifier);
    return nil;
}

- (void) handleCommunicatorDisconnected:(BleCommunicator*)communicator
{
    DDLogInfo(@"Handling comm disconnection for communicator %@", communicator);
    
    //Ble disconnected!
    if (communicator)
    {
        //Great!
        
        //Remove from all-list
        [self.allCommunicators removeObject:communicator];
        
        //Check if this was us?
        if (self.lastCommunicator == communicator)
        {
            //Setup user info
            NSMutableDictionary* userInfo = [[NSMutableDictionary alloc] init];
            
            //Setup various params that the UI might need to know about...
            
            //Notify
            [[NSNotificationCenter defaultCenter] postNotificationName:BleCommunicationControllerDisconnected
                                                                object:self
                                                              userInfo:userInfo];
            
            //Do it
            self.lastCommunicator = nil;
        }
    }
    else
    {
        DDLogWarn(@"Failed identifying Ble among connected comms!");
    }
}

- (BleCommunicator*) createCommunicator:(id<BleProtocolBody>)body
                             identifier:(NSString*)identifier
                                  error:(NSError**)error
{
    DDLogDebug(@"Creating communicator for provided protocol body, using identifier %@", identifier);
    
    BleProtocol* protocol = [[BleProtocol alloc] initWithBody:body];
    
    //... and wrap it into comminicator
    BleCommunicator *communicator = [[BleCommunicator alloc] initWithIdentifier:identifier
                                                                       protocol:protocol];
    
    //Add to our "all" list
    [self.allCommunicators addObject:communicator];
/*
    NSString* serial = nil;
    
    @try {
        serial = [communicator getSerial];
        DDLogInfo(@"Extracted serial %@ from connected Ble", serial);
    }
    @catch (NSException *exception) {
        DDLogInfo(@"Opps - failed reading serial... Most likely a device that's not configured...!");
    }
    
    //Check if it's the expected serial matching our setup...
    if (serial != nil && [self.serialNumber isEqualToString:serial])
    {
        DDLogInfo(@"Serial match! Found 'our' device");
*/
        //Add to "our" list
        self.lastCommunicator = communicator;
        
        //Setup user info
        NSMutableDictionary* userInfo = [[NSMutableDictionary alloc] init];
        
        //Extract params from connected device
        //    NSNumber* bassBoost = [communicator getBassBoost];
        
        //Setup userInfo with details
        //    [userInfo setObject:bassBoost forKey:BleCommunicationControllerParamBassBoost];
        
        //Notify
        [[NSNotificationCenter defaultCenter] postNotificationName:BleCommunicationControllerConnected
                                                            object:self
                                                          userInfo:userInfo];
/*
    }
    else
    {
        DDLogInfo(@"Ignored -- not our device!");
        *error = [NSError errorWithDomain:@"com.wearhaus"
                                     code:100
                                 userInfo:@{
                                            NSLocalizedDescriptionKey: @"Wrong serial"}];
    }
*/
    //Feedback the created comm, if it needs to be used for what-ever-reason.
    return communicator;
}

#pragma mark - Central mgr local utility methods

- (CBPeripheral*) dequeueDiscoveredPeripheral
{
    DDLogInfo(@"Time to dequeue a discovered peripheral. There are %ld peripherals discovered as of now", (long)self.discoveredPeripherals.count);
    
    //Anything left in the pool?
    if (self.discoveredPeripherals.count > 0)
    {
        //Go and dequeue!
        CBPeripheral* peripheral = [self.discoveredPeripherals firstObject];
        
        //Consume ourselves from the discovered pool...
        [self.discoveredPeripherals removeObject:peripheral];
        
        return peripheral;
    }
    else
    {
        DDLogInfo(@"Nope -- no discovered peripherals left to dequeue!");
        return nil;
    }
}

- (BOOL) connectToPeripheral:(CBPeripheral*)peripheral
{
    DDLogInfo(@"Time to connect to peripheral %@", peripheral);
    
    //Valid?
    if (peripheral)
    {
        //Go!
        
        //Store local reference to peripheral since the object passed as argument will not exist efter calling the CB-connect method... Strange perhaps, but nontheless how the API works so we have to deal with it...
        self.currentPeripheral = peripheral;
        
        //Reset charateristics...
        self.protocolCharacteristic = nil;
        
        //Go!
        [self.centralManager connectPeripheral:self.currentPeripheral options:nil];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:BleCommunicationControllerConnecting
                                                            object:self
                                                          userInfo:nil];
        
        return YES;
    }
    else
    {
        DDLogInfo(@"Nope -- no discovered peripherals left to dequeue!");
        return NO;
    }
}

/** Call this when things either go wrong, or you're done with the connection.
 *  This cancels any subscriptions if there are any, or straight disconnects if not.
 *  (didUpdateNotificationStateForCharacteristic will cancel the connection if a subscription is involved)
 */
- (void)cleanupCurrentPeripheral
{
    DDLogDebug(@"Cleanup current peripheral");
    
    // Don't do anything if we're not connected
    if (self.currentPeripheral == nil || self.currentPeripheral.state == CBPeripheralStateDisconnected)
    {
        DDLogDebug(@"-- Not connected, sanitize state");
        
        //Make sure that we're no longer the delegate...
        [self.currentPeripheral setDelegate:nil];
        
        //Reset variables...
        self.currentPeripheral = nil;
        
        //Done!
        return;
    }
    
    // See if we are subscribed to a characteristic on the peripheral
    if ([self.currentPeripheral services] != nil)
    {
        DDLogDebug(@"-- Unsubcscribing from services");
        
        //Cycle thrrough ALL services of the currently connected peripheral...
        for (CBService *service in [self.currentPeripheral services])
        {
            //Do we have any characteristics?
            if ([service characteristics] != nil)
            {
                //Yes -- cycle through them to try to find characteristics that WE might be listening to...
                for (CBCharacteristic *characteristic in [service characteristics])
                {
                    //Was it one of "our" characteristics that WE care about...?
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:BLE_CHARACTERISTIC_CAP_REQUESTS_UUID]] ||
                        [characteristic.UUID isEqual:[CBUUID UUIDWithString:BLE_CHARACTERISTIC_CAP_EVENTS_UUID]])
                    {
                        if (characteristic.isNotifying)
                        {
                            // It is notifying, so unsubscribe
                            [self.currentPeripheral setNotifyValue:NO forCharacteristic:characteristic];
                        }
                    }
                }
            }
        }
    }
    
    DDLogDebug(@"-- Cancelling connection");
    
    // If we've got this far, we're connected, but we're not subscribed, so we just disconnect
    [self.centralManager cancelPeripheralConnection:self.currentPeripheral];
    
    //Tell delegate, if we have one, and that delegate has implemented our optional delegate-protocol method...
    [[NSNotificationCenter defaultCenter] postNotificationName:BleCommunicationControllerDisconnecting
                                                        object:self
                                                      userInfo:nil];
}

- (void)discoverMultiplePeripheralsTimeoutGuard:(NSTimer *)timer
{
    DDLogInfo(@"Discovery of Peripherals timedout guard kicked in!");
    
    //Well, should we abort an ongoing discovery or what?
    if (self.discovering)
    {
        //Restart discovery process!
        DDLogInfo(@"Timeout guard caused a restart of the discovery process");
        [self stopDiscovery];
        
        //This will ensure that we process all, if any, already discovered periherals, before we eventually (if we don't match any session), return to a scan/discovery state trying to find more peripherals
        [self startDiscovery];
    }
    else
    {
        DDLogInfo(@"Ignored timeout guard -- not discovering");
    }
}

#pragma mark - Public methods

- (BOOL)isConnected
{
    return self.lastCommunicator != nil;
}

- (void)startDiscovery
{
    DDLogDebug(@"Starting discovery requested");
    
    if (![self isDiscovering])
    {
        if (_centralManager == nil)
        {
            _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
            
            //Where we put all of our discovered peripherals during a scan
            _discoveredPeripherals = [[NSMutableOrderedSet alloc] init];
            _discoveredPeripheralsThreshold = nil;
            _discovering = NO;
            _currentPeripheral = nil;
        }
        
        CBPeripheral* peripheral = nil;
        
        //First check; do we already know the "reconnectable UUID" to the Ble bud (last connected with matching serial number)?
//        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//        NSString* lastConnectedDeviceUUID = [defaults objectForKey:@"lastConnectedDeviceIdentifier"];
//        if (lastConnectedDeviceUUID != nil)
//        {
//            DDLogInfo(@"Reconnecting to already known 'last' device");
//            NSArray<CBPeripheral*> *retrievedPeripherals = [self.centralManager retrievePeripheralsWithIdentifiers:@[[[NSUUID UUID] initWithUUIDString:lastConnectedDeviceUUID]]];
//            
//            //Try first one!
//            if (retrievedPeripherals != nil && retrievedPeripherals.count > 0)
//                peripheral = [retrievedPeripherals firstObject];
//        }
//        
//        //Are there any already discovered peripherals that we should look at?
//        else if (self.discoveredPeripherals.count > 0)
//        {
//            DDLogInfo(@"There are %lu discovered peripherals that we should check", (unsigned long)self.discoveredPeripherals.count);
//            peripheral = [self dequeueDiscoveredPeripheral];
//        }
        
        //Anything?
        if (peripheral != nil)
        {
            //Try it!
            [self connectToPeripheral:peripheral];
        }
        else
        {
            //No queued discovered peripherals -- time for a scan!
            DDLogInfo(@"No queued peripherals -- prepare a scan!");
            
            //Setup variables needed for this scan!
            if (!self.discoveredPeripheralsThreshold)
            {
                DDLogInfo(@"No previous known discovery threshold -- start from scratch!");
                self.discoveredPeripheralsThreshold = [NSNumber numberWithInteger:1];
            }
            else
            {
                //Reached MAX discovery theshold...?
                if (self.discoveredPeripheralsThreshold.integerValue < MULTI_PERIHERAL_DISCOVERY_MAX_THRESHOLD)
                {
                    DDLogInfo(@"Increasing discovery threshold since we've already started scanning but seem to be unsuccessful doing so...");
                    self.discoveredPeripheralsThreshold = [NSNumber numberWithInteger:self.discoveredPeripheralsThreshold.integerValue + 1];
                }
                
                //Kick timeout guard so that we don't search for infinity and never find anyting...
                DDLogInfo(@"Kicking multe peripheral discovery timeout guard since we're looking %ld peripherals (> 1)", (long)self.discoveredPeripheralsThreshold.integerValue);
                [NSTimer scheduledTimerWithTimeInterval:MULTI_PERIHERAL_DISCOVERY_TIMEOUT
                                                 target:self
                                               selector:@selector(discoverMultiplePeripheralsTimeoutGuard:)
                                               userInfo:nil
                                                repeats:NO];
            }
            
            DDLogInfo(@"Discovery threshold set to %ld", (long)self.discoveredPeripheralsThreshold.integerValue);
            
            //Set logical state
            self.discovering = YES;
            
            if (self.centralManager.state == CBCentralManagerStatePoweredOn)
            {
                DDLogInfo(@"Fire scan!");
                
                //Make sure that we're scanning for a device since we have just added a session!
                [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:BLE_SERVICE_CAP_UUID]]
                                                            options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@YES}];
                
                //Notify...
                [[NSNotificationCenter defaultCenter] postNotificationName:BleCommunicationControllerDiscoveryStarted
                                                                    object:self
                                                                  userInfo:nil];
            }
        }
    }
    else
    {
        DDLogWarn(@"Already logically discovering -- ignore");
    }
}

- (void)stopDiscovery
{
    DDLogDebug(@"Stop advertising!");
    
    if ([self isDiscovering])
    {
        //Set logical state
        self.discovering = NO;
        [self.centralManager stopScan];
    }
    else
    {
        DDLogWarn(@"Already logically discovering -- ignore");
    }
}

#pragma mark - Central manager delegate methods

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    //CB manager updated/changed state, so we need to make sure that we're "on top" and react accordlingy...
    //Note; the CB manager always send this message to us when our app is running, regardless ofig therer was an update/chance or not, just so that hte app can know "current" state.
    DDLogInfo(@"CB manager changed state %ld", (long)central.state);
    
    if (central.state != CBCentralManagerStatePoweredOn)
    {
        //Nope -- we are NOT on -- cancel!
        DDLogInfo(@"CB central manager NOT on");
        
        //If we were discovering, and/or even connected, we need to trigger notificaotins and cleanup our local state
        [self stopDiscovery];
        
        //We will not receive any "unsubscribe" invocations, so we need to "disconnect" our Bles manually
        while ([self.allCommunicators count] > 0)
        {
            BleCommunicator* communicator = [self.allCommunicators firstObject];
            
            //Central disconnected
            [self handleCommunicatorDisconnected:communicator];
        }
        
        return;
    }
    
    //Are we logically supposed to be scanning/disovering?
    if ([self isDiscovering])
    {
        DDLogInfo(@"Logically already discovering -- kick in actual discovery ASAP!");
        //Make sure that we're scanning for a device since we have just added a session!
        [self.centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:BLE_SERVICE_CAP_UUID]]
                                                    options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@YES}];
        
        //Notify...
        [[NSNotificationCenter defaultCenter] postNotificationName:BleCommunicationControllerDiscoveryStarted
                                                            object:self
                                                          userInfo:nil];
    }
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
    DDLogInfo(@"Discovered peripheral %@ with RSSI %ld", peripheral.name, (long)RSSI.integerValue);
    
    /*
     if (ABS(RSSI.integerValue) > 30)
     {
     DDLogInfo(@"TOO FAR AWAY");
     return;
     }
     */
    
    [self.discoveredPeripherals addObject:peripheral];
    DDLogInfo(@"Found %lu peripherals", (unsigned long)self.discoveredPeripherals.count);
    
    //So, did we reach our threshold?
    if (self.discoveredPeripherals.count >= self.discoveredPeripheralsThreshold.unsignedIntegerValue)
    {
        DDLogInfo(@"Threshold reached! Time to start to connect");
        
        //Yes, it's time to stop scanning and see if any of our discovered darlings match a session in our session-pool
        [self stopDiscovery];
        
        CBPeripheral* peripheral = [self dequeueDiscoveredPeripheral];
        if (![self connectToPeripheral:peripheral])
        {
            DDLogWarn(@"Opps. Discovered peripherals, but failed kicking connection attempt");
        }
    }
    else
    {
        //Let things be -- we want to find MORE devices before we attempt any connections
        DDLogInfo(@"Wait... no connection yet, we're waiting for more devices to be found, or scanning to timeout...");
    }
}

/** If the connection fails for whatever reason, we need to deal with it.
 */
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    DDLogWarn(@"CB manager didFailToConnectPeripheral %@ with error %@", peripheral, error);
    
    //OK -- then, I guess -- just make sure that we're all "cleaned up"...
    [self cleanupCurrentPeripheral];
}

/** We've connected to the peripheral, now we need to discover the services and characteristics to find the 'protocol' characteristic.
 */
- (void)centralManager:(CBCentralManager *)central
  didConnectPeripheral:(CBPeripheral *)peripheral
{
    DDLogInfo(@"CB manager didConnectPeripheral %@", peripheral);
    
    // Make sure we get the service & characteristic discovery callbacks
    [peripheral setDelegate:self];
    
    // Search only for services that match our UUID
    [peripheral discoverServices:@[[CBUUID UUIDWithString:BLE_SERVICE_CAP_UUID]]];
}

/** The Transfer Service was discovered
 */
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    DDLogInfo(@"didDiscoverServices: %@", peripheral.services);
    
    if (error)
    {
        DDLogWarn(@"Error discovering services: %@", [error localizedDescription]);
        [self cleanupCurrentPeripheral];
        return;
    }
    
    // Discover the characteristic(s) we want...
    
    // Loop through the newly filled peripheral.services array, just in case there's more than one.
    for (CBService *service in peripheral.services)
    {
        if ([service.UUID isEqual:[CBUUID UUIDWithString:BLE_SERVICE_CAP_UUID]])
        {
            DDLogInfo(@"Kicking discovery of characteristics for servive %@", service.UUID);
            [peripheral discoverCharacteristics:@[
                                                  [CBUUID UUIDWithString:BLE_CHARACTERISTIC_CAP_REQUESTS_UUID],
                                                  [CBUUID UUIDWithString:BLE_CHARACTERISTIC_CAP_EVENTS_UUID]]
                                     forService:service];
            
            return;
        }
    }
    
    //If we get here -- something's bad...
    [self cleanupCurrentPeripheral];
}

// Characteristic was discovered!
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    DDLogInfo(@"didDiscoverCharacteristicsForService %@", service);
    
    // Deal with errors (if any)
    if (error)
    {
        DDLogWarn(@"Error discovering characteristics: %@", [error localizedDescription]);
        [self cleanupCurrentPeripheral];
        return;
    }
    
    //So, let's find the found characteristics for this lock...
    CBCharacteristic *requestsCharacteristic = nil;
    CBCharacteristic *eventsCharacteristic = nil;
    
    for (CBCharacteristic *characteristic in service.characteristics)
    {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:BLE_CHARACTERISTIC_CAP_REQUESTS_UUID]])
            requestsCharacteristic = characteristic;
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:BLE_CHARACTERISTIC_CAP_EVENTS_UUID]])
            eventsCharacteristic = characteristic;
    }
    
    //Well, for this to work, we need to have atleast a valid SerialNumber (for identification) and a valid protocol transfer/SPP-over-BLE characteristic
    if (requestsCharacteristic != nil &&
        eventsCharacteristic != nil)
    {
        DDLogInfo(@"Found protocol characteristic(s)!");
        
        //Hook-up and make sure we're listening on received data on BOTH charateristics...
        [peripheral setNotifyValue:YES forCharacteristic:requestsCharacteristic];
        [peripheral setNotifyValue:YES forCharacteristic:eventsCharacteristic];
        
        //Well -- we have everthing we need to create a comm or this connected!
        
        //Dispatch sync and determine the discovered device's serial number so that we can see if it's ours?
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                                 (unsigned long)NULL), ^(void)
        {
            //Create body and comm...
            BleCentralManagerProtocolBody* body = [[BleCentralManagerProtocolBody alloc] initWithPeripheral:peripheral
                                                                                     requestsCharacteristic:requestsCharacteristic];
            
            NSError* error = nil;
            BleCommunicator* communicator = [self createCommunicator:body
                                                          identifier:peripheral.identifier.UUIDString
                                                               error:&error];
            
            //So -- any failure?
            if (error != nil)
            {
                //NOT a keeper... ;(
                DDLogInfo(@"Wrong serial number for connected peripheral -- disconnect it!");
                
                //If we get here -- we failed! Clean up!
                [self cleanupCurrentPeripheral];
            }
            else
            {
                //Store/remember identifier so that we can reconnect to it automatically next time we connect/discover
                //Update shared prefs accordingly...
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setObject:peripheral.identifier.UUIDString forKey:@"lastConnectedDeviceIdentifier"];
                [defaults synchronize];
                
                //Other than that -- keep connection and let's see what happens!
                
                //But listen to events, for now...
                [communicator.capProtocol setBleProtocolDelegate:self];
            }
        });
    }
    else
    {
        DDLogWarn(@"Missing protocol characteristic!");
        
        //If we get here -- we failed! Clean up!
        [self cleanupCurrentPeripheral];
    }
}

/** This callback lets us know more data has arrived via notification on the characteristic
 */
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    DDLogInfo(@"communictor; didUpdateValueForCharacteristic -- %@", characteristic.UUID);
    
    if (error)
    {
        DDLogWarn(@"Error when updating characteristics: %@", [error localizedDescription]);
        [self cleanupCurrentPeripheral];
        return;
    }
    
    //So -- what kind of data do we have? On request charateristic? Then it's a response to someting we sent...
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:BLE_CHARACTERISTIC_CAP_REQUESTS_UUID]])
    {
        //... and as such we need to forward the response data to the currently running CAP-protocol parser...
        BleCommunicator* communicator = [self findCommunicatorByIdentifier:characteristic.service.peripheral.identifier.UUIDString];
        if (communicator)
        {
            //Append to comm's CAP response buffer...
            [communicator.capProtocol processResponseData:characteristic.value];
        }
        
        return;
    }
    
    else if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:BLE_CHARACTERISTIC_CAP_EVENTS_UUID]])
    {
        //... and as such we need to forward the response data to the currently running CAP-protocol parser...
        BleCommunicator* communicator = [self findCommunicatorByIdentifier:characteristic.service.peripheral.identifier.UUIDString];
        if (communicator)
        {
            //Append to comm's CAP event buffer...
            [communicator.capProtocol processEventData:characteristic.value];
        }
        
        return;
    }
    
    DDLogInfo(@"Disconnecting current connected peripheral");
    [self cleanupCurrentPeripheral];
}

/** Once the disconnection happens, we need to clean up our local copy of the peripheral
 */
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    DDLogInfo(@"Peripheral disconnected");
    
    //If a device/gadget disconnected, and it was NOT in "our" list, hence it was NOT a recognized Ble with matching serial number, then simply resume discovery
    BOOL resumeDiscovery = NO;
    
    //Find comm for peripheral...
    BleCommunicator* communicator = [self findCommunicatorByIdentifier:peripheral.identifier.UUIDString];
    
    //If NOT one of ours...
    if (communicator == nil || self.lastCommunicator != communicator)
    {
        //Identified!
        DDLogInfo(@"Identified peripoheral is NOT our of 'our' connected Bles -- automatically fallback on discovery...");
        resumeDiscovery = YES;
    }
    
    //Central disconnected
    [self handleCommunicatorDisconnected:communicator];
    
    //Always cleanup...
    [self cleanupCurrentPeripheral];
    
    if (resumeDiscovery)
        [self startDiscovery];
}

- (void)bleProtocol:(BleProtocol *)protocol didReceiveEvent:(BleProtocolEvent)event payload:(NSData *)payload comment:(NSString *)comment
{
    DDLogInfo(@"Did receive event from Ble protocol!");
}

@end
