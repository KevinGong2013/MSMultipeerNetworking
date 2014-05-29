//
//  ChatAppClient.m
//  MultipeerClientServer
//
//  Created by Mark Stultz on 4/30/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

#import "ChatAppClient.h"
#import "ChatAppAPI.h"

@interface ChatAppClient ()

@property (nonatomic, strong) NSOperationQueue *operationQueue;

@end

@implementation ChatAppClient

- (id)initWithServiceType:(NSString *)serviceType maxConcurrentRequests:(NSUInteger)maxConcurrentRequests
{
	self = [super initWithServiceType:serviceType maxConcurrentRequests:maxConcurrentRequests];
	if (self) {
		self.thriftServiceClass = [ChatAppAPIClient class];
		self.operationQueue = [[NSOperationQueue alloc] init];
		self.operationQueue.maxConcurrentOperationCount = maxConcurrentRequests;
	}
	
	return self;
}

#pragma mark ChatAppAsyncAPI

- (void)addMessage:(Message *)message withCompletion:(void(^)(int32_t revision))completion
{
	if (!completion) {
		return;
	}

	[self dequeueThriftService:^(id thriftService) {
		ChatAppAPIClient *client = thriftService;
		if (!client) {
			completion(0);
		}
		else {
			NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
				int32_t result = [client addMessage:message];
				completion(result);
			}];
			
			operation.completionBlock = ^{
				[self enqueueThriftService:client];
			};
			
			[self.operationQueue addOperation:operation];
		}
	}];
}

- (void)getChatRevisionWithCompletion:(void(^)(int32_t revision))completion
{
	if (!completion) {
		return;
	}

	[self dequeueThriftService:^(id thriftService) {
		ChatAppAPIClient *client = thriftService;
		if (!client) {
			completion(0);
		}
		else {
			NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
				int32_t revision = [client getChatRevision];
				completion(revision);
			}];
			
			operation.completionBlock = ^{
				[self enqueueThriftService:client];
			};
			
			[self.operationQueue addOperation:operation];
		}
	}];
}

- (void)getChatWithCompletion:(void(^)(Chat *chat))completion
{
	if (!completion) {
		return;
	}

	[self dequeueThriftService:^(id thriftService) {
		ChatAppAPIClient *client = thriftService;
		if (!client) {
			completion(nil);
		}
		else {
			NSBlockOperation *operation = [NSBlockOperation blockOperationWithBlock:^{
				Chat *chat = [client getChat];
				if (completion) {
					completion(chat);
				}
			}];
			
			operation.completionBlock = ^{
				[self enqueueThriftService:client];
			};
			
			[self.operationQueue addOperation:operation];
		}
	}];
}

@end
