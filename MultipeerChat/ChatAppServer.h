//
//  ChatAppServer.h
//  MSMultipeerNetworking
//
//  Created by Mark Stultz on 4/30/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

#import "MSMultipeerServer.h"
#import "ChatAppAsyncAPI.h"

@interface ChatAppServer : MSMultipeerServer <ChatAppAsyncAPI>

- (id)initWithServiceType:(NSString *)serviceType;

@end
