//
//  MCSThriftPeerController.m
//  MultipeerClientServer
//
//  Created by Mark Stultz on 5/31/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

#import "MCSThriftPeerController.h"

@interface MCSThriftPeerController ()

@property (nonatomic, strong) MCPeerID *peerID;
@property (nonatomic, strong) NSMutableSet *thriftServices;
@property (nonatomic, strong) NSMutableSet *activeThriftServices;
@property (nonatomic, strong) NSMutableSet *thriftProcessors;

@end

@implementation MCSThriftPeerController

- (instancetype)initWithPeer:(MCPeerID *)peerID
{
	self = [super init];
	if (self) {
		self.peerID = peerID;
		self.thriftServices = [NSMutableSet set];
		self.activeThriftServices = [NSMutableSet set];
		self.thriftProcessors = [NSMutableSet set];
	}
	
	return self;
}

- (void)enqueueThriftService:(id)thriftService
{
	[self.thriftServices addObject:thriftService];
	[self.activeThriftServices removeObject:thriftService];
}

- (id)dequeueThriftService
{
	id thriftService = self.thriftServices.anyObject;
	if (thriftService) {
		[self.thriftServices removeObject:thriftService];
		[self.activeThriftServices addObject:thriftService];
	}
	
	return thriftService;
}

- (void)addThriftService:(id)thriftService
{
	[self.thriftServices addObject:thriftService];
}

- (void)addProcessor:(id<TProcessor>)processor
{
	[self.thriftProcessors addObject:processor];
}

@end
