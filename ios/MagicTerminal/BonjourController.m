//
//  BonjourController.m
//  MagicTerminal
//
//  Created by Vlad Alexa on 3/4/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "BonjourController.h"

//Service name must be 1-63 characters 
#define SERVICE_NAME	@"MagicTerminal Client"
//Application protocol name must be underscore plus 1-15 characters. See <http://www.dns-sd.org/ServiceTypes.html> 
#define SERVICE_CLIENT	@"_mtermc._tcp."
#define SERVICE_SERVER	@"_mterms._tcp."


#define OBSERVER_NAME_STRING @"MagicTerminalEvent"

@implementation BonjourController

@synthesize servers;

- (id)init {
    self = [super init];
    if (self) {
        
        serviceName = [[NSString alloc] initWithFormat:@"%@ %f",SERVICE_NAME,CFAbsoluteTimeGetCurrent()];
        if ([serviceName length] > 63) {
            int diff = [serviceName length] - 63;
            NSLog(@"Service name \"%@\" %i chars too long",serviceName,diff);
            return self;
        }        
        
        //alloc defaults
        defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults objectForKey:@"pairedServers"] == nil) {
            [defaults setObject:[NSArray array] forKey:@"pairedServers"];
            [defaults synchronize];
        }        
        
        serviceStarted = NO;
        resolving = 0;                
        
        //search for servers
        servers = [[NSMutableArray alloc] init];
        browser = [[NSNetServiceBrowser alloc] init];
        [browser setDelegate:self];        
        [browser searchForServicesOfType:SERVICE_SERVER inDomain:@""];        
        
        //start app server
        [self toggleBonService];                  

        
    }
    return self;
}

- (void)dealloc {   
    [browser release];    
    [servers release];
    [serviceName release]; //must be released after servers or crashes   
    if(netService || listeningSocket) NSLog(@"BonjourController leaking");    
    //NSLog(@"BonjourController freed");  
    [super dealloc];    
}

-(BOOL) serverIsPaired:(NSNetService *)server{
    NSString *uuid = [self getServerUUID:server];    
    for (NSString *pid in [defaults objectForKey:@"pairedServers"]) {
        if ([pid isEqualToString:uuid]) {
            return YES;
        }
    }
    return NO;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
	if ([alertView.title isEqualToString:@"Pairing Required"]){
		if (buttonIndex == 1) {
            UITextField *input = nil;            
            for (id view in [alertView subviews]) {
                if ([view isMemberOfClass:[UITextField class]]) {
                    input = view;
                }
            }
            if (input) {
                //compare the codes
                if ([[input text] intValue] == [input tag]) {
                    //save
                    NSNetService *service = [servers objectAtIndex:[alertView tag]];             
                    NSString *uuid = [self getServerUUID:service];                    
                    NSMutableArray *arr = [[defaults objectForKey:@"pairedServers"] mutableCopy];
                    [arr addObject:uuid];
                    [defaults setObject:arr forKey:@"pairedServers"];
                    [defaults synchronize];
                    [arr release];                            
                }                
            }
		}		
	}		
}

-(void) toggleBonService {
	uint16_t chosenPort = 0;
    
    if(!listeningSocket) {
        // Here, create the socket from traditional BSD socket calls, and then set up an NSFileHandle with that to listen for incoming connections.
        int fdForListening;
        struct sockaddr_in serverAddress;
        socklen_t namelen = sizeof(serverAddress);
		
        // In order to use NSFileHandle's acceptConnectionInBackgroundAndNotify method, we need to create a file descriptor that is itself a socket, bind that socket, and then set it up for listening. At this point, it's ready to be handed off to acceptConnectionInBackgroundAndNotify.
        if((fdForListening = socket(AF_INET, SOCK_STREAM, 0)) > 0) {
            memset(&serverAddress, 0, sizeof(serverAddress));
            serverAddress.sin_family = AF_INET;
            serverAddress.sin_addr.s_addr = htonl(INADDR_ANY);
            serverAddress.sin_port = 0; // allows the kernel to choose the port for us.
			
            if(bind(fdForListening, (struct sockaddr *)&serverAddress, sizeof(serverAddress)) < 0) {
                close(fdForListening);
                return;
            }
			
            // Find out what port number was chosen for us.
            if(getsockname(fdForListening, (struct sockaddr *)&serverAddress, &namelen) < 0) {
                close(fdForListening);
                return;
            }
			
            chosenPort = ntohs(serverAddress.sin_port);
            
            if(listen(fdForListening, 1) == 0) {
                listeningSocket = [[NSFileHandle alloc] initWithFileDescriptor:fdForListening closeOnDealloc:YES];
            }
        }
    }
    
    if(!netService) {
        // lazily instantiate the NSNetService object that will advertise on our behalf.
        netService = [[NSNetService alloc] initWithDomain:@"local." type:SERVICE_CLIENT name:serviceName port:chosenPort];        
        [netService setTXTRecordData:[NSNetService dataFromTXTRecordDictionary:[NSDictionary dictionaryWithObject:[UIDevice currentDevice].model forKey:@"machine"]]];          
        [netService setDelegate:self];
    }
    
    if(netService && listeningSocket) {
        if(!serviceStarted) {
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionReceived:) name:NSFileHandleConnectionAcceptedNotification object:listeningSocket];
            [listeningSocket acceptConnectionInBackgroundAndNotify];
            [netService publish];  
            NSLog(@"Published :%@,%@",SERVICE_CLIENT,serviceName);            
        } else {
            [netService stop];
            [netService release];
            netService = nil;
            [[NSNotificationCenter defaultCenter] removeObserver:self name:NSFileHandleConnectionAcceptedNotification object:listeningSocket];
            // There is at present no way to get an NSFileHandle to -stop- listening for events, so we'll just have to tear it down and recreate it the next time we need it.
            [listeningSocket closeFile];            
            [listeningSocket release];
            listeningSocket = nil;
			serviceStarted = NO;
            NSLog(@"Stopped :%@,%@",SERVICE_CLIENT,serviceName);               
        }
    }
	
}

#pragma mark NSNetServiceBrowser delegates

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    //NSLog(@"Found service %@",aNetService.name);
    [self willChangeValueForKey:@"servers"]; 
	[servers addObject:aNetService];	
    [aNetService setDelegate:self];	
    [aNetService resolveWithTimeout:5.0];
    resolving ++;
	if(!moreComing) [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(checkResolver) userInfo:nil repeats:NO];	
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    //NSLog(@"Lost service %@",aNetService.name); 
    [self willChangeValueForKey:@"servers"];     
	[servers removeObject:aNetService];
	if(!moreComing) [self didChangeValueForKey:@"servers"];	
}

#pragma mark NSNetService delegates

- (void)netServiceDidPublish:(NSNetService *)sender{
    //NSLog(@"Service published: %@",[sender name]);
    serviceStarted = YES;    
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict{
    NSString *err = @"";
    if([[errorDict objectForKey:NSNetServicesErrorCode] intValue] == NSNetServicesCollisionError) err = @"NSNetServicesCollisionError";  
    if([[errorDict objectForKey:NSNetServicesErrorCode] intValue] == NSNetServicesNotFoundError) err = @"NSNetServicesNotFoundError";   
    if([[errorDict objectForKey:NSNetServicesErrorCode] intValue] == NSNetServicesActivityInProgress) err = @"NSNetServicesActivityInProgress";
    if([[errorDict objectForKey:NSNetServicesErrorCode] intValue] == NSNetServicesBadArgumentError) err = @"NSNetServicesBadArgumentError"; 
    if([[errorDict objectForKey:NSNetServicesErrorCode] intValue] == NSNetServicesTimeoutError) err = @"NSNetServicesTimeoutError";     
    NSLog(@"ERROR publishing service: %@ (%@)",[sender name],err);    
    [listeningSocket closeFile];    
    [listeningSocket release];
    listeningSocket = nil;
    [netService stop];    
    [netService release];
    netService = nil;      
}

- (void)netServiceDidResolveAddress:(NSNetService *)sender{
    //NSLog(@"Service resolved: %@ to %@",[sender name],[sender hostName]);
    resolving --;    
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict{
    NSLog(@"ERROR resolving service: %@",[sender name]);
    CFShow(errorDict);
    resolving --;    
}

#pragma mark connections

// When an incoming connection is seen by the listeningSocket object, we get the NSFileHandle representing the near end of the connection.
- (void)connectionReceived:(NSNotification *)aNotification {
    NSFileHandle *otherEndSocket = [[aNotification userInfo] objectForKey:NSFileHandleNotificationFileHandleItem];
    if (listeningSocket != [aNotification object]) {
        NSLog(@"Socket Error");
        return;
    }  
    
    //read all data chunks as they come in
    NSData *inData = nil;
    NSMutableString *inString = [[[NSMutableString alloc] init] autorelease];    
    while ( (inData = [otherEndSocket availableData]) && [inData length] ) {
        NSString *str = [[NSString alloc] initWithFormat:@"%.*s", [inData length], [inData bytes]];
        [inString appendString: str];
        [str release];
    }     
    
    //only read the last chunk of data
    //NSData *inData = [otherEndSocket availableData];
    //NSString *inString = [[[NSString alloc] initWithData:inData encoding:NSASCIIStringEncoding] autorelease];

    NSArray *pieces = [inString componentsSeparatedByString:@":"];
    if ([pieces count] < 3) {
        NSLog(@"Unhandled message %@",inString);
    }else{        
        NSString *server = [pieces objectAtIndex:0];        
        NSString *type = [pieces objectAtIndex:1]; 
        NSString *theid = [NSString stringWithFormat:@"%i",[self getIdOfServiceNamed:server]];        
        if ([type isEqualToString:@"MagicTerminalPairReply"]) {    
            NSString *code = [pieces objectAtIndex:2];             
            
            UIAlertView *sendAlert = [[UIAlertView alloc] initWithTitle:@"Pairing Required" message:@"Look at the screen of the machine for the pairing code and enter it below.\n\n" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Pair", nil];                                              				                                             		
            [sendAlert setTag:[theid intValue]];
            
            UITextField *searchField = [[UITextField alloc] initWithFrame:CGRectMake(100,110,90,28)];
            searchField.font = [UIFont systemFontOfSize:26];
            searchField.borderStyle = UITextBorderStyleRoundedRect;
            searchField.returnKeyType = UIReturnKeyDone;
            searchField.keyboardType = UIKeyboardTypeNumberPad;
            searchField.placeholder = @"00000";
            [searchField setContentVerticalAlignment:UIControlContentVerticalAlignmentCenter];
            [searchField setTextAlignment:UITextAlignmentCenter];	            
            [searchField becomeFirstResponder];
            [searchField setTag:[code intValue]];
            [sendAlert addSubview:searchField];
            [searchField release];
            
            [sendAlert show];
            [sendAlert release];      
            [[NSNotificationCenter defaultCenter] postNotificationName:OBSERVER_NAME_STRING object:nil userInfo:
             [NSDictionary dictionaryWithObjectsAndKeys:@"reply",@"what",theid,@"theid",@"",@"value",nil]
             ];            
        } else if ([type isEqualToString:@"MagicTerminalExecReply"]) { 
            int index = [server length] + [type length] + 3 - 1;
            if ([inString length] >= index) {
                if ([inString length] == index) NSLog(@"Empty reply : %@",inString);
                NSString *reply = [inString substringFromIndex:index];
                //NSLog(@"Got reply : %@",reply);
                [[NSNotificationCenter defaultCenter] postNotificationName:OBSERVER_NAME_STRING object:nil userInfo:
                 [NSDictionary dictionaryWithObjectsAndKeys:@"reply",@"what",theid,@"theid",reply,@"value",nil]
                 ];                               
            }else{
                NSLog(@"Bad reply type %@ in %@",type,inString);                
            }
        } else {
            NSLog(@"Unknown message type %@ in %@",type,inString);
        }                 
    }        
       
    
    [listeningSocket acceptConnectionInBackgroundAndNotify]; //recycle the socket      
}

-(void) sendCommand:(NSString*)command withPath:(NSString*)thePath andID:(NSString*)theId{
	NSNetService *service = [servers objectAtIndex:[theId intValue]];    	
	if(service) {
        if ([self serverIsPaired:service] == NO) {
            command = [NSString stringWithFormat:@"%@:MagicTerminalPairRequest:%@:%u",serviceName,thePath,arc4random()]; 
        }else{
            command = [NSString stringWithFormat:@"%@:MagicTerminalExecRequest:%@:%@",serviceName,thePath,command];                                  
        }    
        NSData *appData = [command dataUsingEncoding:NSUTF8StringEncoding];        
        NSOutputStream *outStream;
        NSInputStream *inStream;            
        [service getInputStream:&inStream outputStream:&outStream];
        //start writing
        [outStream open];           
        int bytes = [outStream write:[appData bytes] maxLength:[appData length]];
        [outStream close];		
        if (bytes != [appData length]) {
            NSLog(@"ERROR Wrote %i bytes but should have written %u",bytes,[appData length]);     
        }else{
            //NSLog(@"Wrote %i bytes (%@) to [%@]",bytes,command,service.name);             
        }  
        //done writing, prepare for reading, does not seem to be needed and appears to cause crashes
        //[inStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        //[inStream open];                     
         
	}else{
        NSLog(@"ERROR getting server");
    }
}

-(int)getIdOfServiceNamed:(NSString*)name{
    int ret = 0;
    for (NSNetService *service in servers) {
        if ([[service name] isEqualToString:name]) return ret;
        ret++;
    }
    NSLog(@"Failed to get id for service: %@",name);
    return -1;
}

-(NSString*)getServerUUID:(NSNetService *)server{
    NSDictionary *dict = [NSNetService dictionaryFromTXTRecordData:server.TXTRecordData];
    NSString *uuid = [[NSString alloc] initWithData:[dict objectForKey:@"uuid"] encoding:NSASCIIStringEncoding];
    if ([uuid length] < 10) {
        NSLog(@"Error getting UUID for %@",server.name);
    }
    return [uuid autorelease];
}

-(void)checkResolver{
    if (resolving == 0){
        [self didChangeValueForKey:@"servers"];	        
    }else{
        [NSTimer scheduledTimerWithTimeInterval:2.5 target:self selector:@selector(checkResolver) userInfo:nil repeats:NO];	        
    }
}

@end
