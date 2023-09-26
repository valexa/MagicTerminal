//
//  MagicTerminalAppDelegate.h
//  MagicTerminal
//
//  Created by Vlad Alexa on 1/15/11.
//  Copyright 2011 NextDesign. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class MagicTerminalMainCore;

@interface MagicTerminalAppDelegate : NSObject <NSApplicationDelegate> {
    MagicTerminalMainCore *main;
    NSUserDefaults *defaults;
}

- (void) restartApp;
- (void)setAutostart;
- (void)removeAutostart;

@end
