//
//  MSThriftController.h
//  MSMultipeerNetworking
//
//  Created by Mark Stultz on 5/30/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

@import Foundation;
@import MultipeerConnectivity;

@class MSMultipeer;

@interface MSThriftController : NSObject

@property (nonatomic, assign) NSUInteger maxConnections;
@property (nonatomic, assign) Class outgoingThriftServiceClass;
@property (nonatomic, copy) id (^incomingThriftProcessorInstantiationBlock)(void);

- (id)initWithMultipeer:(MSMultipeer *)multipeer;

- (void)startBidirectionalConnectionsToPeer:(MCPeerID *)peerID;
- (void)receiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID;
- (void)removeConnectionsForPeer:(MCPeerID *)peerID;

- (void)enqueueThriftService:(id)thriftService forPeer:(MCPeerID *)peerID;
- (void)dequeueThriftService:(void (^)(id thriftService))completion forPeer:(MCPeerID *)peerID;

@end
