//
//  MSPeerThriftInfo.h
//  MSMultipeerNetworking
//
//  Created by Mark Stultz on 5/31/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

@import Foundation;
@import MultipeerConnectivity;

#import "TSharedProcessorFactory.h"

@interface MSPeerThriftInfo : NSObject

- (instancetype)initWithPeer:(MCPeerID *)peerID;

- (void)enqueueThriftService:(id)thriftService;
- (id)dequeueThriftService;

- (void)addThriftService:(id)thriftService;
- (void)addProcessor:(id<TProcessor>)processor;

@end
