//
//  MCSThriftController.m
//  MultipeerClientServer
//
//  Created by Mark Stultz on 5/30/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

#import "MCSThriftController.h"
#import "MCSThriftPeerController.h"
#import "MCSPeer.h"
#import "TBinaryProtocol.h"
#import "TNSStreamTransport.h"
#import "TSharedProcessorFactory.h"
#import "TTransportException.h"

@protocol ThriftServiceInitProtocol <NSObject>

- (id)initWithProtocol:(id<TProtocol>)protocol;

@end

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

@interface MCSThriftController () <NSStreamDelegate>

@property (nonatomic, strong) MCSPeer *peer;
@property (nonatomic, strong) NSMutableDictionary *streamRequests;
@property (nonatomic, strong) NSMutableDictionary *thriftPeerControllers;

- (MCSThriftPeerController *)thriftPeerControllerForPeer:(MCPeerID *)peerID;

- (void)addProcessorFromStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeerID:(MCPeerID *)peerID;

- (void)addThriftService:(id)thriftService forPeer:(MCPeerID *)peerID;
- (void)addProcessor:(id<TProcessor>)processor forPeer:(MCPeerID *)peerID;

@end

static dispatch_queue_t dispatch_thrift_queue() {
	static dispatch_queue_t dispatch_thrift_queue;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		dispatch_thrift_queue = dispatch_queue_create("com.multipeerclientserver.thrift", DISPATCH_QUEUE_CONCURRENT);
	});
	
	return dispatch_thrift_queue;
}

@implementation MCSThriftController

- (id)initWithPeer:(MCSPeer *)peer;
{
	self = [super init];
	if (self) {
		self.peer = peer;
		self.streamRequests = [NSMutableDictionary dictionary];
		self.thriftPeerControllers = [NSMutableDictionary dictionary];
	}
	
	return self;
}

- (void)startBidirectionalConnectionsToPeer:(MCPeerID *)peerID
{
	if (!self.outgoingThriftServiceClass) {
		NSLog(@"Error: thriftServiceClass is nil.");
	}
	
	for (NSUInteger i = 0; i < self.maxConnections; ++i) {
		NSString *streamName = [NSString stringWithFormat:@"out-%@", [[NSUUID UUID] UUIDString]];
		NSOutputStream *outputStream = [self.peer startStreamWithName:streamName toPeer:peerID];
		if (!outputStream) {
			NSLog(@"Error: outputStream is nil.");
			continue;
		}
		
		outputStream.delegate = self;
		[outputStream open];
		MCSStreamRequest *request = [[MCSStreamRequest alloc] initWithOutputStream:outputStream completion:^(NSInputStream *inputStream, NSOutputStream *outputStream) {
			TNSStreamTransport *transport = [[TNSStreamTransport alloc] initWithInputStream:inputStream outputStream:outputStream];
			TBinaryProtocol *protocol = [[TBinaryProtocol alloc] initWithTransport:transport strictRead:YES strictWrite:YES];
			
			id thriftService = [self.outgoingThriftServiceClass alloc];
			if (thriftService) {
				if ([thriftService respondsToSelector:@selector(initWithProtocol:)]) {
					thriftService = [thriftService initWithProtocol:protocol];
					if (!thriftService) {
						NSLog(@"Error: Could not create thrift service for class %@", NSStringFromClass(self.outgoingThriftServiceClass));
					}
					else {
						NSLog(@"%@ adding thrift service %@", [UIDevice currentDevice].name, NSStringFromClass([thriftService class]));
						[self addThriftService:thriftService forPeer:peerID];
					}
				}
			}
		}];
		
		self.streamRequests[ streamName ] = request;
	}
}

- (void)receiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID
{
	MCSStreamRequest *streamRequest = self.streamRequests[ streamName ];
	if (streamRequest) {
		stream.delegate = self;
		[stream open];
		
		[self.streamRequests removeObjectForKey:streamName];
		
		if (streamRequest.completion) {
			streamRequest.completion(stream, streamRequest.outputStream);
		}
	}
	else {
		[self addProcessorFromStream:stream withName:streamName fromPeerID:peerID];
	}
}

- (MCSThriftPeerController *)thriftPeerControllerForPeer:(MCPeerID *)peerID
{
	MCSThriftPeerController *thriftPeerController = self.thriftPeerControllers[ peerID ];
	if (!thriftPeerController) {
		thriftPeerController = [[MCSThriftPeerController alloc] initWithPeer:peerID];
		self.thriftPeerControllers[ peerID ] = thriftPeerController;
	}
	
	return thriftPeerController;
}

- (void)addProcessorFromStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeerID:(MCPeerID *)peerID
{
	NSOutputStream *outputStream = [self.peer startStreamWithName:streamName toPeer:peerID];
	if (!outputStream) {
		NSLog(@"Error: outputStream is nil.");
	}
	else {
		outputStream.delegate = self;
		[outputStream open];
		
		stream.delegate = self;
		[stream open];
		
		TNSStreamTransport *transport = [[TNSStreamTransport alloc] initWithInputStream:stream outputStream:outputStream];
		TBinaryProtocol *protocol = [[TBinaryProtocol alloc] initWithTransport:transport strictRead:YES strictWrite:YES];
		if (self.incomingThriftProcessorInstantiationBlock) {
			id thriftProcessor = self.incomingThriftProcessorInstantiationBlock();
			if (thriftProcessor) {
				[self addProcessor:thriftProcessor forPeer:peerID];
				
				dispatch_async(dispatch_thrift_queue(), ^{
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

- (void)removeConnectionsForPeer:(MCPeerID *)peerID
{
	[self.thriftPeerControllers removeObjectForKey:peerID];
}

- (void)enqueueThriftService:(id)thriftService forPeer:(MCPeerID *)peerID
{
	dispatch_async(dispatch_thrift_queue(), ^{
		MCSThriftPeerController *thriftPeerController = [self thriftPeerControllerForPeer:peerID];
		[thriftPeerController enqueueThriftService:thriftService];
	});
}

- (void)dequeueThriftService:(void (^)(id thriftService))completion forPeer:(MCPeerID *)peerID
{
	static const float timeout = 10.f;
	
	if (completion) {
		dispatch_async(dispatch_thrift_queue(), ^{
			CFAbsoluteTime maxTryTime = CFAbsoluteTimeGetCurrent() + timeout;
			MCSThriftPeerController *thriftPeerController = [self thriftPeerControllerForPeer:peerID];
			id thriftService = [thriftPeerController dequeueThriftService];
			while (!thriftService) {
				thriftService = [thriftPeerController dequeueThriftService];
				
				if (CFAbsoluteTimeGetCurrent() > maxTryTime) {
					break;
				}
			}
			
			if (!thriftService) {
				NSLog(@"Error: thriftService is nil.");
				completion(nil);
				return;
			}
			
			completion(thriftService);
		});
	}
}

- (void)addThriftService:(id)thriftService forPeer:(MCPeerID *)peerID
{
	MCSThriftPeerController *thriftPeerController = [self thriftPeerControllerForPeer:peerID];
	[thriftPeerController addThriftService:thriftService];
}

- (void)addProcessor:(id<TProcessor>)processor forPeer:(MCPeerID *)peerID
{
	MCSThriftPeerController *thriftPeerController = [self thriftPeerControllerForPeer:peerID];
	[thriftPeerController addProcessor:processor];
}

@end
