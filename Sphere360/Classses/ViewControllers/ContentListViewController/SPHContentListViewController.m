//
//  SPHContentListViewController.m
//  Sphere360
//
//  Created by Stas Volskyi on 08.12.14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

static NSString *const BaseApiPath = @"http://api.360.tv/";

#import "SPHContentListViewController.h"
#import "SPHContentCollectionViewCell.h"
#import "SPHPhotoViewController.h"
#import "SPHVideoViewController.h"
#import "SPHBaseViewController.h"

@interface SPHContentListViewController () <UICollectionViewDataSource, UICollectionViewDelegate>

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;

@property (assign, nonatomic) MediaType mediaType;

@end

@implementation SPHContentListViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self generateTitle];
}

#pragma mark - Private

- (void)generateTitle
{
    NSString *title = self.dataSource[0][@"type"];
    if ([title isEqualToString:@"video"]) {
        self.mediaType = MediaTypeVideo;
    } else {
        self.mediaType = MediaTypePhoto;
    }
    title = [title capitalizedString];
    self.navigationItem.title = [NSString stringWithFormat:@"%@ samples", title ? title : @"No"];
}

- (void)setImageWithPath:(NSString *)path forView:(UIImageView *)view
{
    NSString *filePath = [NSString stringWithFormat:@"%@%@", BaseApiPath, path];
    
    __block UIImageView *imageView = view;
    dispatch_async(dispatch_queue_create("queue", nil), ^{
        UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:filePath]]];
        dispatch_async(dispatch_get_main_queue(), ^{
            imageView.image = image;
        });
    });
}

- (void)showContentAtIndex:(NSIndexPath *)indexPath
{
    NSDictionary *dict = self.dataSource[indexPath.row];
    SPHBaseViewController *baseController;
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    SPHContentCollectionViewCell *cell = (SPHContentCollectionViewCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
    switch (self.mediaType) {
        case MediaTypePhoto: {
            baseController = [storyboard instantiateViewControllerWithIdentifier:@"photo"];
            baseController.sourceImage = [UIImage getImageFromSourceStringURL:[NSString stringWithFormat:@"%@%@", BaseApiPath, dict[@"path_high"]]];
            break;
        }
        case MediaTypeVideo: {
            baseController = [storyboard instantiateViewControllerWithIdentifier:@"video"];
            baseController.sourceURL = [NSString stringWithFormat:@"http://player.vimeo.com/external/%@", dict[@"path_high"]];
            break;
        }
        default:
            break;
    }
    baseController.mediaType = self.mediaType;
    [self.navigationController pushViewController:baseController animated:YES];
    [cell.downloadingActivityIndicator stopAnimating];
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return self.dataSource.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    SPHContentCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"contentCell" forIndexPath:indexPath];
    
    NSDictionary *dict = self.dataSource[indexPath.row];
    [self setImageWithPath:dict[@"thumb_path"] forView:cell.thumbnailImageView];
    cell.titleLabel.text = dict[@"title"];
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    SPHContentCollectionViewCell *cell = (SPHContentCollectionViewCell *)[collectionView cellForItemAtIndexPath:indexPath];
    [cell.downloadingActivityIndicator startAnimating];
    dispatch_queue_t serialQueue = dispatch_queue_create("serialQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(serialQueue, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self showContentAtIndex:indexPath];
        });
    });
}

@end
