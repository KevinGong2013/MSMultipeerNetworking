//
//  MCSPeer.m
//  MultipeerClientServer
//
//  Created by Mark Stultz on 4/20/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

#import "MCSPeer.h"

@interface MCSStreamRequest : NSObject

@property (nonatomic, strong) NSOutputStream *outputStream;
@property (nonatomic, copy) void (^completion)(NSInputStream *inputStream, NSOutputStream *outputStream);

- (id)initWithOutputStream:(NSOutputStream *)outputStream completion:(void (^)(NSInputStream *inputStream, NSOutputStream *outputStream))completion;

@end

@implementation MCSStreamRequest

- (id)initWithOutputStream:(NSOutputStream *)outputStream completion:(void (^)(NSInputStream *inputStream, NSOutputStream *outputStream))completion
{
	self = [super init];
	if (self) {
		self.outputStream = outputStream;
		self.completion = completion;
	}
	
	return self;
}

@end

@interface MCSPeer () <MCSStreamCreationDelegate, NSStreamDelegate>

@property (nonatomic, strong) MCPeerID *peerID;
@property (nonatomic, strong) MCSession *session;
@property (nonatomic, copy) NSString *serviceType;
@property (nonatomic, copy) NSString *uuid;
@property (nonatomic, copy) NSArray *connectedPeers;
@property (nonatomic, strong) MCSThriftController *thriftController;
@property (nonatomic, strong) NSMutableDictionary *streamRequests;
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
		self.streamRequests = [NSMutableDictionary dictionary];
		self.peerID = [[MCPeerID alloc] initWithDisplayName:[UIDevice currentDevice].name];
		self.session = [[MCSession alloc] initWithPeer:self.peerID];
		self.session.delegate = self;
		
		self.operationQueue = [[NSOperationQueue alloc] init];
		self.operationQueue.maxConcurrentOperationCount = maxConcurrentRequests;
		
		self.thriftController = [[MCSThriftController alloc] init];
		self.thriftController.streamCreationDelegate = self;
	}
	
	return self;
}

- (void)sendThriftOperation:(void(^)(id thriftService))thriftOperation
{
	__weak MCSPeer *weakSelf = self;
	NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
		[weakSelf.thriftController dequeueThriftService:^(id thriftService) {
			thriftOperation(thriftService);
			[self.thriftController enqueueThriftService:thriftService];
		}];
	}];
	
	[self.operationQueue addOperation:operation];
}

- (void)startStreamWithName:(NSString *)name toPeer:(MCPeerID *)peerID completion:(void(^)(NSInputStream *inputStream, NSOutputStream *outputStream))completion
{
	NSError *error = nil;
	NSOutputStream *outputStream = [self.session startStreamWithName:name toPeer:peerID error:&error];
	if (error || !outputStream) {
		NSLog(@"Error: %@", error.localizedDescription);
	}
	else {
		NSLog(@"Started stream named %@ with host %@", name, peerID.displayName);
		
		outputStream.delegate = self;
		[outputStream open];
		MCSStreamRequest *request = [[MCSStreamRequest alloc] initWithOutputStream:outputStream completion:completion];
		self.streamRequests[ name ] = request;
	}
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

- (Class)thriftServiceClass
{
	return self.thriftController.thriftServiceClass;
}

- (void)setThriftServiceClass:(Class)thriftServiceClass
{
	self.thriftController.thriftServiceClass = thriftServiceClass;
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
	MCSStreamRequest *streamRequest = self.streamRequests[ streamName ];
	if (streamRequest && streamRequest.completion) {
		stream.delegate = self;
		[stream open];
		
		[self.streamRequests removeObjectForKey:streamName];
		streamRequest.completion(stream, streamRequest.outputStream);
	}
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
