//
//  MCSClient.m
//  MultipeerClientServer
//
//  Created by Mark Stultz on 4/20/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

#import "MCSClient.h"
#import "MCSNearbyServer.h"
#import "TNSStreamTransport.h"
#import "TBinaryProtocol.h"

static void *ConnectedContext = &ConnectedContext;

@protocol ThriftServiceInitProtocol <NSObject>

- (id)initWithProtocol:(id<TProtocol>)protocol;

@end

@interface MCSClient () <MCNearbyServiceBrowserDelegate>

@property (nonatomic, strong) MCNearbyServiceBrowser *browser;
@property (nonatomic, strong) NSArray *nearbyServers;
@property (nonatomic, strong) MCPeerID *hostPeerID;
@property (nonatomic, assign) NSUInteger maxConcurrentRequests;
@property (nonatomic, strong) NSMutableSet *thriftServices;
@property (nonatomic, strong) NSMutableSet *activeThriftServices;
@property (nonatomic, assign) BOOL connected;
@property (nonatomic, copy) void (^onConnectBlock)(void);

- (void)createStreams;

@end

@implementation MCSClient

- (id)initWithServiceType:(NSString *)serviceType maxConcurrentRequests:(NSUInteger)maxConcurrentRequests
{
	self = [super initWithServiceType:serviceType];
	if (self) {
		self.maxConcurrentRequests = maxConcurrentRequests;
		self.nearbyServers = [NSMutableArray array];
		self.browser = [[MCNearbyServiceBrowser alloc] initWithPeer:self.session.myPeerID serviceType:self.serviceType];
		self.browser.delegate = self;
		self.thriftServices = [NSMutableSet set];
		self.activeThriftServices = [NSMutableSet set];
		
		[self startBrowsingForHosts];

		[self addObserver:self forKeyPath:@"connected" options:NSKeyValueObservingOptionNew context:ConnectedContext];
	}
	
	return self;
}

- (void)dealloc
{
	[self stopBrowsingForHosts];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context == ConnectedContext) {
		if (self.connected && self.onConnectBlock) {
			self.onConnectBlock();
			self.onConnectBlock = nil;
		}
	}
	else {
		return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
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

- (void)connectToHost:(MCPeerID *)hostPeerID completion:(void(^)())completion
{
	self.onConnectBlock = completion;
	self.hostPeerID = hostPeerID;
	self.connected = NO;
	[self.browser invitePeer:hostPeerID toSession:self.session withContext:nil timeout:20.f];
}

- (void)enqueueThriftService:(id)thriftService
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[self.thriftServices addObject:thriftService];
	});
}

- (void)dequeueThriftService:(void (^)(id thriftService))completion
{
	if (completion) {
		dispatch_async(dispatch_get_main_queue(), ^{
			id thriftService = self.thriftServices.anyObject;
			if (thriftService) {
				[self.activeThriftServices addObject:thriftService];
				[self.thriftServices removeObject:thriftService];
			}
			
			completion(thriftService);
		});
	}
}

- (void)createStreams
{
	if (!self.thriftServiceClass) {
		NSLog(@"Error: No Thrift service class.");
	}
	
	for (int i = 0; i < self.maxConcurrentRequests; ++i) {
		NSString *streamName = [NSString stringWithFormat:@"out-%@", [[NSUUID UUID] UUIDString]];
		[self startStreamWithName:streamName toPeer:self.hostPeerID completion:^(NSInputStream *inputStream, NSOutputStream *outputStream) {
			TNSStreamTransport *transport = [[TNSStreamTransport alloc] initWithInputStream:inputStream outputStream:outputStream];
			TBinaryProtocol *protocol = [[TBinaryProtocol alloc] initWithTransport:transport strictRead:YES strictWrite:YES];
			
			id thriftService = [self.thriftServiceClass alloc];
			if (thriftService) {
				if ([thriftService respondsToSelector:@selector(initWithProtocol:)]) {
					thriftService = [thriftService initWithProtocol:protocol];
					if (!thriftService) {
						NSLog(@"Error: Could not create thrift service for class %@", NSStringFromClass(self.thriftServiceClass));
					}
					else {
						[self.thriftServices addObject:thriftService];
					}
				}
			}
			
		}];
	}
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
		case MCSessionStateConnecting: {
			dispatch_async(dispatch_get_main_queue(), ^{
			});
		}
			break;
		case MCSessionStateConnected: {
			dispatch_async(dispatch_get_main_queue(), ^{
				if (peerID == self.hostPeerID) {
					self.connected = YES;
					[self createStreams];
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
	
	MCSNearbyServer *nearbyServer = [[MCSNearbyServer alloc] initWithPeerID:peerID discoveryInfo:info];
	if (nearbyServer.uuid) {
		self.nearbyServers = [self.nearbyServers arrayByAddingObject:nearbyServer];
	}
}

- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID
{
	NSLog(@"Client: Lost potential host: %@", peerID.displayName);
	
	MCSNearbyServer *nearbyServerToRemove = nil;
	for (MCSNearbyServer *nearbyServer in self.nearbyServers) {
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
