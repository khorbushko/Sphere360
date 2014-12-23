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
#import "SPHInternetConnection.h"
#import "MBProgressHUD.h"

@interface SPHContentListViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>

@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;

@property (assign, nonatomic) MediaType mediaType;
@property (assign, nonatomic) UIEdgeInsets landscapeInsets;
@property (assign, nonatomic) UIEdgeInsets portraitInsets;
@property (strong, nonatomic) MBProgressHUD *HUD;

@property (strong, nonatomic) NSMutableDictionary *thumbnails;

@end

@implementation SPHContentListViewController

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self generateTitle];
    self.landscapeInsets = UIEdgeInsetsMake(0, 20, 0, 0);
    self.portraitInsets = UIEdgeInsetsMake(0, 0, 0, 0);
    
    self.HUD = [[MBProgressHUD alloc] initWithView:self.navigationController.view];
    [self.navigationController.view addSubview:self.HUD];
    self.HUD.delegate = (id)self;
    self.HUD.labelText = @"Loading";
    
    [self loadThumbnails];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateUIForOrientation:self.interfaceOrientation];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self updateUIForOrientation:self.interfaceOrientation];
}

#pragma mark - Private

- (void)loadThumbnails
{
    self.thumbnails = [[NSMutableDictionary alloc] init];
    __weak SPHContentListViewController *weakSelf = self;
    for (NSDictionary *dict in self.dataSource) {
        NSString *filePath = [NSString stringWithFormat:@"%@%@", BaseApiPath, dict[@"thumb_path"]];
        dispatch_async(dispatch_queue_create("queue", nil), ^{
            NSString *key = dict[@"thumb_path"];
            UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:filePath]]];
            if (image) {
                [weakSelf.thumbnails setObject:image forKey:key];
            }
            if ([weakSelf.thumbnails allKeys].count == self.dataSource.count) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [weakSelf.collectionView reloadData];
                });
            }
        });
    }
}

- (void)updateUIForOrientation:(UIInterfaceOrientation)orientation
{
    if (UIInterfaceOrientationIsPortrait(orientation)) {
        [self applyPortraitDirection];
    } else {
        [self applyLandscapeDirection];
    }
    [self.collectionView reloadData];
}

- (void)applyPortraitDirection
{
    ((UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout).sectionInset = self.portraitInsets;
    ((UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout).scrollDirection = UICollectionViewScrollDirectionVertical;
}

- (void)applyLandscapeDirection
{
    ((UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout).sectionInset = self.landscapeInsets;
    ((UICollectionViewFlowLayout *)self.collectionView.collectionViewLayout).scrollDirection = UICollectionViewScrollDirectionHorizontal;
}

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

- (void)showContentAtIndex:(NSIndexPath *)indexPath
{
    NSDictionary *dict = self.dataSource[indexPath.row];
    SPHBaseViewController *baseController;
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    
    switch (self.mediaType) {
        case MediaTypePhoto: {
            baseController = [storyboard instantiateViewControllerWithIdentifier:@"photo"];
            baseController.mediaType = self.mediaType;
            [self.HUD showAnimated:YES whileExecutingBlock:^{
                baseController.sourceImage = [UIImage getImageFromSourceStringURL:/*[[NSBundle mainBundle] pathForResource:@"GIR000009" ofType:@"jpeg"]];/*/[NSString stringWithFormat:@"%@%@", BaseApiPath, dict[@"path_high"]]];

            } completionBlock:^{
                [self.HUD hide:YES afterDelay:2];
                [self.navigationController pushViewController:baseController animated:YES];
            }];
            break;
        }
        case MediaTypeVideo: {
            baseController = [storyboard instantiateViewControllerWithIdentifier:@"video"];
            baseController.sourceURL = [NSString stringWithFormat:@"http://player.vimeo.com/external/%@", dict[@"path_high"]];
            baseController.mediaType = self.mediaType;
            [self.navigationController pushViewController:baseController animated:YES];
            break;
        }
        case MediaTypeLive: {
            //todo
            break;
        }
        default:
            break;
    }
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
    if (self.thumbnails[dict[@"thumb_path"]]) {
        cell.thumbnailImageView.image = self.thumbnails[dict[@"thumb_path"]];
    }
    cell.titleLabel.text = dict[@"title"];
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if ([SPHInternetConnection isInternetAvaliable]) {
        [self performSelector:@selector(showContentAtIndex:) withObject:indexPath afterDelay:0.1];
    } else {
        [SPHInternetConnection notificationNoInternetAvaliable];
    }
}

@end
