//
//  MCSPeer.m
//  MultipeerClientServer
//
//  Created by Mark Stultz on 4/20/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

#import "MCSPeer.h"

@interface MCSPeer ()

@property (nonatomic, strong) MCPeerID *peerID;
@property (nonatomic, strong) MCSession *session;
@property (nonatomic, copy) NSString *serviceType;
@property (nonatomic, copy) NSString *uuid;
@property (nonatomic, copy) NSArray *connectedPeers;
@property (nonatomic, strong) MCSThriftController *thriftController;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@property (nonatomic, assign) NSUInteger *maxConcurrentRequests;

- (NSString *)stringForSessionState:(MCSessionState)state;

@end

@implementation MCSPeer

- (id)initWithServiceType:(NSString *)serviceType maxConcurrentRequests:(NSUInteger)maxConcurrentRequests
{
	self = [super init];
	if (self) {
		self.serviceType = serviceType;
		self.uuid = [[NSUUID UUID] UUIDString];
		self.connectedPeers = [NSArray array];
		self.peerID = [[MCPeerID alloc] initWithDisplayName:[UIDevice currentDevice].name];
		self.session = [[MCSession alloc] initWithPeer:self.peerID];
		self.session.delegate = self;
		self.thriftController = [[MCSThriftController alloc] initWithPeer:self];
		self.thriftController.maxConnections = maxConcurrentRequests;
		self.operationQueue = [[NSOperationQueue alloc] init];
		self.operationQueue.maxConcurrentOperationCount = maxConcurrentRequests;
	}
	
	return self;
}

- (void)sendThriftOperation:(void(^)(id thriftService))thriftOperation
{
	/**/
}

- (NSOutputStream *)startStreamWithName:(NSString *)name toPeer:(MCPeerID *)peerID
{
	NSError *error = nil;
	NSOutputStream *outputStream = [self.session startStreamWithName:name toPeer:peerID error:&error];
	if (error || !outputStream) {
		NSLog(@"Error: %@", error.localizedDescription);
	}
	else {
		NSLog(@"Started stream named %@ with host %@", name, peerID.displayName);
	}
	
	return outputStream;
}

- (NSString *)stringForSessionState:(MCSessionState)state
{
	switch (state) {
		case MCSessionStateNotConnected:
			return @"MCSessionStateNotConnected";
		case MCSessionStateConnecting:
			return @"MCSessionStateConnecting";
		case MCSessionStateConnected:
			return @"MCSessionStateConnected";
		default:
			return @"Invalid state";
	}
}

- (Class)outgoingThriftServiceClass
{
	return self.thriftController.outgoingThriftServiceClass;
}

- (void)setOutgoingThriftServiceClass:(Class)outgoingThriftServiceClass
{
	self.thriftController.outgoingThriftServiceClass = outgoingThriftServiceClass;
}

- (id (^)(void))incomingThriftProcessorInstantiationBlock
{
	return self.thriftController.incomingThriftProcessorInstantiationBlock;
}

- (void)setIncomingThriftProcessorInstantiationBlock:(id (^)(void))incomingThriftProcessorInstantiationBlock
{
	self.thriftController.incomingThriftProcessorInstantiationBlock = incomingThriftProcessorInstantiationBlock;
}

#pragma mark MCSessionDelegate

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
	NSLog(@"%@ did change state with peer, %@: %@", peerID.displayName, peerID, [self stringForSessionState:state]);

	switch (state) {
		case MCSessionStateConnected:
			self.connectedPeers = [self.connectedPeers arrayByAddingObject:peerID];
			break;
		case MCSessionStateNotConnected: {
			NSMutableArray *connectedPeers = [NSMutableArray arrayWithArray:self.connectedPeers];
			[connectedPeers removeObject:peerID];
			self.connectedPeers = [NSArray arrayWithArray:connectedPeers];
		}
			break;
		default:
			break;
	}
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID
{
	/**/
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
	[self.thriftController receiveStream:stream withName:streamName fromPeer:peerID];
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress
{
	/**/
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error
{
	/**/
}

@end
