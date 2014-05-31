//
//  MCSThriftController.h
//  MultipeerClientServer
//
//  Created by Mark Stultz on 5/30/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

@import Foundation;
@import MultipeerConnectivity;

@protocol MCSStreamCreationDelegate <NSObject>

- (void)startStreamWithName:(NSString *)name toPeer:(MCPeerID *)peerID completion:(void(^)(NSInputStream *inputStream, NSOutputStream *outputStream))completion;

@end

@interface MCSThriftController : NSObject

@property (nonatomic, assign) NSUInteger maxConnections;
@property (nonatomic, assign) Class thriftServiceClass;
@property (nonatomic, weak) id<MCSStreamCreationDelegate> streamCreationDelegate;

- (void)startBidirectionalConnectionsToPeer:(MCPeerID *)peerID;

- (void)enqueueThriftService:(id)thriftService;
- (void)dequeueThriftService:(void (^)(id thriftService))completion;

@end
