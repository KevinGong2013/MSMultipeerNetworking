//
//  MSMultipeerClient.m
//  MSMultipeerNetworking
//
//  Created by Mark Stultz on 4/20/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

#import "MSMultipeerClient.h"
#import "MSNearbyServer.h"
#import "MSThriftController.h"

@interface MSMultipeerClient () <MCNearbyServiceBrowserDelegate>

@property (nonatomic, strong) MCNearbyServiceBrowser *browser;
@property (nonatomic, strong) NSArray *nearbyServers;
@property (nonatomic, strong) MCPeerID *hostPeerID;

@end

@implementation MSMultipeerClient

- (id)initWithServiceType:(NSString *)serviceType maxConcurrentRequests:(NSUInteger)maxConcurrentRequests
{
	self = [super initWithServiceType:serviceType maxConcurrentRequests:maxConcurrentRequests];
	if (self) {		
		self.nearbyServers = [NSMutableArray array];
		self.browser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.session.myPeerID serviceType:self.serviceType];
		self.browser.delegate = self;
		
		[self startBrowsingForHosts];
	}
	
	return self;
}

- (void)dealloc
{
	[self stopBrowsingForHosts];
}

- (void)startBrowsingForHosts
{
	[self.browser startBrowsingForPeers];
}

- (void)stopBrowsingForHosts;
{
	self.nearbyServers = [NSMutableArray array];
	[self.browser stopBrowsingForPeers];
}

- (void)connectToHost:(MCPeerID *)hostPeerID
{
	self.hostPeerID = hostPeerID;
	self.connected = NO;
	[self.browser invitePeer:hostPeerID toSession:self.session withContext:nil timeout:20.f];
}

- (void)sendThriftOperation:(void(^)(id thriftService))thriftOperation
{
	__weak MSMultipeer *weakSelf = self;
	NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
		[weakSelf.thriftController dequeueThriftService:^(id thriftService) {
			@try {
				thriftOperation(thriftService);
			}
			@catch (NSException * e) {
				NSLog(@"Error, exception: %@", e);
			}
			
			if (thriftService) {
				[self.thriftController enqueueThriftService:thriftService forPeer:self.hostPeerID];
			}
		}
		forPeer:self.hostPeerID];
	}];
		
	[self.operationQueue addOperation:operation];
}

#pragma mark MCSessionDelegate

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
	[super session:session peer:peerID didChangeState:state];
	
	switch (state) {
		case MCSessionStateNotConnected: {
			dispatch_async(dispatch_get_main_queue(), ^{
				if (peerID == self.hostPeerID) {
					self.connected = NO;
				}
			});
		}
			break;
		case MCSessionStateConnecting:
			break;
		case MCSessionStateConnected: {
			dispatch_async(dispatch_get_main_queue(), ^{
				if (peerID == self.hostPeerID) {
					self.connected = YES;
					[self.thriftController startBidirectionalConnectionsToPeer:peerID];
				}
			});
		}
			break;
			
		default:
			break;
	}
}

#pragma mark MCNearbyServiceBrowserDelegate

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info
{
	NSLog(@"Client: Discovered potential host: %@", peerID.displayName);
	
	MSNearbyServer *nearbyServer = [[MSNearbyServer alloc] initWithPeerID:peerID discoveryInfo:info];
	if (nearbyServer.uuid) {
		self.nearbyServers = [self.nearbyServers arrayByAddingObject:nearbyServer];
	}
}

- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID
{
	NSLog(@"Client: Lost potential host: %@", peerID.displayName);
	
	MSNearbyServer *nearbyServerToRemove = nil;
	for (MSNearbyServer *nearbyServer in self.nearbyServers) {
		if (nearbyServer.peerID == peerID) {
			nearbyServerToRemove = nearbyServer;
			break;
		}
	}
	
	if (nearbyServerToRemove) {
		NSMutableArray *nearbyServers = [NSMutableArray arrayWithArray:self.nearbyServers];
		[nearbyServers removeObject:nearbyServerToRemove];
		self.nearbyServers = nearbyServers;
	}
}

- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error
{
	NSLog(@"Client: Could not start browsing for peers. %@", error.localizedDescription);
}

@end
