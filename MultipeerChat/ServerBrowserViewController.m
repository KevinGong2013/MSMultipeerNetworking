//
//  ServerBrowserViewController.m
//  MSMultipeerNetworking
//
//  Created by Mark Stultz on 4/15/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

#import "ServerBrowserViewController.h"
#import "SVProgressHUD.h"
#import "NearbyServersDataSource.h"
#import "MSNearbyServer.h"
#import "MSMultipeerClient.h"

@interface ServerBrowserViewController () <UICollectionViewDelegate>

@property (nonatomic, weak) IBOutlet UICollectionView *collectionView;
@property (nonatomic, strong) NearbyServersDataSource *nearbyServersDataSource;

- (IBAction)back:(id)sender;

@end

@implementation ServerBrowserViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	self.nearbyServersDataSource = [[NearbyServersDataSource alloc] initWithCollectionView:self.collectionView multipeerClient:self.multipeerClient];
	self.collectionView.delegate = self;
}

- (IBAction)back:(id)sender
{
	[self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.row < self.multipeerClient.nearbyServers.count) {
		UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
		cell.backgroundColor = [UIColor colorWithHue:0.f saturation:0.f brightness:0.85f alpha:1.f];
		
		MSNearbyServer *nearbyServer = self.multipeerClient.nearbyServers[ indexPath.row ];
		if ([self.delegate respondsToSelector:@selector(serverBrowserViewController:wantsToJoinPeer:)]) {
			[self.delegate serverBrowserViewController:self wantsToJoinPeer:nearbyServer.peerID];
		}
	}
}

- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
	UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
	cell.backgroundColor = [UIColor colorWithHue:0.f saturation:0.f brightness:0.85f alpha:1.f];
}

- (void)collectionView:(UICollectionView *)collectionView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath
{
	UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
	cell.backgroundColor = [UIColor whiteColor];
}

@end
