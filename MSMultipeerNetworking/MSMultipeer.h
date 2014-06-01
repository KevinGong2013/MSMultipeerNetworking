//
//  MSMultipeer.h
//  MSMultipeerNetworking
//
//  Created by Mark Stultz on 4/20/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

@import Foundation;
@import MultipeerConnectivity;

#import "MSThriftController.h"

@interface MSMultipeer : NSObject <MCSessionDelegate>

@property (nonatomic, assign) Class outgoingThriftServiceClass;
@property (nonatomic, copy) id (^incomingThriftProcessorInstantiationBlock)(void);

@property (nonatomic, strong, readonly) MCSession *session;
@property (nonatomic, copy, readonly) NSString *serviceType;
@property (nonatomic, copy, readonly) NSString *uuid;
@property (nonatomic, copy, readonly) NSArray *connectedPeers;
@property (nonatomic, strong, readonly) MSThriftController *thriftController;
@property (nonatomic, strong, readonly) NSOperationQueue *operationQueue;
@property (nonatomic, assign) BOOL connected;

- (id)initWithServiceType:(NSString *)serviceType maxConcurrentRequests:(NSUInteger)maxConcurrentRequests;

- (NSOutputStream *)startStreamWithName:(NSString *)streamName toPeer:(MCPeerID *)peer;

- (void)sendThriftOperation:(void(^)(id thriftService))thriftOperation;

@end
