//
//  ChatAppServer.m
//  MSMultipeerNetworking
//
//  Created by Mark Stultz on 4/30/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

#import "ChatAppServer.h"
#import "ChatAppAPI.h"

@interface ChatAppServer () <ChatAppAPI>

@property (nonatomic, strong) Chat *chat;

@end

@implementation ChatAppServer

- (id)initWithServiceType:(NSString *)serviceType
{
	self = [super initWithServiceType:serviceType maxConcurrentRequests:3];
	if (self) {
		self.chat = [[Chat alloc] initWithRevision:0 messages:[NSMutableArray array]];

		__weak ChatAppServer *weakSelf = self;
		self.outgoingThriftServiceClass = [ChatAppServerEventsClient class];
		self.incomingThriftProcessorInstantiationBlock = ^{ return [[ChatAppAPIProcessor alloc] initWithChatAppAPI:weakSelf]; };
	}
	
	return self;
}

#pragma mark ChatAppAsyncAPI

- (void)addMessage:(Message *)message withCompletion:(void(^)(int32_t revision))completion
{
	if (completion) {
		int32_t result = [self addMessage:message];
		completion(result);
	}
}

- (void)getChatRevisionWithCompletion:(void(^)(int32_t revision))completion
{
	if (completion) {
		int32_t revision = [self getChatRevision];
		completion(revision);
	}
}

- (void)getChatWithCompletion:(void(^)(Chat *chat))completion
{
	if (completion) {
		Chat *chat = [self getChat];
		completion(chat);
	}
}

#pragma mark ChatAppAPI

- (int32_t)addMessage:(Message *)message
{
	[self.chat.messages addObject:message];
	self.chat.revision = self.chat.revision + 1;
	
	[self sendThriftEvent:^(id thriftService) {
		ChatAppServerEventsClient *client = thriftService;
		[client chatUpdated:self.chat.revision];
	}];
	
	return self.chat.revision;
}

- (int32_t)getChatRevision
{
	return self.chat.revision;
}

- (Chat *)getChat
{
	return self.chat;
}

@end
