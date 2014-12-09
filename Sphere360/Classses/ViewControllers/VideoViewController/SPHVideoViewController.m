//
//  SPHVideoViewController.m
//  Sphere360
//
//  Created by Kirill on 12/5/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

#import "SPHVideoViewController.h"

@interface SPHVideoViewController () <SPHVideoPlayerDelegate>

@property (weak, nonatomic) IBOutlet UIView *bottomView;
@property (weak, nonatomic) IBOutlet UIButton *playStopButton;
@property (weak, nonatomic) IBOutlet UISlider *videoProgressSlider;
@property (weak, nonatomic) IBOutlet UISlider *volumeSlider;
@property (weak, nonatomic) IBOutlet UIButton *gyroscopeButton;

@property (assign, nonatomic) CGFloat urlAssetDuration;
@property (strong, nonatomic) AVURLAsset *urlAsset;
@property (strong, nonatomic) SPHVideoPlayer *videoPlayer;

@end

@implementation SPHVideoViewController

#pragma mark - LifeCycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupVideoUI];
    [self setupVideoPlayer];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self clearPlayer];
}

#pragma mark - Draw & update methods

- (void)update
{
    [super update];
    if ([self.videoPlayer isPlayerPlayVideo]) {
        [self setNewTextureFromVideoPlayer];
    }
}

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

- (IBAction)playStopButtonPress:(id)sender
{
    if ([self.videoPlayer isPlayerPlayVideo]) {
        [self.playStopButton setTitle:@"Play" forState:UIControlStateNormal];
        [self.videoPlayer pause];
    } else {
        [self.playStopButton setTitle:@"Pause" forState:UIControlStateNormal];
        [self.videoPlayer play];
        self.volumeSlider.value = self.videoPlayer.volume;
    }
}

#pragma mark - Video

- (void)setupVideoPlayer
{
    if (self.mediaType == MediaTypeVideo) {
        NSURL *urlToFile = [NSURL URLWithString:self.sourceURL];
        self.videoPlayer = [[SPHVideoPlayer alloc] initVideoPlayerWithURL:urlToFile];
        [self.videoPlayer prepareToPlay];
        self.videoPlayer.delegate = self;
    }
}

- (void)setNewTextureFromVideoPlayer
{
    if (self.videoPlayer) {
        if ([self.videoPlayer canProvideFrame]) {
            [self setupTextureWithImage:[self.videoPlayer getCurrentFramePicture]];
        }
    }
    [self drawArrayOfData];
}

#pragma mark - SPHVideoPlayerDelegate

- (void)isReadyToPlayVideo
{
    self.playStopButton.enabled = YES;
    self.videoProgressSlider.enabled = YES;
    self.gyroscopeButton.enabled = YES;
    self.volumeSlider.enabled = YES;
}

- (void)progressUpdateToTime:(CGFloat)progress
{
    if ([self.videoPlayer isPlayerPlayVideo]) {
        self.videoProgressSlider.value = progress;
        NSLog(@"Progress - %f", progress);
    }
}

- (void)progressChangedToTime:(CMTime)time
{
    
}

- (void)downloadingProgress:(CGFloat)progress
{
    NSLog(@"Downloaded - %f percentage", progress * 100);
}

#pragma mark - UIConfiguration

- (void)setupSlider
{
    [self.videoProgressSlider addTarget:self action:@selector(progressSliderTouchedDown) forControlEvents:UIControlEventTouchDown];
    [self.videoProgressSlider addTarget:self action:@selector(progressSliderTouchedUp) forControlEvents:UIControlEventTouchUpInside];
    [self.volumeSlider addTarget:self action:@selector(volumeSliderTouchedUp) forControlEvents:UIControlEventTouchUpInside];
}

- (void)setupVideoUI
{
    [self setupSlider];
    [self setupTextureWithImage:[[UIImage alloc] init]];
}

#pragma mark - Slider

- (void)progressSliderTouchedDown
{
    if ([self.videoPlayer isPlayerPlayVideo]) {
        [self.videoPlayer pause];
    }
}

- (void)progressSliderTouchedUp
{
    [self.videoPlayer seekPositionAtProgress:self.videoProgressSlider.value];
}

- (void)volumeSliderTouchedUp
{
    [self.videoPlayer setPlayerVolume:self.volumeSlider.value];
}

#pragma mark - Cleanup

- (void)clearPlayer
{
    [self.videoPlayer stop];
    [self.videoPlayer removeObserversFromPlayer];
    self.videoPlayer.delegate = nil;
    self.urlAsset = nil;
    self.videoPlayer = nil;
}

- (void)dealloc
{
    [self clearPlayer];
}

@end
