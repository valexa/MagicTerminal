//
//  MagicTerminalAppDelegate.m
//  MagicTerminal
//
//  Created by Vlad Alexa on 3/4/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "MagicTerminalAppDelegate.h"
#import "BonjourController.h"
#import "MainViewController.h"
#include <dlfcn.h>

#define OBSERVER_NAME_STRING @"MagicTerminalEvent"

@implementation MagicTerminalAppDelegate


@synthesize window=_window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    
	// Set the style to black so it matches the background of the application
	[application setStatusBarStyle:UIStatusBarStyleBlackOpaque animated:NO];
	// Now show the status bar
	[application setStatusBarHidden:NO];    
    	 	
    //listen for events
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(theEvent:) name:OBSERVER_NAME_STRING object:nil];    
    
	controller = [[UITabBarController alloc] init]; 	
    controller.delegate = self;
    
    self.window.rootViewController = controller;    
	[self.window addSubview:[controller view]];    
    [self.window makeKeyAndVisible];
    
    preservedTabs = [[NSMutableArray alloc] init];
        
    return YES;
}

- (void)serverNotice:(NSTimer*)timer
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Unable to find any server" message:@"Make sure a MagicTerminal server is running on a machine that is on the same network as this MagicTerminal client." delegate:nil cancelButtonTitle:@"OK, keep looking." otherButtonTitles:nil];
    [alert show];
    [alert release];
    serverNotice = nil;    
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    [bonjourController removeObserver:self forKeyPath:@"servers"];    
    [bonjourController toggleBonService];
    [bonjourController release];
    bonjourController = nil;
    [preservedTabs removeAllObjects];
    [preservedTabs addObjectsFromArray:controller.viewControllers];
    controller.viewControllers = nil;
    [serverNotice invalidate];
    serverNotice = nil;    
    //NSLog(@"applicationWillResignActive");    
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    //NSLog(@"applicationDidEnterBackground");
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    //NSLog(@"applicationDidBecomeActive");
	serverNotice = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(serverNotice:) userInfo:nil repeats:NO];    
    bonjourController = [[BonjourController alloc] init];         
    [bonjourController addObserver:self forKeyPath:@"servers" options:NSKeyValueObservingOptionOld context:NULL];
    [self syncUI];
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}

- (void)dealloc
{
    [controller release];
    [_window release];
    [preservedTabs release];
	[[NSNotificationCenter defaultCenter] removeObserver:self];     
    [super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	if (object == bonjourController){	
        if ([keyPath isEqualToString:@"servers"]) {         
            [self syncUI];  
            [serverNotice invalidate];
            serverNotice = nil;
        }
	}	
}

-(void)theEvent:(NSNotification*)notif{			
	if (![[notif name] isEqualToString:OBSERVER_NAME_STRING]) {		
		return;
	}	
	if ([[notif object] isKindOfClass:[NSString class]]){	
        
	}	
	if ([[notif userInfo] isKindOfClass:[NSDictionary class]]){
        if ([[[notif userInfo] objectForKey:@"what"] isEqualToString:@"reply"]){			
            int theid = [[[notif userInfo] objectForKey:@"theid"] intValue];
            NSString *value = [[notif userInfo] objectForKey:@"value"];
            if ([controller.viewControllers count] > theid) {
                MainViewController *cont = [controller.viewControllers objectAtIndex:theid];
                if (cont == nil) return; //TODO
                if ([cont.outputView.text length] < 200000) {
                    [cont.outputView setText:[cont.outputView.text stringByAppendingString:value]];                                       
                }else{
                    [cont.outputView setText:value];                    
                    [cont animateBlink:nil];                    
                    NSLog(@"Display exceeded 200000 chars, clearing");                    
                }                
                cont.outputView.selectedRange = NSMakeRange(cont.outputView.text.length - 1, 0);
                [cont gotReply];
            }else{
                NSLog(@"Error for %i",theid);
            }
        } 
        if ([[[notif userInfo] objectForKey:@"what"] isEqualToString:@"command"]){	
            NSString *theid = [[notif userInfo] objectForKey:@"theid"];
            NSString *command = [[notif userInfo] objectForKey:@"command"]; 
            NSString *path = [[notif userInfo] objectForKey:@"path"];             
            [bonjourController sendCommand:command withPath:path andID:theid];
        }    
    }    	
}

- (void)syncUI{
    controller.viewControllers = nil;    
    int tag = 0;    
    NSMutableArray *tabs = [NSMutableArray arrayWithCapacity:1];
    for (NSNetService *server in bonjourController.servers) {
        BOOL exists = NO;        
        //reuse existing ones in order to preserve data displayed in them
        NSDictionary *data = [self getTXTDict:server];                
        for (MainViewController *cont in preservedTabs) {
            if ([cont isMemberOfClass:[MainViewController class]]) {
                if ([cont.data isEqualToDictionary:data]) {
                    [cont.inputView setTag:tag];                
                    [tabs addObject:cont];
                    exists = YES;
                    continue;
                }                
            }
        }          
        //add new ones
        if (exists == NO) {
            UIImage *image = [self getMachineImage:[data objectForKey:@"model"]];
            NSString *name = [NSString stringWithFormat:@"%@@%@",[data objectForKey:@"username"],[server.hostName stringByReplacingOccurrencesOfString:@".local." withString:@""]];        
            NSString *title = [self truncateString:name largerThan:12];            
            MainViewController *cont = [[MainViewController alloc] init];
            cont.data = data;
            [cont.inputView setTag:tag];
            cont.tabBarItem.title = title;
            cont.tabBarItem.image = image; 
            cont.tabBarItem.tag = tag;            
            [tabs addObject:cont];
            [cont release];
        }           
        tag++;       
    }   
    if (tag == 0) {
        UIViewController *cont = [[UIViewController alloc] init];  
        cont.tabBarItem.image = [self UIImageFromPDF:@"search.pdf" size:CGSizeMake(26,26)];
        cont.tabBarItem.title = @"Waiting for servers";        
        [tabs addObject:cont];
        [cont release];
    }
    controller.viewControllers = tabs;    
}

-(UIImage *)UIImageFromPDF:(NSString*)fileName size:(CGSize)size{
	CFURLRef pdfURL = CFBundleCopyResourceURL(CFBundleGetMainBundle(), (CFStringRef)fileName, NULL, NULL);	
	if (pdfURL) {		
		CGPDFDocumentRef pdf = CGPDFDocumentCreateWithURL(pdfURL);
		CFRelease(pdfURL);	
		//create context with scaling 0.0 as to get the main screen's if iOS4+
		if (dlsym(RTLD_DEFAULT,"UIGraphicsBeginImageContextWithOptions") == NULL) {
			UIGraphicsBeginImageContext(size);				
		}else {
			UIGraphicsBeginImageContextWithOptions(size,NO,0.0);						
		}
		CGContextRef context = UIGraphicsGetCurrentContext();		
		//translate the content
		CGContextTranslateCTM(context, 0.0, size.height);	
		CGContextScaleCTM(context, 1.0, -1.0);		
		CGContextSaveGState(context);	
		//scale to our desired size
		CGPDFPageRef page = CGPDFDocumentGetPage(pdf, 1);
		CGAffineTransform pdfTransform = CGPDFPageGetDrawingTransform(page, kCGPDFCropBox, CGRectMake(0, 0, size.width, size.height), 0, true);
		CGContextConcatCTM(context, pdfTransform);
		CGContextDrawPDFPage(context, page);	
		CGContextRestoreGState(context);
		//return autoreleased UIImage
		UIImage *ret = UIGraphicsGetImageFromCurrentImageContext(); 	
		UIGraphicsEndImageContext();
		CGPDFDocumentRelease(pdf);		
		return ret;		
	}else {
		NSLog(@"Could not load %@",fileName);
	}
	return nil;	
}

-(UIImage*)getMachineImage:(NSString*)name{
    UIImage *ret = [UIImage imageNamed:name];
    if ([name rangeOfString:@"MacBook"].location != NSNotFound) ret = [UIImage imageNamed:@"MacBook"];
    if (ret) {
        return ret;
    }else{
        return [self UIImageFromPDF:@"help.pdf" size:CGSizeMake(26,26)];
    }
}

-(NSDictionary*)getTXTDict:(NSNetService *)server{
    NSDictionary *dict = [NSNetService dictionaryFromTXTRecordData:server.TXTRecordData];
    NSString *username = [[[NSString alloc] initWithData:[dict objectForKey:@"user"] encoding:NSASCIIStringEncoding] autorelease];
    NSString *uuid = [[[NSString alloc] initWithData:[dict objectForKey:@"uuid"] encoding:NSASCIIStringEncoding] autorelease];
    NSString *model = [[[NSString alloc] initWithData:[dict objectForKey:@"machine"] encoding:NSASCIIStringEncoding] autorelease];    
    return [NSDictionary dictionaryWithObjectsAndKeys:username,@"username",server.hostName,@"hostname",uuid,@"uuid",model,@"model",server.name,@"servicename", nil];
}

-(NSString*)truncateString:(NSString*)str largerThan:(int)limit{
    if( [str length] > limit ) {
        return [[str substringToIndex:limit] stringByAppendingString:@"..."];
    } else{
        return str;
    }   
}

@end
