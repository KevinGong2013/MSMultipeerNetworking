//
//  NearbyServersDataSource.h
//  MSMultipeerNetworking
//
//  Created by Mark Stultz on 4/15/14.
//  Copyright (c) 2014 Mark Stultz. All rights reserved.
//

@import Foundation;

@class MSMultipeerClient;

@interface NearbyServersDataSource : NSObject

- (id)initWithCollectionView:(UICollectionView *)collectionView multipeerClient:(MSMultipeerClient *)multipeerClient;

@end
