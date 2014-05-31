//
//  ChatAppClient.m
//  MultipeerClientServer
//
//  Created by Mark Stultz on 4/30/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

#import "ChatAppClient.h"
#import "MCSClient.h"
#import "ChatAppAPI.h"

@interface ChatAppClient ()

@property (nonatomic, strong) MCSClient *client;
@end

@implementation ChatAppClient

- (id)init
{
	self = [super initWithServiceType:@"ms-multichat" maxConcurrentRequests:3];
	if (self) {
		self.thriftServiceClass = [ChatAppAPIClient class];
	}
	
	return self;
}

#pragma mark ChatAppAsyncAPI

- (void)addMessage:(Message *)message withCompletion:(void(^)(int32_t revision))completion
{
	if (!completion) {
		return;
	}
	
	[self sendThriftOperation:^(id thriftService) {
		ChatAppAPIClient *client = thriftService;
		int32_t result = [client addMessage:message];
		completion(result);
	}];
}

- (void)getChatRevisionWithCompletion:(void(^)(int32_t revision))completion
{
	if (!completion) {
		return;
	}

	[self sendThriftOperation:^(id thriftService) {
		ChatAppAPIClient *client = thriftService;
		int32_t revision = [client getChatRevision];
		completion(revision);
	}];
}

- (void)getChatWithCompletion:(void(^)(Chat *chat))completion
{
	if (!completion) {
		return;
	}
	
	[self sendThriftOperation:^(id thriftService) {
		Chat *chat = nil;
				
		ChatAppAPIClient *client = thriftService;
		if (client) {
			chat = [client getChat];
		}

		if (completion) {
			completion(chat);
		}
	}];
}

@end
