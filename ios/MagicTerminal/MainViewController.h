//
//  MainViewController.h
//  MagicTerminal
//
//  Created by Vlad Alexa on 3/4/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MainViewController : UIViewController <UITextViewDelegate,UITextFieldDelegate,UIPickerViewDelegate,UIPickerViewDataSource>{
    NSUserDefaults *defaults;    
	UIImageView *outputImg;
	UITextView  *outputView;    	
	UITextField *pathView;    
	UITextField *inputView;
    UIButton *retButton;
    UIButton *histButton;
    UIButton *xButton;
    UIActivityIndicatorView *spinner; 
    NSDictionary *data;
    UIPickerView *picker;
}

@property (nonatomic, retain) UITextField *inputView;
@property (nonatomic, retain) UITextField *pathView;
@property (nonatomic, retain) UITextView *outputView;
@property (nonatomic, retain) NSDictionary *data;

- (void)syncLayout;
- (void)gotReply;
-(void)sendCommand;
-(NSString*)caretString;
-(UIImage *)UIImageFromPDF:(NSString*)fileName size:(CGSize)size;
-(void)animateBlink:(id)target;

@end
