//
//  MenuBar.h
//  MagicTerminal
//
//  Created by Vlad Alexa on 3/27/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface MenuBar : NSObject {
    NSUserDefaults *defaults;    
    NSMutableArray *servers;    
    NSMutableArray *clients; 
	IBOutlet NSWindow *aboutWindow;    
@private
	NSStatusItem *_statusItem;	    
}


- (void) actionQuit:(id)sender;
- (void) showAbout:(id)sender;		
- (void) togDockIcon:(id)sender;	
- (void) togAutostart:(id)sender;

-(void)loadMenu;
-(NSMenu*)newMenu;
-(NSMenu*)newSubMenu:(NSArray*)arr;

@end
