//
//  MSMultipeerClient.h
//  MSMultipeerNetworking
//
//  Created by Mark Stultz on 4/20/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

#import "MSMultipeer.h"

@interface MSMultipeerClient : MSMultipeer

@property (nonatomic, strong, readonly) NSArray *nearbyServers;

- (id)initWithServiceType:(NSString *)serviceType maxConcurrentRequests:(NSUInteger)maxConcurrentRequests;

- (void)startBrowsingForHosts;
- (void)stopBrowsingForHosts;

- (void)connectToHost:(MCPeerID *)hostPeerID;

@end
