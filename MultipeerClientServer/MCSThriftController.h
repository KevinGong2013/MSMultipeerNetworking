//
//  MCSThriftController.h
//  MultipeerClientServer
//
//  Created by Mark Stultz on 5/30/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

@import Foundation;
@import MultipeerConnectivity;

@class MCSPeer;

@interface MCSThriftController : NSObject

@property (nonatomic, assign) NSUInteger maxConnections;
@property (nonatomic, assign) Class thriftServiceClass;

- (id)initWithPeer:(MCSPeer *)peer;

- (void)startBidirectionalConnectionsToPeer:(MCPeerID *)peerID;
- (void)receiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID;
- (void)removeConnectionsForPeer:(MCPeerID *)peerID;

- (void)enqueueThriftService:(id)thriftService;
- (void)dequeueThriftService:(void (^)(id thriftService))completion;

@end
