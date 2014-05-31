//
//  MCSThriftController.m
//  MultipeerClientServer
//
//  Created by Mark Stultz on 5/30/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

#import "MCSThriftController.h"
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
@property (nonatomic, strong) NSMutableSet *thriftServices;
@property (nonatomic, strong) NSMutableSet *activeThriftServices;
@property (nonatomic, strong) NSMutableDictionary *peerProcessorMap;

- (void)addProcessor:(id<TProcessor>)processor forPeer:(MCPeerID *)peerID;
- (void)addProcessorFromStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeerID:(MCPeerID *)peerID;
@end

static dispatch_queue_t processor_queue() {
	static dispatch_queue_t processor_queue;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		processor_queue = dispatch_queue_create("com.multipeerclientserver.mcspeer.processor", DISPATCH_QUEUE_CONCURRENT);
	});
	
	return processor_queue;
}

@implementation MCSThriftController

- (id)initWithPeer:(MCSPeer *)peer;
{
	self = [super init];
	if (self) {
		self.peer = peer;
		self.streamRequests = [NSMutableDictionary dictionary];
		self.thriftServices = [NSMutableSet set];
		self.activeThriftServices = [NSMutableSet set];
		self.peerProcessorMap = [NSMutableDictionary dictionary];
	}
	
	return self;
}

- (void)startBidirectionalConnectionsToPeer:(MCPeerID *)peerID
{
	if (!self.thriftServiceClass) {
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
		if ([self.peer.delegate respondsToSelector:@selector(thriftProcessor)]) {
			id thriftProcessor = [self.peer.delegate thriftProcessor];
			if (thriftProcessor) {
				[self addProcessor:thriftProcessor forPeer:peerID];
				
				dispatch_async(processor_queue(), ^{
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
	[self.peerProcessorMap removeObjectForKey:peerID];
}

- (void)enqueueThriftService:(id)thriftService
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[self.thriftServices addObject:thriftService];
	});
}

- (void)dequeueThriftService:(void (^)(id thriftService))completion
{
	static const float timeout = 10.f;
	
	if (completion) {
		dispatch_async(dispatch_get_main_queue(), ^{
			CFAbsoluteTime maxTryTime = CFAbsoluteTimeGetCurrent() + timeout;

			id thriftService = self.thriftServices.anyObject;
			while (!thriftService) {
				thriftService = self.thriftServices.anyObject;
				
				if (CFAbsoluteTimeGetCurrent() > maxTryTime) {
					break;
				}
			}
			
			if (!thriftService) {
				NSLog(@"Error: thriftService is nil.");
				return;
			}
			
			[self.activeThriftServices addObject:thriftService];
			[self.thriftServices removeObject:thriftService];
			completion(thriftService);
		});
	}
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

@end
