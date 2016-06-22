//
//  Header.h
//  Ble
//
//  Created by Markus Millfjord on 2014-12-19.
//  Copyright (c) 2014 Millcode AB. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, BleProtocolBodyState) {
    BleProtocolBodyStateReadyForMore = 0,
    BleProtocolBodyStateInterrupted,
    BleProtocolBodyStateFinished
};

@protocol BleProtocolBody <NSObject>

- (BleProtocolBodyState) processInquireDataStream:(NSInputStream*)inputStream;

@end
