//
//  SPHPhotoViewController.m
//  Sphere360
//
//  Created by Kirill on 12/5/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

#import "SPHPhotoViewController.h"

@interface SPHPhotoViewController ()

@property (weak, nonatomic) IBOutlet UIView *bottomView;

@end

@implementation SPHPhotoViewController

#pragma mark - LifeCycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupUI];
}

#pragma mark - LifeCycle

- (void)tapGesture
{
    [super tapGesture];
    [self hideBottomBar];
}

- (void)hideBottomBar
{
    [self hideBottomBarView:self.bottomView];
}

#pragma mark - IBActions

- (IBAction)gyroscopeButtonPress:(id)sender
{
    [super gyroscopeChoose];
}

- (void)setupUI
{
    [self applyImageTexture];
}

- (void)applyImageTexture
{
    UIImage *sourceImage = [UIImage imageWithContentsOfFile:self.sourceURL];
    if (!sourceImage) {
        NSData *imageData = [NSData dataWithContentsOfURL: [NSURL URLWithString:self.sourceURL]];
        sourceImage = [UIImage imageWithData:imageData];
    }
    UIImage* flippedImage = [UIImage flipAndMirrorImageHorizontally:sourceImage];
    [self setupTextureWithImage:flippedImage];
}

@end