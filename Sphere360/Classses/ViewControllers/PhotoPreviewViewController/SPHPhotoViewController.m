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
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomViewHeightConstraint;

@end

@implementation SPHPhotoViewController

#pragma mark - LifeCycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self applyImageTexture];
}

#pragma mark - Override

- (void)tapGesture
{
    [super tapGesture];
    [self hideBottomBar];
}

- (void)applyImageTexture
{
    [self setupTextureWithImage:self.sourceImage.CGImage];
}

#pragma mark - Private

- (void)hideBottomBar
{
    BOOL hidden = !self.navigationController.navigationBar.hidden;
    [self.navigationController setNavigationBarHidden:hidden animated:YES];
    CGFloat newHeight = hidden ? 0.0f : 60.0f;
    [UIView animateWithDuration:0.2 animations:^{
        self.bottomViewHeightConstraint.constant = newHeight;

        [self.bottomView layoutIfNeeded];
    }];
}

#pragma mark - IBActions

- (IBAction)gyroscopeButtonPress:(id)sender
{
    [super gyroscopeChoose];
}

- (IBAction)littlePlanitButtonPress:(id)sender
{
    [super turnPlanetMode];
    ((UIButton *)sender).selected = !((UIButton *)sender).selected;
}

@end