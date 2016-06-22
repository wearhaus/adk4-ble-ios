//
//  Manager.m
//  Millcode
//
//  Created by Markus Millfjord on 2015-02-07.
//

#import "Manager.h"
#import "BleCommunicator.h"
#import "BleCommunicationController.h"

#import <DDLog.h>
#import <DDLogMacros.h>

///////////////////////////////////////////
//Singleton global

static Manager *singletonManager = nil;

///////////////////////////////////////////
//Anonoumous extention/category, used to declare private stuff
@interface Manager ()

@end

///////////////////////////////////////////
//Actual class-implementation

@implementation Manager

#pragma mark - Constructors/initializers

- (id)init
{
    self = [super init];

    if (self)
    {
        //Setup communicators/controllers
        _bleController = [[BleCommunicationController alloc] init];
        
        //Restore persistent state
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [self setCurrentSerialNumber:[defaults objectForKey:@"serialNumber"]];
    }

    return self;
}

#pragma mark - Singleton accessor methods

+ (Manager*) getSharedManager
{
    //Well, singleton based approach -- check if we're initialized...
    if (singletonManager == nil)
    {
        //Initialise -- ONCE!
        DDLogInfo(@"Created singleton Manager!");
        singletonManager = [[Manager alloc] init];
    }

    return singletonManager;
}

- (void)setCurrentSerialNumber:(NSString *)serialNumber
{
    DDLogInfo(@"Setting current serial to %@", serialNumber);
    
    //Save value...
    _currentSerialNumber = serialNumber;
    
    //Update shared prefs accordingly...
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:serialNumber forKey:@"serialNumber"];
    [defaults synchronize];
    
    //Forward serial to BleCommController
    [self.bleController setSerialNumber:serialNumber];
}

#pragma mark - Instance methods

@end