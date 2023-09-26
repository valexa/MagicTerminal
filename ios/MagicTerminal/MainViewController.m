//
//  MainViewController.m
//  MagicTerminal
//
//  Created by Vlad Alexa on 3/4/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "MainViewController.h"
#include <dlfcn.h>
#import <QuartzCore/CoreAnimation.h>

#define OBSERVER_NAME_STRING @"MagicTerminalEvent"

@implementation MainViewController

@synthesize inputView,outputView,pathView,data;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization  
        
        //alloc defaults
        defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults objectForKey:@"history"] == nil) {
            [defaults setObject:[NSArray array] forKey:@"history"];
            [defaults synchronize];
        }          
        
        self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"bg.png"]];				
        
        //set background image 
        UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed: @"top.png"]];
        //imageView.frame = CGRectMake(0, 0, 1024, 57);	
        [self.view addSubview:imageView]; 
        [imageView release]; 
        
        //add output
        UIImage *outImage =[[UIImage imageNamed:@"output.png"] stretchableImageWithLeftCapWidth:200 topCapHeight:40];		
        outputImg = [[UIImageView alloc] initWithImage:outImage];
        [self.view addSubview:outputImg];         
        
        outputView = [[UITextView alloc] initWithFrame:CGRectZero];	
        outputView.inputView = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
        outputView.autocorrectionType = UITextAutocorrectionTypeNo;        
        outputView.font = [UIFont fontWithName:@"Courier" size:14];		
        outputView.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.1];
        outputView.textColor = [UIColor whiteColor];	
        outputView.delegate = self;	
        [outputView setEditable:NO];
        [self.view addSubview:outputView];	 
            
        pathView = [[UITextField alloc] initWithFrame:CGRectZero];
        pathView.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
        pathView.keyboardAppearance = UIKeyboardAppearanceAlert;	
        pathView.textColor = [UIColor whiteColor];
        pathView.adjustsFontSizeToFitWidth = YES;
        pathView.font = [UIFont fontWithName:@"Courier" size:14];	        
        pathView.backgroundColor = [UIColor clearColor];	
        pathView.clearButtonMode = UITextFieldViewModeWhileEditing;
        pathView.enablesReturnKeyAutomatically = YES;
        pathView.autocorrectionType = UITextAutocorrectionTypeNo;
        pathView.autocapitalizationType = UITextAutocapitalizationTypeNone;
        pathView.keyboardType = UIKeyboardTypeASCIICapable;	
        pathView.delegate = self;
        pathView.text = @"/";
        [self.view addSubview:pathView];        
        
        inputView = [[UITextField alloc] initWithFrame:CGRectZero];
        inputView.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;        
        inputView.adjustsFontSizeToFitWidth = YES;	
        inputView.borderStyle = UITextBorderStyleRoundedRect;        
        inputView.clearButtonMode = UITextFieldViewModeWhileEditing;
        inputView.enablesReturnKeyAutomatically = YES;
        inputView.autocorrectionType = UITextAutocorrectionTypeNo;
        inputView.autocapitalizationType = UITextAutocapitalizationTypeNone;
        inputView.keyboardType = UIKeyboardTypeASCIICapable;	
        inputView.returnKeyType = UIReturnKeySend;
        inputView.delegate = self;
        inputView.placeholder = @"enter commands here";	
        [self.view addSubview:inputView];	 
        
        //add minus button	       
        UIButton *minusButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [minusButton setImage:[self UIImageFromPDF:@"minus.pdf" size:CGSizeMake(16,16)] forState:UIControlStateNormal];	        
        [minusButton addTarget:self action:@selector(minusButtonPressed:) forControlEvents:UIControlEventTouchUpInside];	
        minusButton.frame = CGRectMake(60, 16, 32, 32);		
        [self.view addSubview:minusButton];
        
        //add plus button	
        UIButton *plusButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [plusButton setImage:[self UIImageFromPDF:@"plus.pdf" size:CGSizeMake(16,16)] forState:UIControlStateNormal];		
        [plusButton addTarget:self action:@selector(plusButtonPressed:) forControlEvents:UIControlEventTouchUpInside];	
        plusButton.frame = CGRectMake(132, 16, 32, 32);				
        [self.view addSubview:plusButton];	
        
        //add x button		
        xButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [xButton setImage:[self UIImageFromPDF:@"x.pdf" size:CGSizeMake(16,16)] forState:UIControlStateNormal];		
        [xButton addTarget:self action:@selector(xButtonPressed:) forControlEvents:UIControlEventTouchUpInside];	
        xButton.frame = CGRectMake(self.view.frame.size.width-35, 16, 32, 32);
        xButton.contentMode = UIViewContentModeRight;         
        [self.view addSubview:xButton]; 
        
        //add return button		
        retButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [retButton setImage:[self UIImageFromPDF:@"return.pdf" size:CGSizeMake(33,33)] forState:UIControlStateNormal];		
        [retButton addTarget:self action:@selector(returnButtonPressed:) forControlEvents:UIControlEventTouchUpInside];	
        retButton.frame = CGRectMake(self.view.frame.size.width-50, self.view.frame.size.height-110, 50, 50);        
        [self.view addSubview:retButton]; 
        
        //add history button		
        histButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [histButton setImage:[self UIImageFromPDF:@"history.pdf" size:CGSizeMake(33,33)] forState:UIControlStateNormal];		
        [histButton addTarget:self action:@selector(historyButtonPressed:) forControlEvents:UIControlEventTouchUpInside];	
        histButton.frame = CGRectMake(0, self.view.frame.size.height-110, 50, 50);
        if ([[defaults objectForKey:@"history"] count] < 1) [histButton setEnabled:NO];        
        [self.view addSubview:histButton];  
        
        //add spinner
        spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];	
        spinner.frame = CGRectMake(self.view.frame.size.width-44, self.view.frame.size.height-102, 37, 37);	
        [spinner setHidesWhenStopped:YES];
        [self.view addSubview:spinner];   

        //add picker
        picker = [[UIPickerView alloc] initWithFrame:CGRectMake(3,self.view.bounds.size.height-59-216, self.view.bounds.size.width-6, 216)];
        picker.delegate = self;
        [picker setShowsSelectionIndicator:YES];
        [picker setAlpha:0.0];
        [self.view addSubview:picker];
        
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(keyboardWillShow:) name: UIKeyboardWillShowNotification object:nil];
        [nc addObserver:self selector:@selector(keyboardWillHide:) name: UIKeyboardWillHideNotification object:nil];
                
    }
    return self;
}

- (void)dealloc
{
    [spinner release];
    [outputImg release];
    [outputView release];
    [pathView release];   
    [inputView release]; 
    [super dealloc];    
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView
{
}
*/

/*
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
}
*/

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewDidAppear:(BOOL)animated{
	//sync layout
	[self syncLayout];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    //IOS 6+ to override iphone default UIInterfaceOrientationMaskAllButUpsideDown
    return UIInterfaceOrientationMaskAll;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration{
	//resize base items
	[self syncLayout];	
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    // Dismiss the keyboard when the view outside the text field is touched.
    [inputView resignFirstResponder];
    [pathView resignFirstResponder];    
	//dismiss the picker
    [picker setAlpha:0.0];    
}

-(void) keyboardWillHide:(NSNotification *) note
{
    //move input/path field back down
	float width = self.view.bounds.size.width;
	float height = self.view.bounds.size.height;
	inputView.frame = CGRectMake(50,height-49, width-100, 25);
	pathView.frame = CGRectMake(44, height-90, width-90, 25);
    [inputView setBorderStyle:UITextBorderStyleRoundedRect];
    [inputView setBackgroundColor:[UIColor whiteColor]];
    [pathView setBorderStyle:UITextBorderStyleNone];
    [pathView setBackgroundColor:[UIColor clearColor]];
}

-(void) keyboardWillShow:(NSNotification *) note
{
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    
    UIView *theView = nil;
    if ([inputView isFirstResponder]) theView = inputView;
    if ([pathView isFirstResponder]) theView = pathView;
    CGRect view = theView.frame;
    CGRect keyboard;
    [[note.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &keyboard];
    float keybHeight = keyboard.size.height;
    if (keyboard.size.height > keyboard.size.width) keybHeight = keyboard.size.width; //bug on landscape the values are reversed
    view.origin.x = 0;
    view.size.width =  self.view.frame.size.width;    
    view.origin.y =  self.view.frame.size.height - keybHeight + view.size.height;
    theView.frame = view;
    
    [UIView commitAnimations];
}

- (void)syncLayout{
    
    //dismiss the keyboard
    [inputView resignFirstResponder];
    [pathView resignFirstResponder];    
	//dismiss the picker
    [picker setAlpha:0.0];     
	
	float width = self.view.bounds.size.width;
	float height = self.view.bounds.size.height;
	
	outputImg.frame = CGRectMake(10, 20, width-20, height-80);		
	outputView.frame = CGRectMake(14, 42, width-26, height-80-54);
	pathView.frame = CGRectMake(44, height-90, width-90, 25);
	inputView.frame = CGRectMake(50,height-49, width-100, 25);
    picker.frame = CGRectMake(3,height-216, width-6, 162);
    spinner.frame = CGRectMake(width-44,height-52, 37, 37);    

    xButton.frame = CGRectMake(width-35, 16, 32, 32);				
    retButton.frame = CGRectMake(width-50, height-60, 50, 50);			
    histButton.frame = CGRectMake(0, height-60, 50, 50);
    
    [self.view setNeedsDisplay];    
    
}    

- (void)gotReply{
    [retButton setHidden:NO];
    [spinner stopAnimating];    
}

#pragma mark UITextView/Field delegates

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text{    
    if (textView == outputView) {
        return NO;        
    }    
    return YES;
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    [picker setAlpha:0.0];    
    //animate input/path on top of keyboard
    if (textField == pathView) {
        [pathView setBorderStyle:UITextBorderStyleLine];
        [pathView setBackgroundColor:[UIColor colorWithWhite:0.1 alpha:0.8]];            
    }
    if (textField == inputView) {
        [inputView setBorderStyle:UITextBorderStyleLine]; 
        [inputView setBackgroundColor:[UIColor colorWithWhite:1.0 alpha:0.9]];        
    }    
    if (textField == inputView || textField == pathView ) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.33];
        [UIView commitAnimations];	        
    }   
    return YES;    
}

- (void)textFieldDidEndEditing:(UITextField *)textField{
    //keyboard dismised
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    //button pressed    
    [textField resignFirstResponder];    
    
    if (textField == inputView) {
        [self sendCommand];
    }
    
    if (textField == pathView) {
        if ([pathView.text rangeOfString:@"/"].location == NSNotFound) pathView.text = @"/"; 
    }   
    
    return YES;    
}

#pragma mark UIPickerViewDelegate

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component{
    inputView.text = [[defaults objectForKey:@"history"] objectAtIndex:row];
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component{
    return [[defaults objectForKey:@"history"] objectAtIndex:row];
}

#pragma mark UIPickerViewDataSource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView{
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component{
    return [[defaults objectForKey:@"history"] count];
}

#pragma mark actions

-(void)minusButtonPressed:(id)sender{
    float old = outputView.font.pointSize;
    if (old > 1) {
        outputView.font = [UIFont fontWithName:@"Courier" size:old-1.0];        
    }
    [self animateBlink:sender]; 
}

-(void)plusButtonPressed:(id)sender{
    float old = outputView.font.pointSize;
    if (old < 50) {
        outputView.font = [UIFont fontWithName:@"Courier" size:old+1.0];        
    }
    [self animateBlink:sender];    
}

-(void)xButtonPressed:(id)sender{
    outputView.text = @"";
    [self animateBlink:sender];    
}

-(void)returnButtonPressed:(id)sender{
    [picker setAlpha:0.0];    
    [self sendCommand];
}

-(void)historyButtonPressed:(id)sender{  
	float width = self.view.bounds.size.width;
	float height = self.view.bounds.size.height;
    
    if ([picker alpha] == 0.0) {
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.2];
        picker.frame = CGRectMake(0,height-59-216, width, 216);
        [picker setAlpha:1.0];        
        [UIView commitAnimations];        
    }else{
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.2];
        picker.frame = CGRectMake(3,height-216, width-6, 162);
        [picker setAlpha:0.0];        
        [UIView commitAnimations];             
    }
}

#pragma mark tools


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

-(NSString*)caretString{    
    NSString *hostname = [[data objectForKey:@"hostname"] stringByReplacingOccurrencesOfString:@".local." withString:@""];
    NSString *ret = [NSString stringWithFormat:@"%@@%@$ %@\n",[data objectForKey:@"username"],hostname,inputView.text];    
    return ret;
}

-(void)sendCommand{
    if ([inputView.text length] < 1) return;
    if ([pathView.text rangeOfString:@"/"].location == NSNotFound) pathView.text = @"/";    
    NSString *theid = [NSString stringWithFormat:@"%i",[inputView tag]];    
    [[NSNotificationCenter defaultCenter] postNotificationName:OBSERVER_NAME_STRING object:nil userInfo:
     [NSDictionary dictionaryWithObjectsAndKeys:@"command",@"what",theid,@"theid",inputView.text,@"command",pathView.text,@"path",nil]
     ]; 
    //update ui
    [outputView setText:[outputView.text stringByAppendingString:[self caretString]]];         
    [retButton setHidden:YES];
    [spinner startAnimating];
    //save history
    NSMutableArray *arr = [[defaults objectForKey:@"history"] mutableCopy];
    if ([arr containsObject:inputView.text]) [arr removeObject:inputView.text];    
    [arr insertObject:inputView.text atIndex:0];
    [defaults setObject:arr forKey:@"history"];
    [arr release];
    [defaults synchronize];  
    [picker reloadAllComponents];            
    if ([[defaults objectForKey:@"history"] count] > 0) {
        [histButton setEnabled:YES];
    }      
}

-(void)animateBlink:(id)target {
    
    if (target == nil)  target = xButton;
	
	///Scale the X and Y dimmensions by a factor of 2
	CATransform3D tt = CATransform3DMakeScale(2,2,1);	

	CABasicAnimation *animation = [CABasicAnimation animation];
	animation.fromValue = [NSValue valueWithCATransform3D: CATransform3DIdentity];
	animation.toValue = [NSValue valueWithCATransform3D: tt];
	animation.duration = 0.2;
	animation.removedOnCompletion = YES;
	animation.fillMode = kCAFillModeBoth;
	[target addAnimation:animation forKey:@"transform"];
	
}


@end
