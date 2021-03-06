//
//  ChatAppClient.m
//  MSMultipeerNetworking
//
//  Created by Mark Stultz on 4/30/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

#import "ChatAppClient.h"
#import "MSMultipeerClient.h"
#import "ChatAppAPI.h"

@interface ChatAppClient () <ChatAppServerEvents>

@property (nonatomic, strong) Chat *chat;

@end

@implementation ChatAppClient

- (id)init
{
	self = [super initWithServiceType:@"ms-multichat" maxConcurrentRequests:3];
	if (self) {
		self.chat = [[Chat alloc] initWithRevision:0 messages:[NSMutableArray array]];
		
		__weak ChatAppClient *weakSelf = self;
		self.outgoingThriftServiceClass = [ChatAppAPIClient class];
		self.incomingThriftProcessorInstantiationBlock = ^{ return [[ChatAppServerEventsProcessor alloc] initWithChatAppServerEvents:weakSelf]; };
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

#pragma mark ChatAppServerEvents

- (void)chatUpdated:(int32_t)revision
{
	[self getChatWithCompletion:^(Chat *chat) {
		if (chat) {
			[self.chat willChangeValueForKey:@"revision"];
			self.chat.revision = chat.revision;
			self.chat.messages = chat.messages;
			[self.chat didChangeValueForKey:@"revision"];
		}
	}];
}

@end
