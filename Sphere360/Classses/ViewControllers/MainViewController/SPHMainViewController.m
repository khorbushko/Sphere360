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
     id viewController = [segue destinationViewController];
    if ([segue.identifier isEqualToString:MVCPhotoSegue]) {
        ((SPHPhotoViewController *)viewController).selectedController = PhotoViewController;
        ((SPHPhotoViewController *)viewController).sourceURL = @"http://api.360.tv/GIR000156.jpg";
    } else if ([segue.identifier isEqualToString:MVCVideoSegue]){
        ((SPHVideoViewController *)viewController).selectedController = VideoViewController;
        ((SPHVideoViewController *)viewController).sourceURL = @"http://player.vimeo.com/external/96616956.hd.mp4?s=a30e67fc675df30962308e3239fe09e6";
    } else if ([segue.identifier isEqualToString:MVCLiveSegue]) {
        ((SPHBaseViewController *)viewController).selectedController = LiveViewController;
        ((SPHBaseViewController *)viewController).sourceURL = @"http://pdl.vimeocdn.com/32832/736/257635005.mp4?token2=1417638082_e16e52797027cf8e94f9d963cf25e005&aksessionid=3cd7eed7b511225f87e03303d1b9f24fa9703d5b1417623682";
    }
}

@end
