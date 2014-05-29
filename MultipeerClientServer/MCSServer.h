//
//  MCSServer.h
//  MultipeerClientServer
//
//  Created by Mark Stultz on 4/20/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

#import "MCSPeer.h"

@protocol MCSServerDelegate;

@interface MCSServer : MCSPeer

@property (nonatomic, weak) id<MCSServerDelegate> delegate;

@end

@protocol MCSServerDelegate <NSObject>
@optional
- (id)thriftProcessor;
@end
