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
#import "SPHUniversalViewController.h"

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
    SPHUniversalViewController *viewController = [segue destinationViewController];
    if ([segue.identifier isEqualToString:MVCPhotoSegue]) {
        viewController.selectedController = PhotoViewController;
        viewController.sourceURL = [[NSBundle mainBundle] pathForResource:kTestImage ofType:kTestImageType];
    } else if ([segue.identifier isEqualToString:MVCVideoSegue]){
        viewController.selectedController = VideoViewController;
        viewController.sourceURL = [[NSBundle mainBundle] pathForResource:kTestVideo ofType:kTestVideoType];
    } else if ([segue.identifier isEqualToString:MVCLiveSegue]) {
        viewController.selectedController = LiveViewController;
        viewController.sourceURL = @"http://pdl.vimeocdn.com/32832/736/257635005.mp4?token2=1417638082_e16e52797027cf8e94f9d963cf25e005&aksessionid=3cd7eed7b511225f87e03303d1b9f24fa9703d5b1417623682";
    }
}

@end
