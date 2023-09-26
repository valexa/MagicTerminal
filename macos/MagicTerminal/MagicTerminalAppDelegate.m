//
//  MagicTerminalAppDelegate.m
//  MagicTerminal
//
//  Created by Vlad Alexa on 1/15/11.
//  Copyright 2011 NextDesign. All rights reserved.
//

#import "MagicTerminalAppDelegate.h"
#import "MagicTerminalMainCore.h"

#define OBSERVER_NAME_STRING @"VAMagicTerminalEvent"

@implementation MagicTerminalAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	// Insert code here to initialize your application 
	
	main = [[MagicTerminalMainCore alloc] init];
		
	defaults = [NSUserDefaults standardUserDefaults];	
    
	[[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(theEvent:) name:OBSERVER_NAME_STRING object:nil];	    
	    
	if ([[defaults objectForKey:@"hideDock"] boolValue] == NO) {
		// display dock icon		
		ProcessSerialNumber psn = { 0, kCurrentProcess };
		TransformProcessType(&psn, kProcessTransformToForegroundApplication);
	}	  
    
    if ([defaults objectForKey:@"noAutostart"] == nil){
        [defaults setBool:YES forKey:@"noAutostart"];        
        [defaults synchronize];
    }
    
}

-(void)dealloc{
	[[NSDistributedNotificationCenter defaultCenter] removeObserver:self];     
	[main release];	       
	[super dealloc];    
}


-(void)theEvent:(NSNotification*)notif{	
	if (![[notif name] isEqualToString:OBSERVER_NAME_STRING]) {		
		return;
	}	
	if ([[notif object] isKindOfClass:[NSString class]]){
		if ([[notif object] isEqualToString:@"doRestart"]){
			[self restartApp];
		}
		if ([[notif object] isEqualToString:@"AutostartON"]){
			[self setAutostart];
		}
		if ([[notif object] isEqualToString:@"AutostartOFF"]){
			[self removeAutostart];
		}	
		if ([[notif object] isEqualToString:@"setBadge"]){
			[self removeAutostart]; 
		}	                
	}
	if ([[notif userInfo] isKindOfClass:[NSDictionary class]]){    

    }    
}

-(void) restartApp{
	//ignores plist launch settings and freezes if launched from xcode
	NSString *fullPath = [[NSBundle mainBundle] executablePath];
	[NSTask launchedTaskWithLaunchPath:fullPath arguments:[NSArray arrayWithObjects:nil]];
	[NSApp terminate:self];
}

- (void)setAutostart{
	UInt32 seedValue;
	CFURLRef thePath;
	CFURLRef currentPath = (CFURLRef)[NSURL fileURLWithPath:[[NSBundle mainBundle] bundlePath]];	
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);	
	if (loginItems) {
		//add it to startup list
		LSSharedFileListItemRef item = LSSharedFileListInsertItemURL(loginItems, kLSSharedFileListItemLast, NULL, NULL, currentPath, NULL, NULL);		
		if (item){
			NSLog(@"Added login item %@",CFURLGetString(currentPath));			
			CFRelease(item);		
		}else{
			NSLog(@"Failed to set to autostart from %@",CFURLGetString(currentPath));
		}
		//remove entries of same app with different paths	
		NSArray  *loginItemsArray = (NSArray *)LSSharedFileListCopySnapshot(loginItems, &seedValue);
		for (id item in loginItemsArray) {		
			LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)item;
			CFStringRef currentPathComponent = CFURLCopyLastPathComponent(currentPath);
			if (LSSharedFileListItemResolve(itemRef, 0, (CFURLRef*) &thePath, NULL) == noErr) {
				CFStringRef thePathComponent = CFURLCopyLastPathComponent(thePath);
				if (CFStringCompare(thePathComponent,currentPathComponent,0) == kCFCompareEqualTo
					&& CFStringCompare(CFURLGetString(thePath),CFURLGetString(currentPath),0) != kCFCompareEqualTo	){
					LSSharedFileListItemRemove(loginItems, itemRef);
					//NSLog(@"Deleting duplicate login item at %@",CFURLGetString(thePath));				
				}
				CFRelease(thePathComponent);
				CFRelease(thePath);				
			}else{
				CFStringRef displayNameComponent = LSSharedFileListItemCopyDisplayName(itemRef);				
				//also remove those with path that do not resolve
				if (CFStringCompare(displayNameComponent,currentPathComponent,0) == kCFCompareEqualTo) {
					LSSharedFileListItemRemove(loginItems, itemRef);	
					//NSLog(@"Deleting duplicate and broken login item %@",LSSharedFileListItemCopyDisplayName(itemRef));	
				}
				CFRelease(displayNameComponent);				
			}
			CFRelease(currentPathComponent);
			//CFRelease(itemRef);			
		}
		[loginItemsArray release];		
		CFRelease(loginItems);		
	}else{
		NSLog(@"Failed to get login items");
	}
	//CFRelease(currentPath);
}

- (void)removeAutostart{
	UInt32 seedValue;
	LSSharedFileListRef loginItems = LSSharedFileListCreate(NULL, kLSSharedFileListSessionLoginItems, NULL);	
	if (loginItems) {
		//remove entries of same app	
		NSArray  *loginItemsArray = (NSArray *)LSSharedFileListCopySnapshot(loginItems, &seedValue);
		for (id item in loginItemsArray) {		
			LSSharedFileListItemRef itemRef = (LSSharedFileListItemRef)item;
			CFStringRef name = LSSharedFileListItemCopyDisplayName(itemRef);
			if (CFStringCompare(name,CFSTR("MagicTerminal.app"),0) == kCFCompareEqualTo){
				LSSharedFileListItemRemove(loginItems, itemRef);
				NSLog(@"Deleted login item %@",name);				
			}
			//CFRelease(itemRef);	
			CFRelease(name);							
		}
		[loginItemsArray release];	
		CFRelease(loginItems);		
	}else{
		NSLog(@"Failed to get login items");
	}
}

@end
