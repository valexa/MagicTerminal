//
//  MenuBar.m
//  MagicTerminal
//
//  Created by Vlad Alexa on 3/27/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "MenuBar.h"

#define OBSERVER_NAME_STRING @"VAMagicTerminalMenubarEvent"
#define MAIN_OBSERVER_NAME_STRING @"VAMagicTerminalEvent"

@implementation MenuBar

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
        
        defaults = [NSUserDefaults standardUserDefaults];        
        
        //register for notifications
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(theEvent:) name:OBSERVER_NAME_STRING object:nil];
        
        servers = [[NSMutableArray alloc] init];    
        clients = [[NSMutableArray alloc] init];
        
        [[NSDistributedNotificationCenter defaultCenter] postNotificationName:MAIN_OBSERVER_NAME_STRING object:nil userInfo:
         [NSDictionary dictionaryWithObjectsAndKeys:@"getNearbyServices",@"what",OBSERVER_NAME_STRING,@"callback",nil]
         ];	     
        
        //init icon
        _statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength] retain];
        [_statusItem setHighlightMode:YES];
        [_statusItem setToolTip:[NSString stringWithFormat:@"MagicTerminal"]];
        [_statusItem setImage:[NSImage imageNamed:@"mbar"]];
        [_statusItem setAlternateImage:[NSImage imageNamed:@"mbar_"]];	        
        
    }
    
    return self;
}

- (void)dealloc
{
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self];     
    [servers release];
    [clients release];    
    [super dealloc];    
}

-(void)theEvent:(NSNotification*)notif{		
	if (![[notif name] isEqualToString:OBSERVER_NAME_STRING]) {
		return;
	}		
	if ([[notif userInfo] isKindOfClass:[NSDictionary class]]){
		if ([[[notif userInfo] objectForKey:@"what"] isEqualToString:@"getNearbyServicesCallback"]){
			[servers setArray:[[notif userInfo] objectForKey:@"servers"]];
			[clients setArray:[[notif userInfo] objectForKey:@"clients"]];            
			[self loadMenu];
            if ([clients count] > 0) {
                [[NSApp dockTile] setBadgeLabel:[NSString stringWithFormat:@"%i",[clients count]]];        
            } else {
                [[NSApp dockTile] setBadgeLabel:nil];                
            }           
		}		
	}	
}

#pragma mark actions

- (void) actionQuit:(id)sender {
	[[NSStatusBar systemStatusBar] removeStatusItem:_statusItem];
	[NSApp terminate:sender];
}

- (void) showAbout:(id)sender {		
    [aboutWindow makeKeyAndOrderFront:nil];
    [NSApp arrangeInFront:aboutWindow];	
}

- (void) togDockIcon:(id)sender {		
	BOOL boo = [defaults boolForKey:@"hideDock"];	
	if (boo) {					
		[defaults setBool:NO forKey:@"hideDock"];	
	}else{	
		[defaults setBool:YES forKey:@"hideDock"];	
	}	
	[defaults synchronize];	
    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:MAIN_OBSERVER_NAME_STRING object:@"doRestart"];
	[self loadMenu];    
}

- (void) togAutostart:(id)sender {			
	BOOL noAutostart = [defaults boolForKey:@"noAutostart"];	
	if (noAutostart) {						
		[defaults setBool:NO forKey:@"noAutostart"];
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:MAIN_OBSERVER_NAME_STRING object:@"AutostartON" userInfo:nil];		
	}else{
		[defaults setBool:YES forKey:@"noAutostart"];
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName:MAIN_OBSERVER_NAME_STRING object:@"AutostartOFF" userInfo:nil];				
	}		
	[defaults synchronize];	
	[self loadMenu];
}

# pragma mark functions


-(void)loadMenu{
	//make menu
	NSMenu *menu = [self newMenu];
	[_statusItem setMenu:menu];
	[menu release];
}

- (NSMenu *) newMenu
{
	NSZone *menuZone = [NSMenu menuZone];
	NSMenu *menu = [[NSMenu allocWithZone:menuZone] init];
	[menu setAutoenablesItems:NO];
	NSMenuItem *menuItem;
	NSMenu *clientsSubMenu;
	NSMenu *serversSubMenu;
	   
	clientsSubMenu = [self newSubMenu:clients];
	menuItem = [menu addItemWithTitle:@"Clients" action:nil keyEquivalent:@""];	
	[menuItem setSubmenu:clientsSubMenu];
	[clientsSubMenu release];
    
	serversSubMenu = [self newSubMenu:servers];
	menuItem = [menu addItemWithTitle:@"Servers" action:nil keyEquivalent:@""];	
	[menuItem setSubmenu:serversSubMenu];	
	[serversSubMenu release];	
	
	// Add Separator
	[menu addItem:[NSMenuItem separatorItem]];	
    
	NSString *title;
	BOOL boo;	
	
	boo = [defaults boolForKey:@"hideDock"];		
	if (boo) {					
		title = @"Show dock icon";			
	}else{
		title = @"Hide dock icon";	
	}	
	menuItem = [menu addItemWithTitle:title action:@selector(togDockIcon:)	keyEquivalent:@""];	
	[menuItem setTarget:self];	
	
	boo = [defaults boolForKey:@"noAutostart"];	
	if (boo) {					
		title = @"Enable autostart";
	}else{
		title = @"Disable autostart";		
	}	
	menuItem = [menu addItemWithTitle:title action:@selector(togAutostart:)	keyEquivalent:@""];		
	[menuItem setTarget:self];	
    
	// Add Separator
	[menu addItem:[NSMenuItem separatorItem]];		
	
	menuItem = [menu addItemWithTitle:@"About" action:@selector(showAbout:) keyEquivalent:@""];
	NSString *toolTip = [NSString stringWithFormat:@"%@(%@)",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];
	[menuItem setToolTip:toolTip];	
	[menuItem setTarget:self];	
	
	menuItem = [menu addItemWithTitle:@"Quit MagicTerminal" action:@selector(actionQuit:) keyEquivalent:@""];
	[menuItem setTarget:self];	
	
	return menu;
}

-(NSMenu *)newSubMenu:(NSArray*)arr{
	NSMenu *subMenu = [[NSMenu alloc] init];	
	for (NSDictionary *item in arr){
        NSString *hostName = [item objectForKey:@"hostname"];
        NSString *title = @"";
        if (hostName){
            if ([[item objectForKey:@"username"] length] > 1) {
                title = [NSString stringWithFormat:@"%@@%@%@",[item objectForKey:@"username"],[item objectForKey:@"hostname"],[item objectForKey:@"model"]];                
            }else{
                title = [NSString stringWithFormat:@"%@%@",[item objectForKey:@"hostname"],[item objectForKey:@"model"]];                
            }
        }else{
            title = [item objectForKey:@"servicename"];
        }
        NSMenuItem *menuItem = [subMenu addItemWithTitle:title action:nil keyEquivalent:@""];         
		[menuItem setTarget:self];		
	}	
	return subMenu;
}

#pragma mark about window stuff

- (BOOL)application:(NSApplication *)sender delegateHandlesKey:(NSString *)key { 
    if ([key isEqualToString: @"versionString"]) return YES; 
    return NO; 
} 

- (NSString *)versionString {
	NSString *sv = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	NSString *v = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];	
	return [NSString stringWithFormat:@"version %@ (%@)",sv,v];	
}

- (IBAction) openWebsite:(id)sender{
	NSURL *url = [NSURL URLWithString:@"http://vladalexa.com/apps/osx/magicterminal"];
	[[NSWorkspace sharedWorkspace] openURL:url];
	[[NSApp keyWindow] close];
}

@end
