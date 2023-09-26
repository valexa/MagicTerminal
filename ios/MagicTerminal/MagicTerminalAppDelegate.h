//
//  MagicTerminalAppDelegate.h
//  MagicTerminal
//
//  Created by Vlad Alexa on 3/4/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BonjourController;


@interface MagicTerminalAppDelegate : NSObject <UIApplicationDelegate,UITabBarControllerDelegate> {

	UITabBarController *controller;    
    BonjourController *bonjourController;
    NSMutableArray *preservedTabs;
    NSTimer *serverNotice;    
}

@property (nonatomic, retain) IBOutlet UIWindow *window;

- (void)syncUI;
-(UIImage *)UIImageFromPDF:(NSString*)fileName size:(CGSize)size;
-(UIImage*)getMachineImage:(NSString*)name;
-(NSString*)truncateString:(NSString*)str largerThan:(int)limit;
-(NSDictionary*)getTXTDict:(NSNetService *)server;
@end
