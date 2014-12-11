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
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *downloadingActivityIndicator;

@property (assign, nonatomic) CGFloat urlAssetDuration;
@property (strong, nonatomic) AVURLAsset *urlAsset;
@property (strong, nonatomic) SPHVideoPlayer *videoPlayer;
@property (assign, nonatomic) BOOL isPlaying;

@property (assign, nonatomic) CGFloat playedProgress;
@property (assign, nonatomic) CGFloat downloadedProgress;

@end

@implementation SPHVideoViewController

#pragma mark - LifeCycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupVideoUI];
    [self setupVideoPlayer];
    
    [self.downloadingActivityIndicator startAnimating];
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
        self.isPlaying = NO;
    } else {
        [self.playStopButton setTitle:@"Pause" forState:UIControlStateNormal];
        [self.videoPlayer play];
        self.volumeSlider.value = self.videoPlayer.volume;
        self.isPlaying = YES;
    }
}

#pragma mark - Video

- (void)setupVideoPlayer
{
    if (self.mediaType == MediaTypeVideo) {
//        NSURL *urlToFile = [NSURL URLWithString:self.sourceURL];
        //local resource
        NSString *url = [[NSBundle mainBundle] pathForResource:@"3D" ofType:@"mp4"];
        NSURL *urlToFile = [NSURL fileURLWithPath: url];
        
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
    [self enableControlls];
}

- (void)progressUpdateToTime:(CGFloat)progress
{
    if ([self.videoPlayer isPlayerPlayVideo]) {
        self.videoProgressSlider.value = progress;
        NSLog(@"Progress - %f", progress * 100);
    }
    self.playedProgress = progress;
}

- (void)progressChangedToTime:(CMTime)time
{
    
}

- (void)downloadingProgress:(CGFloat)progress
{
    NSLog(@"Downloaded - %f percentage", progress * 100);
    self.downloadedProgress = progress;
    if (progress >= (self.playedProgress)) {
        [self.downloadingActivityIndicator startAnimating];
    } else {
        [self.downloadingActivityIndicator stopAnimating];
    }
    if ((progress - self.playedProgress) > 0.1) {
        [self enableControlls];
        if (self.isPlaying) {
            [self.videoPlayer play];
        }
    }
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
    [self setupTextureWithImage:[[UIImage alloc] init].CGImage];
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
    [self.videoPlayer pause];
    [self.downloadingActivityIndicator startAnimating];
    [self.videoPlayer seekPositionAtProgress:self.videoProgressSlider.value withPlayingStatus:self.isPlaying];
}

- (void)volumeSliderTouchedUp
{
    [self.videoPlayer setPlayerVolume:self.volumeSlider.value];
}

#pragma mark - Private

- (void)disableControls
{
    self.playStopButton.enabled = NO;
    self.videoProgressSlider.enabled = NO;
    self.gyroscopeButton.enabled = NO;
    self.volumeSlider.enabled = NO;
    [self.downloadingActivityIndicator startAnimating];
}

- (void)enableControlls
{
    self.playStopButton.enabled = YES;
    self.videoProgressSlider.enabled = YES;
    self.gyroscopeButton.enabled = YES;
    self.volumeSlider.enabled = YES;
    [self.downloadingActivityIndicator stopAnimating];
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

@end
