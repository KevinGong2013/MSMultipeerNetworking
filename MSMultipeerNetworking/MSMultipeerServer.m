//
//  MSMultipeerServer.m
//  MSMultipeerNetworking
//
//  Created by Mark Stultz on 4/20/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

#import "MSMultipeerServer.h"

@interface MSMultipeerServer () <MCNearbyServiceAdvertiserDelegate, NSStreamDelegate>

@property (nonatomic, copy, readonly) NSDictionary *discoveryInfo;
@property (nonatomic, strong) MCNearbyServiceAdvertiser *advertiser;

@end

@implementation MSMultipeerServer

- (id)initWithServiceType:(NSString *)serviceType maxConcurrentRequests:(NSUInteger)maxConcurrentRequests
{
	self = [super initWithServiceType:serviceType maxConcurrentRequests:maxConcurrentRequests];
	if (self) {
		self.advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.session.myPeerID discoveryInfo:self.discoveryInfo serviceType:self.serviceType];
		self.advertiser.delegate = self;
		
		[self.advertiser startAdvertisingPeer];
	}
	
	return self;
}

- (void)dealloc;
{
	[self.advertiser stopAdvertisingPeer];
}

- (void)sendThriftEvent:(void(^)(id thriftService))thriftOperation
{
	for( MCPeerID *peerID in self.connectedPeers) {
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
					[self.thriftController enqueueThriftService:thriftService forPeer:peerID];
				}
			}
			forPeer:peerID];
		}];
		
		[self.operationQueue addOperation:operation];

	}
}

- (NSDictionary *)discoveryInfo
{
	return @{
		@"uuid" : self.uuid
	};
}

#pragma mark MCSessionDelegate

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
	[super session:session peer:peerID didChangeState:state];
	
	switch (state) {
		case MCSessionStateNotConnected: {
			[self.thriftController removeConnectionsForPeer:peerID];
		}
			break;
		case MCSessionStateConnecting:
			break;
		case MCSessionStateConnected: {
			[self.thriftController startBidirectionalConnectionsToPeer:peerID];
		}
			break;
			
		default:
			break;
	}
}

#pragma mark MCNearbyServiceAdvertiserDelegate

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void(^)(BOOL accept, MCSession *session))invitationHandler
{
	NSLog(@"Server: Host received invitation from client: %@; accepting", peerID.displayName);
	if (invitationHandler) {
		invitationHandler(YES, self.session);
	}
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error
{
	NSLog(@"Server: Did not start advertising to peer. %@", error.localizedDescription);
}

@end

