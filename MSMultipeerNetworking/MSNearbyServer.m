//
//  MSNearbyServer.m
//  MSMultipeerNetworking
//
//  Created by Mark Stultz on 4/15/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

#import "MSNearbyServer.h"

@interface MSNearbyServer ()

@property (nonatomic, copy) MCPeerID *peerID;
@property (nonatomic, copy) NSString *uuid;

@end

@implementation MSNearbyServer

- (id)initWithPeerID:(MCPeerID *)peerID discoveryInfo:(NSDictionary *)discoveryInfo
{
	self = [super init];
	if (self) {
		self.peerID = peerID;
		self.uuid = discoveryInfo[ @"uuid" ];
	}
	
	return self;
}

@end
