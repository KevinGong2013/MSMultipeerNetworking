//
//  ChatAppClient.h
//  MSMultipeerNetworking
//
//  Created by Mark Stultz on 4/30/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

#import "MSMultipeerClient.h"
#import "ChatAppAsyncAPI.h"

@interface ChatAppClient : MSMultipeerClient <ChatAppAsyncAPI>

@end
