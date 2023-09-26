//
//  BonjourController.h
//  MagicTerminal
//
//  Created by Vlad Alexa on 3/4/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

@interface BonjourController : NSObject <NSNetServiceBrowserDelegate,NSNetServiceDelegate,UIAlertViewDelegate> {
    NSUserDefaults *defaults;
	NSNetServiceBrowser		*browser;
    NSMutableArray *servers;    
    BOOL    serviceStarted;
    NSFileHandle	*listeningSocket;  
	NSNetService	*netService; 
    int resolving;
    NSString *serviceName;
}

@property (nonatomic, retain) NSMutableArray *servers;

-(BOOL) serverIsPaired:(NSNetService *)aNetService;
-(void) toggleBonService;
-(void) sendCommand:(NSString*)command withPath:(NSString*)thePath andID:(NSString*)theId;
-(int)getIdOfServiceNamed:(NSString*)name;
-(NSString*)getServerUUID:(NSNetService *)server;

@end
