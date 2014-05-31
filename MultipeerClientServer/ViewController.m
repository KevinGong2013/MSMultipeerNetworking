//
//  ViewController.m
//  MultipeerClientServer
//
//  Created by Mark Stultz on 4/15/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

#import "ViewController.h"
#import "ChatAppClient.h"
#import "ChatAppServer.h"
#import "ChatAppAPI.h"
#import "ServerBrowserViewController.h"
#import "ChatViewController.h"

static void *ConnectedContext = &ConnectedContext;

@interface ViewController () <ServerBrowserViewControllerDelegate>

@property (nonatomic, strong) ChatAppClient *client;
@property (nonatomic, strong) ChatAppServer *server;
@property (nonatomic, strong) Chat *chat;

- (IBAction)startClient:(id)sender;
- (IBAction)startServer:(id)sender;

@end

@implementation ViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	self.chat = [[Chat alloc] initWithRevision:0 messages:[NSMutableArray array]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context == ConnectedContext) {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self dismissViewControllerAnimated:YES completion:^{
				[self performSegueWithIdentifier:@"joinServerSegue" sender:self];
			}];
		});
	}
	else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	if ([segue.identifier isEqualToString:@"startClientSegue"]) {
		ServerBrowserViewController *viewController = segue.destinationViewController;
		viewController.multipeerClient = self.client;
		viewController.delegate = self;
	}
	else if ([segue.identifier isEqualToString:@"startServerSegue"]
				|| [segue.identifier isEqualToString:@"joinServerSegue"]) {
		ChatViewController *viewController = segue.destinationViewController;
		viewController.chatAppAPI = self.server ? self.server : self.client;
		viewController.peer = self.server ? self.server : self.client;
		viewController.chat = self.chat;
	}
}

- (IBAction)startClient:(id)sender
{
	self.chat = [[Chat alloc] initWithRevision:0 messages:[NSMutableArray array]];
	self.client = [[ChatAppClient alloc] init];
	[self performSegueWithIdentifier:@"startClientSegue" sender:sender];
}

- (IBAction)startServer:(id)sender
{
	self.chat = [[Chat alloc] initWithRevision:0 messages:[NSMutableArray array]];
	self.server = [[ChatAppServer alloc] initWithServiceType:@"ms-multichat" chat:self.chat];
	[self performSegueWithIdentifier:@"startServerSegue" sender:sender];
}

- (void)setClient:(ChatAppClient *)client
{
	[_client removeObserver:self forKeyPath:@"connected"];
	_client = client;
	[_client addObserver:self forKeyPath:@"connected" options:NSKeyValueObservingOptionNew context:ConnectedContext];
}

#pragma mark ServerBrowserViewControllerDelegate

- (void)serverBrowserViewController:(ServerBrowserViewController *)viewController wantsToJoinPeer:(MCPeerID *)peerID
{
	if (self.client) {
		[self.client connectToHost:peerID];
	}
}

@end
