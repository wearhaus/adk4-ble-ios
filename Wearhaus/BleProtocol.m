//
//  BleProtocol.m
//  Ble
//
//  Created by Markus Millfjord on 2014-12-18.
//  Copyright (c) 2014 Millcode AB. All rights reserved.
//

#import "BleProtocol.h"

#import <DDLog.h>
#import <DDLogMacros.h>

#import "BleProtocolBody.h"

NSString * const BleProtocolInquireSent              = @"BleProtocolInquireSent";
NSString * const BleProtocolReceivedData             = @"BleProtocolReceivedData";

NSString * const BleProtocolParamData                = @"BleProtocolParamData";

///////////////////////////////////////////
//Local constants
static const NSString* EVENT_MATCH_STRING = @"EVENT";
static NSString* COMMAND_CONFIRMED_STRING = @"OK";
static NSString* COMMAND_FAILED_STRING = @"FAIL";

static const NSString* INQUIRE_COMMAND_TERMINATOR = @"\r";
static const NSString* RESPONSE_COMMAND_TERMINATOR = @"\r";
static const NSString* DATA_BLOCK_START_CHAR = @"[";
static const NSString* DATA_BLOCK_END_CHAR = @"]";
static const NSString* DATA_BLOCK_VALUE_SEPARATOR = @",";
static const NSString* COMMENT_CHAR = @",";

///////////////////////////////////////////
//Anonoumous extention/category, used to declare private stuff
@interface BleProtocol ()

@property (nonatomic) BleProtocolState state;

@property (nonatomic, strong) id<BleProtocolBody> body;

@property (strong, nonatomic) NSInputStream *inquireDataStream;

@property (strong, nonatomic) NSString* lastSentInquireCommand;

@property (strong, nonatomic) NSMutableData* responseDataBuffer;
@property (strong, nonatomic) NSMutableData* eventDataBuffer;

@property (strong, nonatomic) NSData* responsePayload;
@property (strong, nonatomic) NSException* exception;
@property (strong) dispatch_semaphore_t responseBlockingSemaphore;

- (void)commonParseDataBuffer:(NSMutableData*)buffer;

@end

///////////////////////////////////////////
//Actual class-implementation

@implementation BleProtocol

#pragma mark - Internal functions

- (void)commonParseDataBuffer:(NSMutableData*)buffer
{
    DDLogInfo(@"Parsing data buffer %@", [[NSString alloc] initWithData:buffer
                                                               encoding:NSUTF8StringEncoding]);
    
    if (buffer && [buffer length] > 0)
    {
        //Check if we have a full command
        NSRange terminatorRange = [buffer rangeOfData:[RESPONSE_COMMAND_TERMINATOR dataUsingEncoding:NSUTF8StringEncoding]
                                            options:0
                                              range:NSMakeRange(0, [buffer length])];
        
        if (terminatorRange.location != NSNotFound)
        {
            //Found terminator!
            DDLogDebug(@"Found terminator at location %ld", terminatorRange.location);
            
            //Setup user info
            NSMutableDictionary* userInfo = [[NSMutableDictionary alloc] init];
            
            //Setup userInfo with details
            [userInfo setObject:[[NSString alloc] initWithData:[buffer subdataWithRange:NSMakeRange(0, terminatorRange.location)] encoding:NSUTF8StringEncoding]
                         forKey:BleProtocolParamData];
            
            //Notify
            [[NSNotificationCenter defaultCenter] postNotificationName:BleProtocolReceivedData
                                                                object:self
                                                              userInfo:userInfo];
            
            //It's a string until data-block, OR termination sequence is found...
            
            //First, extract full response;
            //IDENTIFIER [data bytes], Comment
            //-- Identifier is manadatory
            //-- data and comment are optional...
            NSString* identifyer = nil;
            NSString* comment = nil;
            
            // -- any data-block in there?
            NSRange dataBlockStartRange = [buffer rangeOfData:[DATA_BLOCK_START_CHAR dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:0
                                                      range:NSMakeRange(0, terminatorRange.location - 1)];
            
            if (dataBlockStartRange.location != NSNotFound)
            {
                //Found terminator!
                DDLogDebug(@"Found data block start at location %ld", dataBlockStartRange.location);
                
                //OK -- we found the beginning of a data block BEFORE our found termination index
                //-- Then identifyer is all from 0 --> this index!
                identifyer = [[NSString alloc] initWithData:[buffer subdataWithRange:NSMakeRange(0, dataBlockStartRange.location - 1)]
                                                   encoding:NSUTF8StringEncoding];
                
                DDLogDebug(@"Identifier before data block is %@", identifyer);
                
                // -- find data block end
                NSRange dataBlockEndRange = [buffer rangeOfData:[DATA_BLOCK_END_CHAR dataUsingEncoding:NSUTF8StringEncoding]
                                                      options:NSDataSearchBackwards
                                                        range:NSMakeRange(dataBlockStartRange.location + 1, terminatorRange.location - (dataBlockStartRange.location + 1))];
                
                //Found end?
                if (dataBlockEndRange.location != NSNotFound)
                {
                    //Found terminator!
                    DDLogDebug(@"Found data block end at location %ld", dataBlockEndRange.location);
                    
                    //Great!
                    self.responsePayload = [buffer subdataWithRange:NSMakeRange(dataBlockStartRange.location + 1, dataBlockEndRange.location - (dataBlockStartRange.location + 1))];
                    
                    DDLogDebug(@"Extracted payload with length %ld, contents as string %@", self.responsePayload.length, [[NSString alloc] initWithData:self.responsePayload encoding:NSUTF8StringEncoding]);
                    
                    //Then move on and find comment -- if any...
                    NSRange commentRange = [buffer rangeOfData:[COMMENT_CHAR dataUsingEncoding:NSUTF8StringEncoding]
                                                     options:0
                                                       range:NSMakeRange(dataBlockEndRange.location + 1, terminatorRange.location - (dataBlockEndRange.location + 1))];
                    if (commentRange.location != NSNotFound)
                    {
                        comment = [[NSString alloc] initWithData:[buffer subdataWithRange:NSMakeRange(commentRange.location + 1, terminatorRange.location - (commentRange.location + 1))]
                                                        encoding:NSUTF8StringEncoding];
                        
                        DDLogDebug(@"Found comment after datablock; %@", comment);
                    }
                }
                else
                {
                    //No -- no end-index found, most likely more data is needed, OR data is currupt!
                    DDLogWarn(@"Missing end of data-block, but we have a terminator. Corrupt data!");
                }
            }
            else
            {
                //No -- no data in here, just a pure terminator...
                DDLogDebug(@"Found NO data -- just pure terminator");
                
                //Then move on and find comment -- if any...
                NSRange commentRange = [buffer rangeOfData:[COMMENT_CHAR dataUsingEncoding:NSUTF8StringEncoding]
                                                 options:0
                                                   range:NSMakeRange(0, terminatorRange.location - 1)];
                if (commentRange.location != NSNotFound)
                {
                    //Identifyer is everything from 0 -> comment
                    identifyer = [[NSString alloc] initWithData:[buffer subdataWithRange:NSMakeRange(0, commentRange.location)]
                                                       encoding:NSUTF8StringEncoding];
                    
                    comment = [[NSString alloc] initWithData:[buffer subdataWithRange:NSMakeRange(commentRange.location + 1, terminatorRange.location - (commentRange.location + 1))]
                                                    encoding:NSUTF8StringEncoding];
                    
                    DDLogDebug(@"Found comment where no datablock; %@", comment);
                }
                else
                {
                    //No, no comment...
                    DDLogDebug(@"No comment -- pure identifier");
                    
                    //Identifyer is everything from 0 -> termiantion
                    identifyer = [[NSString alloc] initWithData:[buffer subdataWithRange:NSMakeRange(0, terminatorRange.location)]
                                                       encoding:NSUTF8StringEncoding];
                }
            }
            
            //Ensure that we don't have any trailing/leading white-spaces...
            identifyer = [identifyer stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
            //Make upper-case for further analysis
            identifyer = [identifyer uppercaseString];
            DDLogDebug(@"Trimmed identifyer %@", identifyer);
            
            if (comment)
            {
                //Ensure that we don't have any trailing/leading white-spaces...
                comment = [comment stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
                DDLogDebug(@"Trimmed comment %@", comment);
            }
            
            NSUInteger nbrOfConsumedBytes = terminatorRange.location + RESPONSE_COMMAND_TERMINATOR.length;
            DDLogDebug(@"NbrOfConsumed bytes from respon-buffer: %ld", nbrOfConsumedBytes);
            
            //Consume from buffer
            [buffer replaceBytesInRange:NSMakeRange(0, nbrOfConsumedBytes) withBytes:nil length:0];
            
            //Now, take action depending on what kind of response that we've found
            //-- Check if this recevied string is an event...
            NSRange eventRange = [[identifyer dataUsingEncoding:NSUTF8StringEncoding]
                                  rangeOfData:[EVENT_MATCH_STRING dataUsingEncoding:NSUTF8StringEncoding]
                                  options:NSDataSearchAnchored
                                  range:NSMakeRange(0, EVENT_MATCH_STRING.length)];
            
            if (eventRange.location != NSNotFound)
            {
                //This is an event!
                DDLogDebug(@"Identier %@ is an event!", identifyer);
                
                //OK -- strip event-prefix, and figure out which kind of event this is!
                NSString* event = [identifyer stringByReplacingCharactersInRange:eventRange withString:@""];
                event = [event stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
                DDLogDebug(@"Trimmed event %@", event);
                
                //TODO: distribute event...? OR waht else do we do with it... ;)
            }
            else
            {
                //This is NOT an event!
                DDLogDebug(@"Identier %@ is NOT an event!", identifyer);
                
                //Are we waiting for a response on a sent command=?
                if (self.lastSentInquireCommand)
                {
                    //Check if the identifier matches our last-sent-command...
                    NSRange lastSentCommandRange = [[identifyer dataUsingEncoding:NSUTF8StringEncoding]
                                                    rangeOfData:[self.lastSentInquireCommand dataUsingEncoding:NSUTF8StringEncoding]
                                                    options:NSDataSearchAnchored
                                                    range:NSMakeRange(0, self.lastSentInquireCommand.length)];
                    
                    if (lastSentCommandRange.location != NSNotFound)
                    {
                        //This is an event!
                        DDLogDebug(@"Identified as a response to last send command!");
                        
                        //Then, extract what's ever left AFTER the command, since that's the status to indicate if we're good or not...
                        NSString* status = [identifyer stringByReplacingCharactersInRange:lastSentCommandRange withString:@""];
                        status = [status stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
                        DDLogDebug(@"Trimmed status: %@", status);
                        
                        if (status && status.length > 0)
                        {
                            //Great -- so, finally -- did we do god or not?
                            if ([status isEqualToString:COMMAND_CONFIRMED_STRING])
                            {
                                //Success!
                                DDLogDebug(@"Success!");
                                
                                self.state = BleProtocolStateSuccessful;
                            }
                            else
                            {
                                //Failed!
                                DDLogDebug(@"Failed!");
                                self.state = BleProtocolStateFailed;
                                
                                //Any reason?
                                NSString* reason = nil;
                                if (comment && comment.length > 0)
                                    reason = comment;
                                else
                                    reason = @"Failed";
                                
                                self.exception = [[NSException alloc] initWithName:@"LECapProtocolFailedException"
                                                                            reason:reason
                                                                          userInfo:nil];
                            }
                            
                            //... Release semaphore so that we can proceed in our blocked inquery method!
                            DDLogInfo(@"Releaseing semaphore");
                            dispatch_semaphore_signal(self.responseBlockingSemaphore);
                        }
                        else
                        {
                            DDLogWarn(@"No status on command -- STRANGE!");
                        }
                    }
                    else
                    {
                        DDLogWarn(@"Command identifier does NOT match our pending request -- process as request from Ble to us?");
                    }
                }
                else
                {
                    DDLogWarn(@"No pending request, yet an incoming command -- process as request from Ble to us?");
                }
            }
        }
        else
        {
            //No terminator found -- then jsut ignor and wait until more data arrive...
        }
    }
}

#pragma mark - Constructors/initializers

- (id) initWithBody:(id<BleProtocolBody>)body
{
    //Kick super-initialization...
    if (self = [super init])
    {
        //And since that worked - proceed!
        _body = body;
        
        //And since that worked - proceed!
        _state = BleProtocolStateIdle;
        _inquireDataStream = nil;
        _lastSentInquireCommand = nil;
        
        _responseDataBuffer = [[NSMutableData alloc] init];
        _eventDataBuffer = [[NSMutableData alloc] init];
        _responsePayload = nil;
        _exception = nil;
        
        //Since we wait (and block) on this semaphore, let's initialize it to 0!
        _responseBlockingSemaphore = dispatch_semaphore_create(0);
        
        //Return ourselves...
        return self;
    }
    
    return nil;
}

#pragma mark - Inquire methods

- (NSData*)inquire:(NSString*)command
{
    //Kick the actual inquiry with default timeout!
    return [self inquire:command
                 timeout:dispatch_time(DISPATCH_TIME_NOW, CAP_PROTOCOL_COMM_DEFAULT_TIMEOUT * NSEC_PER_SEC)];
}

- (NSData*)inquire:(NSString*)command
           timeout:(dispatch_time_t)timeout
{
    //OK -- time to send request, so just put nil as payload...
    return [self inquire:command
                 payload:nil
                 timeout:timeout];
}

- (NSData*)inquire:(NSString*)command
           payload:(NSData*)payload
{
    //Kick the actual inquiry with default timeout!
    return [self inquire:command
                 payload:payload
                 timeout:dispatch_time(DISPATCH_TIME_NOW, CAP_PROTOCOL_COMM_DEFAULT_TIMEOUT * NSEC_PER_SEC)];
}

- (NSData*)inquire:(NSString*)command
           payload:(NSData*)payload
           timeout:(dispatch_time_t)timeout
{
    //Check is we're the main-thread, cause IFF we are, then this is not a good approach since we will block everthing...
    if ([NSThread currentThread] == [NSThread mainThread])
    {
        //Shit -- we're the main-thread! Abort this ASASP!
        DDLogInfo(@"Aborting; no go on main-thread requests...");
        NSException* exception = [[NSException alloc] initWithName:@"UnsupportedRequestThread" reason:@"Main thread NOT supported as request-thread" userInfo:nil];
        @throw exception;
    }
    
    //Check if we're idle... if we're not -- abort!
    if (self.state == BleProtocolStatePending)
    {
        //Shit -- we're already pending on a request -- Abort this ASASP!
        DDLogInfo(@"Aborting; already pending on a different request...");
        NSException* exception = [[NSException alloc] initWithName:@"RequestAlreadyPending" reason:@"Protocol is already pending for the response of a previously sent request" userInfo:nil];
        @throw exception;
    }
    
    //Create inquery buffer
    NSMutableData *inquireData = [NSMutableData data];
    
    //First, the command
    [inquireData appendData:[command dataUsingEncoding:NSUTF8StringEncoding]];
    
    //Then, the payload if any...
    if (payload && [payload length] > 0)
    {
        [inquireData appendData:[@" " dataUsingEncoding:NSUTF8StringEncoding]];
        [inquireData appendData:[DATA_BLOCK_START_CHAR dataUsingEncoding:NSUTF8StringEncoding]];
        [inquireData appendData:payload];
        [inquireData appendData:[DATA_BLOCK_END_CHAR dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    //Finally, the terminator
    [inquireData appendData:[INQUIRE_COMMAND_TERMINATOR dataUsingEncoding:NSUTF8StringEncoding]];
    
    DDLogInfo(@"Created inquire data; %@", [[NSString alloc] initWithData:inquireData
                                                                 encoding:NSUTF8StringEncoding]);
    
    //Setup input stream allowing us to "chunk-up" the inquire due to BLE/GATT constraints...
    self.inquireDataStream = [NSInputStream inputStreamWithData:inquireData];
    [self.inquireDataStream open];
    
    DDLogDebug(@"Input stream has data available; %d", [self.inquireDataStream hasBytesAvailable]);
    
    //Prepare properties needed to catch the response!
    self.lastSentInquireCommand = [command uppercaseString];
    [self.responseDataBuffer setLength:0];
    self.responsePayload = nil;
    self.exception = nil;
    self.state = BleProtocolStatePending;
    
    //Kick inquire-transfer process
    [self processInquireDataStream];

    //Setup user info
    NSMutableDictionary* userInfo = [[NSMutableDictionary alloc] init];

    //Setup userInfo with details
    [userInfo setObject:[[NSString alloc] initWithData:inquireData encoding:NSUTF8StringEncoding]
                 forKey:BleProtocolParamData];
    
    //Notify
    [[NSNotificationCenter defaultCenter] postNotificationName:BleProtocolInquireSent
                                                        object:self
                                                      userInfo:userInfo];
    
    DDLogInfo(@"Grab semaphore to block the current thread execution UNTIL we either timeout, OR get signalled by a successfully received response");
    if (dispatch_semaphore_wait(self.responseBlockingSemaphore, timeout) != 0)
    {
        //Opps -- timed out!
        DDLogInfo(@"Inquiry of command %@ timeout", command);
        
        //Indicate timeout...
        self.state = BleProtocolStateTimeout;
        self.exception = [[NSException alloc] initWithName:@"TimeoutException" reason:@"Ble failed to respond in time" userInfo:nil];
    }
    else
    {
        //Successfully received the semaphore (wait is over!)
        DDLogInfo(@"Inquiry of command %@ successfully processed (semaphore awaited without timeout)", command);
    }
    
    DDLogInfo(@"Wait is over -- proceed!");
    
    //Reset last-sent-commadn info
    self.lastSentInquireCommand = nil;
    
    //We're here -- so we're no longer "pending" -- great stuff!
    
    if (self.state == BleProtocolStateSuccessful)
    {
        //Successful response -- return response payload (if any)
        return self.responsePayload;
    }
    
    else
    {
        //Not success... Then we failed for some reason... Let's indicate that back to our invoker...!
        if (!self.exception)
        {
            //Hm.. we've failed, but without a reson/exception. Strange, but let's create a reason so that we can throw the exception already!!!
            self.exception = [[NSException alloc] initWithName:@"ProtocolFailedException" reason:@"Comm failed for unknown reason" userInfo:nil];
        }
        
        //Throw!!
        @throw self.exception;
    }
    
    return nil;
}

- (void)processInquireDataStream
{
    DDLogInfo(@"Time to transfer data from the inquire stream");
    
    //Thing is, we -- the protocol -- have the actual input buffer where we've created the packet that we need to send. But, the actual implementation/body depends might require to chunk it up into parts, so we must leave the "how" the body. Also, since differerent bodies will cause triggers in delegates in warious places in the code, the rule is that this method; "processInquireDataStream" is called when buffers are cleared and we're "ready for more".
    
    DDLogDebug(@"Input stream stream status; %lu", [self.inquireDataStream streamStatus]);
    DDLogDebug(@"Input stream has data available; %d", [self.inquireDataStream hasBytesAvailable]);
    
    //So, bascially, we ask the body to process the inquire data stream and since the body is responsible for retransmissions etc, we cannot rely on bytes kleft in teh input data stream. Hence, if a body is busy with a retransmission of previously failed chunk of data, the input data stream will not have been reduced, and might even be empty.
    //Instead, we trust that the bodyu will return process-state...
    BleProtocolBodyState state;
    do
    {
        //So -- ask body to process as long as it returns that there's more to do...
        state = [self.body processInquireDataStream:self.inquireDataStream];
    } while (state == BleProtocolBodyStateReadyForMore);
    
    //Are we done?
    if (state == BleProtocolBodyStateFinished && self.inquireDataStream && ![self.inquireDataStream hasBytesAvailable])
    {
        //Done
        DDLogInfo(@"Inquire stream was depleted and full contents has been sent!");
        
        //Clean-up
        self.inquireDataStream = nil;
        
        DDLogInfo(@"Await response before we release the semaphore...");
    }
}

- (void)processResponseData:(NSData*)data
{
    DDLogInfo(@"Processing response data %@", [[NSString alloc] initWithData:data
                                                                    encoding:NSUTF8StringEncoding]);
    
    if (data && [data length] > 0)
    {
        //append data to responseBuffer
        [self.responseDataBuffer appendData:data];
        
        //See if we have anything in there...
        [self commonParseDataBuffer:self.responseDataBuffer];
    }
}

- (void)processEventData:(NSData*)data
{
    DDLogInfo(@"Processing event data %@", [[NSString alloc] initWithData:data
                                                                 encoding:NSUTF8StringEncoding]);
    
    if (data && [data length] > 0)
    {
        //append data to responseBuffer
        [self.eventDataBuffer appendData:data];
        
        //See if we have anything in there...
        [self commonParseDataBuffer:self.eventDataBuffer];
    }
}

@end
