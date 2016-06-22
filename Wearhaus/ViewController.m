//
//  ViewController.m
//  Wearhaus
//
//  Created by Markus Millfjord on 2015-02-05.
//  Copyright (c) 2015 Millcode. All rights reserved.
//

#import "Manager.h"

#import "ViewController.h"

#import "BleCommunicationController.h"
#import "BleCommunicator.h"
#import "BleProtocol.h"

#import "BleProtocolDataCell.h"

#import <DDLog.h>
#import <DDLogMacros.h>

#pragma mark - Hidden internal helper classes

//////////////
//Public state for the inner class
@interface RowDataObject : NSObject

- (id) initWithData:(NSString*)data isInquiry:(BOOL)inquiry;

@end

//////////////
//Private state for the inner class
@interface RowDataObject ()

@property (strong, nonatomic) NSString* data;
@property (nonatomic, getter=isInquiry) BOOL inquiry;

@end

///////////////
// Actual implememntation
@implementation RowDataObject

- (id) initWithData:(NSString*)data isInquiry:(BOOL)inquiry
{
    //Kick super-initialization...
    if (self = [super init])
    {
        _data = data;
        _inquiry = inquiry;
        
        //Return ourselves...
        return self;
    }
    
    return nil;
}

@end

/////////////////////////

@interface ViewController ()

@property (nonatomic, strong) NSMutableArray* dataArray;

- (void)setUserInteractionEnabled:(BOOL)enabled;

- (void)deviceConnected:(NSNotification*)notification;
- (void)deviceDisconnected:(NSNotification*)notification;
- (void)inquireSent:(NSNotification*)notification;
- (void)receivedData:(NSNotification*)notification;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.dataArray = [NSMutableArray array];
    
    //Register as observer for EarinCommController notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceConnected:)
                                                 name:BleCommunicationControllerConnected
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceDisconnected:)
                                                 name:BleCommunicationControllerDisconnected
                                               object:nil];
    
    //Register as observer for EarinCommController notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(inquireSent:)
                                                 name:BleProtocolInquireSent
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(receivedData:)
                                                 name:BleProtocolReceivedData
                                               object:nil];
    
    [self setUserInteractionEnabled:NO];

    Manager* manager = [Manager getSharedManager];
    [manager.bleController startDiscovery];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setUserInteractionEnabled:(BOOL)enabled
{
    //Well?
    if (enabled)
    {
        //Re-enable editing...!
        [self.sendButton setEnabled:YES];
        [self.inquireTextfield setEnabled:YES];
    }
    else
    {
        [self.sendButton setEnabled:NO];
        [self.inquireTextfield setEnabled:NO];
    }
}

- (void)deviceConnected:(NSNotification*)notification
{
    DDLogDebug(@"A BLE device just connected to us!");
    
    //Extract params from notification...
    NSDictionary* userInfo = notification.userInfo;
    
    //Extract meta-data from notification...
    
    //Make great logical decisions
    
    //Perform awesomeness
    
    //Enable UI-controls -- in main-queue, of course... else UI hate us...
    dispatch_sync(dispatch_get_main_queue(), ^(void)
    {
        [self setUserInteractionEnabled:YES];
    });
}

- (void)deviceDisconnected:(NSNotification*)notification
{
    DDLogDebug(@"A BLE just disconnected from us!");
    
    //Extract params from notification...
    NSDictionary* userInfo = notification.userInfo;
    
    //Disable UI-controls -- in main-queue, of course... else UI hate us...
    dispatch_sync(dispatch_get_main_queue(), ^(void)
    {
        [self setUserInteractionEnabled:NO];
    });
}

- (void)inquireSent:(NSNotification*)notification
{
    //Extract params from notification...
    NSDictionary* userInfo = notification.userInfo;
    
    //Extract meta-data from notification...
    NSString* inquire = [userInfo objectForKey:BleProtocolParamData];
    
    DDLogDebug(@"Sent inquire: %@", inquire);
    
    //Add to data-logg
    dispatch_async(dispatch_get_main_queue(), ^(void)
    {
        [self.dataArray addObject:[[RowDataObject alloc] initWithData:inquire isInquiry:YES]];
        [self.dataTable reloadData];
    });
}

- (void)receivedData:(NSNotification *)notification
{
    //Extract params from notification...
    NSDictionary* userInfo = notification.userInfo;
    
    //Extract meta-data from notification...
    NSString* data = [userInfo objectForKey:BleProtocolParamData];
    
    DDLogDebug(@"Received data: %@", data);
    
    //Add to data-logg
    dispatch_async(dispatch_get_main_queue(), ^(void)
    {
        [self.dataArray addObject:[[RowDataObject alloc] initWithData:data isInquiry:NO]];
        [self.dataTable reloadData];
    });
}

#pragma mark - Table view delegate/data source methods...

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)sectionIndex
{
    DDLogDebug(@"How many rows do we have?");
    
    //Number of entries...
    return self.dataArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    DDLogDebug(@"LocksView; cellForRowAtIndexPath for indexPath %@", indexPath);
    
    RowDataObject *object = [self.dataArray objectAtIndex:indexPath.row];
    if (object)
    {
        //Lock object!
        BleProtocolDataCell *cell = nil;
        
        if ([object isInquiry])
            cell = (BleProtocolDataCell*)[tableView dequeueReusableCellWithIdentifier:@"Inquire"];
        else
            cell = (BleProtocolDataCell*)[tableView dequeueReusableCellWithIdentifier:@"Receive"];
        
        DDLogVerbose(@" -- Dequeued cell %@", cell);
        
        //Configure cell!
        cell.dataLabel.text = object.data;
        
        return cell;
    }
    
    //Opps... NO cell identified! Warn and return nil!
    DDLogWarn(@"Failed determining cell-type for render!");
    return nil;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

#pragma mark - Button/UI-action methods...

- (IBAction)sendButtonPressed:(id)sender
{
    //Fetch data from textfield...
    NSString* inquire = self.inquireTextfield.text;
    
    //Anything in there...?
    if ([inquire length] > 0)
    {
        //Well, since the BLE comms are designed to work blocking, we're not allowed to call their functions from main-dispatch, so let's dispatch an async thread to do this...
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                                 (unsigned long)NULL), ^(void)
        {
            @try
            {
                Manager* manager = [Manager getSharedManager];
                [manager.bleController.lastCommunicator rawQuery:inquire];
            }
            @catch (NSException *exception)
            {
                //Failed...
                DDLogWarn(@"Failed runnign inquiry; %@ -> reason; %@", inquire, exception.description);
            }
        });
    }
}

@end
