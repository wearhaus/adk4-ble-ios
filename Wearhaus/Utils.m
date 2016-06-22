//
//  Utils.m
//  Ble
//
//  Created by Markus Millfjord on 2015-02-07.
//

#import "Utils.h"

@implementation Utils

+ (BOOL)isValidSerialNumber:(NSString *)string
{
    /* Must be atleast x length */
    if (string.length >= 2)
    {
/*        //Must begin with @"ER"
        if (![[string substringToIndex:2] isEqualToString:@"ER"])
        {
            return NO;
        }
*/
        //Must be "full length" serial number
        if (string.length != 8)
        {
            return NO;
        }
        
        //All characters after the initial @"ER" MUST be digits forming an integer value
        NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
        [f setAllowsFloats: NO];
        if ([f numberFromString:[string substringFromIndex:2]] == nil)
        {
            return NO;
        }
        
        //We passed!
        return YES;
    }
    
    return NO;
}

@end
