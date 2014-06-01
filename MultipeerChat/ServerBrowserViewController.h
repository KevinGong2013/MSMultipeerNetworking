//
//  ServerBrowserViewController.h
//  MSMultipeerNetworking
//
//  Created by Mark Stultz on 4/15/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

@import UIKit;
@import MultipeerConnectivity;

@class MSMultipeerClient;

@protocol ServerBrowserViewControllerDelegate;

@interface ServerBrowserViewController : UIViewController

@property (nonatomic, strong) MSMultipeerClient *multipeerClient;
@property (nonatomic, weak) id<ServerBrowserViewControllerDelegate> delegate;

@end

@protocol ServerBrowserViewControllerDelegate <NSObject>

- (void)serverBrowserViewController:(ServerBrowserViewController *)viewController wantsToJoinPeer:(MCPeerID *)peerID;

@end