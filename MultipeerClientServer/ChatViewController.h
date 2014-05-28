//
//  ChatViewController.h
//  MultipeerClientServer
//
//  Created by Mark Stultz on 5/6/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

@import UIKit;

#import "ChatAppAsyncAPI.h"
#import "MCSPeer.h"

@interface ChatViewController : UIViewController

@property (nonatomic, strong) Chat *chat;
@property (nonatomic, strong) id<ChatAppAsyncAPI> chatAppAPI;
@property (nonatomic, strong) MCSPeer *peer;

@end
