//
//  MCSPeer.h
//  MultipeerClientServer
//
//  Created by Mark Stultz on 4/20/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

@import Foundation;
@import MultipeerConnectivity;

#import "MCSThriftController.h"

@interface MCSPeer : NSObject <MCSessionDelegate>

@property (nonatomic, assign) Class thriftServiceClass;

@property (nonatomic, strong, readonly) MCSession *session;
@property (nonatomic, copy, readonly) NSString *serviceType;
@property (nonatomic, copy, readonly) NSString *uuid;
@property (nonatomic, copy, readonly) NSArray *connectedPeers;
@property (nonatomic, strong, readonly) MCSThriftController *thriftController;
@property (nonatomic, assign) BOOL connected;

- (id)initWithServiceType:(NSString *)serviceType maxConcurrentRequests:(NSUInteger)maxConcurrentRequests;

- (void)sendThriftOperation:(void(^)(id thriftService))thriftOperation;

@end

