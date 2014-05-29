//
//  MCSClient.h
//  MultipeerClientServer
//
//  Created by Mark Stultz on 4/20/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

#import "MCSPeer.h"

@interface MCSClient : MCSPeer

@property (nonatomic, strong, readonly) NSArray *nearbyServers;
@property (nonatomic, assign, readonly) BOOL connected;
@property (nonatomic, assign) Class thriftServiceClass;

- (id)initWithServiceType:(NSString *)serviceType maxConcurrentRequests:(NSUInteger)maxConcurrentRequests;

- (void)startBrowsingForHosts;
- (void)stopBrowsingForHosts;

- (void)connectToHost:(MCPeerID *)hostPeerID completion:(void(^)())completion;

- (void)enqueueThriftService:(id)thriftService;
- (void)dequeueThriftService:(void (^)(id thriftService))completion;

@end
