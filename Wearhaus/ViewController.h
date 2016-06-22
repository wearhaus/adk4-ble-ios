//
//  ViewController.h
//  Wearhaus
//
//  Created by Markus Millfjord on 2015-02-05.
//  Copyright (c) 2015 Millcode. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITableView *dataTable;
@property (weak, nonatomic) IBOutlet UITextField *inquireTextfield;
@property (weak, nonatomic) IBOutlet UIButton *sendButton;

- (IBAction)sendButtonPressed:(id)sender;

@end

