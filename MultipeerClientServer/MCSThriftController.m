//
//  MCSThriftController.m
//  MultipeerClientServer
//
//  Created by Mark Stultz on 5/30/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

#import "MCSThriftController.h"
#import "TNSStreamTransport.h"
#import "TBinaryProtocol.h"

@protocol ThriftServiceInitProtocol <NSObject>

- (id)initWithProtocol:(id<TProtocol>)protocol;

@end

@interface MCSThriftController ()

@property (nonatomic, strong) NSMutableDictionary *streamRequests;
@property (nonatomic, strong) NSMutableSet *thriftServices;
@property (nonatomic, strong) NSMutableSet *activeThriftServices;

@end

@implementation MCSThriftController

- (id)init
{
	self = [super init];
	if (self) {
		self.streamRequests = [NSMutableDictionary dictionary];
		self.thriftServices = [NSMutableSet set];
		self.activeThriftServices = [NSMutableSet set];
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
		[self.streamCreationDelegate startStreamWithName:streamName toPeer:peerID completion:^(NSInputStream *inputStream, NSOutputStream *outputStream) {
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

@end
