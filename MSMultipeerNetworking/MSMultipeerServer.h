//
//  MSMultipeerServer.h
//  MSMultipeerNetworking
//
//  Created by Mark Stultz on 4/20/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

#import "MSMultipeer.h"

@interface MSMultipeerServer : MSMultipeer

- (void)sendThriftEvent:(void(^)(id thriftService))thriftOperation;

@end
