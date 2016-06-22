//
//  Manager.h
//  Millcode
//
//  Created by Markus Millfjord on 2015-02-07.
//

#import <Foundation/Foundation.h>

@class BleCommunicationController;

@interface Manager : NSObject

//The controller required for interaction
@property (strong) BleCommunicationController* bleController;

//The Serial number setup for the Ble/user
@property (strong, nonatomic) NSString* currentSerialNumber;

 //Static methods
+ (Manager*) getSharedManager;

//Instance methods

@end
