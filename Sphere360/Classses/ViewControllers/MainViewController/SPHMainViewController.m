//
//  SPHMainViewController.m
//  Sphere360
//
//  Created by Kirill on 12/1/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

static NSString *const MVCPhotoSegue = @"photoSegue";
static NSString *const MVCVideoSegue = @"videoSegue";
static NSString *const MVCLiveSegue = @"liveSegue";

#import "SPHMainViewController.h"
#import "SPHVideoViewController.h"
#import "SPHPhotoViewController.h"
#import "SPHBaseViewController.h"

@interface SPHMainViewController ()

@end

@implementation SPHMainViewController

#pragma mark - LifeCycle

- (void)viewDidLoad
{
    [super viewDidLoad];
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:MVCPhotoSegue]) {
        SPHPhotoViewController *viewController = [segue destinationViewController];
        viewController.selectedController = PhotoViewController;
        viewController.sourceURL = @"http://api.360.tv/GIR000156.jpg";
    } else if ([segue.identifier isEqualToString:MVCVideoSegue]){
        SPHVideoViewController *viewController = [segue destinationViewController];
        viewController.selectedController = VideoViewController;
        viewController.sourceURL = @"http://player.vimeo.com/external/96616956.hd.mp4?s=a30e67fc675df30962308e3239fe09e6";
    } else if ([segue.identifier isEqualToString:MVCLiveSegue]) {
        //todo live
    }
}

@end
