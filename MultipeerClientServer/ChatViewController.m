//
//  ChatViewController.m
//  MultipeerClientServer
//
//  Created by Mark Stultz on 5/6/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

#import "ChatViewController.h"
#import "MSMessageViewController.h"

static void *ChatRevisionContext = &ChatRevisionContext;

@interface ChatViewController () <MSMessageViewControllerDelegate>

@property (nonatomic, strong) MSMessageViewController *messageViewController;

- (MSMessageBubbleViewModel *)messageBubbleViewModelForMessageText:(NSString *)messageText isAuthor:(BOOL)isAuthor;

@end

@implementation ChatViewController

- (void)dealloc
{
	[self.chatAppAPI.chat removeObserver:self forKeyPath:@"revision"];
}

- (void)viewDidLoad
{
	[super viewDidLoad];

	[self.chatAppAPI.chat addObserver:self forKeyPath:@"revision" options:NSKeyValueObservingOptionNew context:ChatRevisionContext];
}

- (void)viewWillLayoutSubviews
{
	self.messageViewController.maxKeyboardLayoutGuide = self.topLayoutGuide;
	[super viewWillLayoutSubviews];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
	if ([segue.identifier isEqualToString:@"embedMessageViewSegue"]) {
		self.messageViewController = segue.destinationViewController;
		self.messageViewController.delegate = self;
	}
	else {
		return [super prepareForSegue:segue sender:sender];
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context == ChatRevisionContext) {
		dispatch_async(dispatch_get_main_queue(), ^{
			[self.messageViewController reloadData];
		});
	}
	else {
		return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (MSMessageBubbleViewModel *)messageBubbleViewModelForMessageText:(NSString *)messageText isAuthor:(BOOL)isAuthor
{
	MSMessageBubbleLayoutSpec *layoutSpec = [[MSMessageBubbleLayoutSpec alloc] init];
	layoutSpec.collectionViewSize = self.view.bounds.size;
	layoutSpec.bubbleMaskImageSize = CGSizeMake(48.f, 35.f);
	layoutSpec.bubbleMaskOffset = CGPointMake(20.f, 16.f);
	layoutSpec.alignMessageLabelRight = isAuthor;
	
	if (isAuthor) {
		layoutSpec.messageBubbleInsets = UIEdgeInsetsMake(0.f, 74.f, 0.f, 10.f);
		layoutSpec.messageLabelInsets = UIEdgeInsetsMake(6.5f, 12.f, 7.5f, 18.f);
	}
	else {
		layoutSpec.messageBubbleInsets = UIEdgeInsetsMake(0.f, 10.f, 0.f, 74.f);
		layoutSpec.messageLabelInsets = UIEdgeInsetsMake(6.5f, 18.f, 7.5f, 12.f);
	}
	
	CGFloat constraintWidth = self.view.bounds.size.width - (layoutSpec.messageBubbleInsets.left + layoutSpec.messageBubbleInsets.right + layoutSpec.messageLabelInsets.left + layoutSpec.messageLabelInsets.right);
	CGSize constraintSize = CGSizeMake(constraintWidth, MAXFLOAT);
	layoutSpec.messageLabelSize = [messageText boundingRectWithSize:constraintSize
																			  options:NSStringDrawingUsesLineFragmentOrigin
																		  attributes:@{ NSFontAttributeName : [UIFont preferredFontForTextStyle:UIFontTextStyleBody] }
																			  context:nil].size;
	
	return [[MSMessageBubbleViewModel alloc] initWithMessageLabelText:messageText isAuthor:isAuthor layoutSpec:layoutSpec];
}

#pragma mark MSMessageViewControllerDelegate

- (MSMessageInputViewModel *)messageInputViewModel
{
	MSMessageInputLayoutSpec *layoutSpec = [[MSMessageInputLayoutSpec alloc] init];
	//layoutSpec.messageInputTextViewContentInset = UIEdgeInsetsMake(5.f, 3.f, 0.f, 0.f);
	layoutSpec.messageInputTextViewContentInset = UIEdgeInsetsMake(5.f, 3.f, -2.f, 0.f);
	layoutSpec.messageInputTextViewPadding = UIEdgeInsetsMake(8.f, 8.f, 8.f, 8.f);
	
	MSMessageInputViewModel *viewModel = [[MSMessageInputViewModel alloc] initWithLayoutSpec:layoutSpec];
	viewModel.messageInputCornerRadius = 5.f;
	viewModel.messageInputBorderWidth = 0.5f;
	viewModel.messageInputBackgroundColor = [UIColor colorWithWhite:1 alpha:0.825f];
	viewModel.messageInputBorderColor = [UIColor colorWithWhite:0.5f alpha:0.4f];
	viewModel.messageInputFont = [UIFont systemFontOfSize:16];
	viewModel.messageInputFontColor = [UIColor darkTextColor];
	viewModel.sendButtonFont = [UIFont boldSystemFontOfSize:17.f];
	viewModel.backgroundToolbarName = @"backgroundToolbar";
	viewModel.inputTextViewName = @"inputTextView";
	viewModel.sendButtonName = @"sendButton";
	
	viewModel.layoutConstraints = @[
	  @"H:[sendButton]-6-|",
	  @"V:[sendButton]-4.5-|",
	  [NSString stringWithFormat:@"H:|-%.2f-[inputTextView]-%.2f-[sendButton]-6-|", viewModel.layoutSpec.messageInputTextViewPadding.left, viewModel.layoutSpec.messageInputTextViewPadding.right],
	  [NSString stringWithFormat:@"V:|-%.2f-[inputTextView]-%.2f-|", viewModel.layoutSpec.messageInputTextViewPadding.top, viewModel.layoutSpec.messageInputTextViewPadding.bottom],
  ];
	
	return viewModel;
}

- (NSUInteger)messageCount
{
	return self.chatAppAPI.chat.messages.count;
}

- (CGSize)sizeForItemAtIndexPath:(NSIndexPath *)indexPath
{
	Message *message = self.chatAppAPI.chat.messages[ indexPath.row ];
	BOOL isAuthor = [message.authorId isEqualToString:self.peer.uuid];
	MSMessageBubbleViewModel *viewModel = [self messageBubbleViewModelForMessageText:message.text isAuthor:isAuthor];
	return [viewModel.layoutSpec cellSize];
}

- (MSMessageBubbleViewModel *)messageBubbleViewModelAtIndexPath:(NSIndexPath *)indexPath
{
	Message *message = self.chatAppAPI.chat.messages[ indexPath.row ];
	BOOL isAuthor = [message.authorId isEqualToString:self.peer.uuid];
	return [self messageBubbleViewModelForMessageText:message.text isAuthor:isAuthor];
}

- (void)messageViewController:(MSMessageViewController *)messageViewController didSendMessageText:(NSString *)messageText
{
	Message *message = [[Message alloc] initWithAuthorId:self.peer.uuid text:messageText];
	[self.chatAppAPI addMessage:message withCompletion:^(int32_t revision) {
		/**/
	}];
}

@end
