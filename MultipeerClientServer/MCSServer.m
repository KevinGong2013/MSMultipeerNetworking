//
//  MCSServer.m
//  MultipeerClientServer
//
//  Created by Mark Stultz on 4/20/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

#import "MCSServer.h"
#import "TSharedProcessorFactory.h"
#import "TBinaryProtocol.h"
#import "TNSStreamTransport.h"
#import "TTransportException.h"

static void *ConnectedPeersContext = &ConnectedPeersContext;

@interface MCSServer () <MCNearbyServiceAdvertiserDelegate, NSStreamDelegate>

@property (nonatomic, copy, readonly) NSDictionary *discoveryInfo;
@property (nonatomic, strong) MCNearbyServiceAdvertiser *advertiser;
@property (nonatomic, strong) NSMutableDictionary *peerProcessorMap;

- (void)addProcessor:(id<TProcessor>)processor forPeer:(MCPeerID *)peerID;

@end

static dispatch_queue_t server_processor_queue() {
	static dispatch_queue_t server_processor_queue;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		server_processor_queue = dispatch_queue_create("com.multipeerclientserver.mcsserver.processor", DISPATCH_QUEUE_CONCURRENT);
	});
	
	return server_processor_queue;
}

@implementation MCSServer

- (id)initWithServiceType:(NSString *)serviceType
{
	self = [super initWithServiceType:serviceType];
	if (self) {
		self.advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:self.session.myPeerID discoveryInfo:self.discoveryInfo serviceType:self.serviceType];
		self.advertiser.delegate = self;
		self.peerProcessorMap = [NSMutableDictionary dictionary];
		
		[self.advertiser startAdvertisingPeer];
	}
	
	return self;
}

- (void)dealloc;
{
	[self.advertiser stopAdvertisingPeer];
}

- (NSDictionary *)discoveryInfo
{
	return @{
		@"uuid" : self.uuid
	};
}

- (void)addProcessor:(id<TProcessor>)processor forPeer:(MCPeerID *)peerID
{
	NSMutableArray *processors = self.peerProcessorMap[ peerID ];
	if (!processors) {
		processors = [NSMutableArray array];
		self.peerProcessorMap[ peerID ] = processors;
	}
	
	[processors addObject:processor];
}

#pragma mark MCSessionDelegate

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state
{
	[super session:session peer:peerID didChangeState:state];
	
	if (state == MCSessionStateNotConnected) {
		[self.peerProcessorMap removeObjectForKey:peerID];
	}
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
	BOOL isClientRequest = [streamName hasPrefix:@"out"];
	if (!isClientRequest) {
		return [super session:session didReceiveStream:stream withName:streamName fromPeer:peerID];
	}
	else {
		NSLog(@"Server received stream named %@ from peer %@", streamName, peerID.displayName);
		
		NSError *error = nil;
		NSOutputStream *outputStream = [self.session startStreamWithName:streamName toPeer:peerID error:&error];
		if (error) {
			NSLog(@"error: %@", error.localizedDescription);
		}
		else {
			outputStream.delegate = self;
			[outputStream open];
			
			stream.delegate = self;
			[stream open];
			
			TNSStreamTransport *transport = [[TNSStreamTransport alloc] initWithInputStream:stream outputStream:outputStream];
			TBinaryProtocol *protocol = [[TBinaryProtocol alloc] initWithTransport:transport strictRead:YES strictWrite:YES];
			if ([self.delegate respondsToSelector:@selector(thriftProcessor)]) {
				id thriftProcessor = [self.delegate thriftProcessor];
				if (thriftProcessor) {
					[self addProcessor:thriftProcessor forPeer:peerID];
					
					dispatch_async(server_processor_queue(), ^{
						@try {
							BOOL result = NO;
							do {
								@autoreleasepool {
									result = [thriftProcessor processOnInputProtocol:protocol outputProtocol:protocol];
								}
							} while (result);
						}
						@catch (TTransportException *exception) {
							NSLog(@"Caught transport exception, abandoning client connection: %@", exception);
						}
					});
				}
			}
		}
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

