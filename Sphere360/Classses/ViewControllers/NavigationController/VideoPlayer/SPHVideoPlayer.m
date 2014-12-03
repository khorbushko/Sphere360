//
//  SPHVideoPlayer.m
//  Sphere360
//
//  Created by Kirill on 12/2/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

#import "SPHVideoPlayer.h"
#import "SPHTextureProvider.h"

static const NSString *ItemStatusContext;

@interface SPHVideoPlayer()

@property (strong, nonatomic) AVPlayer *assetPlayer;
@property (strong, nonatomic) AVPlayerItem *playerItem;
@property (assign, nonatomic) CGFloat assetDuration;
@property (strong, nonatomic) AVURLAsset *urlAsset;
@property (strong, nonatomic) AVPlayerItemVideoOutput *videoOutput;

@end

@implementation SPHVideoPlayer

#pragma mark - LifeCycle

- (instancetype)initVideoPlayerWithURL:(NSURL *)urlAsset
{
    if (self = [super init]) {
        [self initialSetupWithURL:urlAsset];
    }
    return self;
}

#pragma mark - Public

- (void)play
{
    if ((self.assetPlayer.currentItem != nil) && ([self.assetPlayer.currentItem status] == AVPlayerItemStatusReadyToPlay)) {
        [self.assetPlayer play];
    }
}

- (void)pause
{
    [self.assetPlayer pause];
}

- (void)seekPositionAtProgress:(CGFloat)progressValue
{
    [self.assetPlayer seekToTime:CMTimeMakeWithSeconds(self.assetDuration * progressValue, NSEC_PER_SEC)];
    [self.assetPlayer play];
}

- (void)setPlayerVolume:(CGFloat)volume
{
    self.assetPlayer.volume = volume > .0 ? volume : 0.0f;
    [self.assetPlayer play];
}

- (void)setPlayerRate:(CGFloat)rate
{
    self.assetPlayer.rate = rate > .0 ? rate : 0.0f;
}

- (void)stop
{
    self.assetPlayer.rate = .0f;
}

- (BOOL)isPlayerPlayVideo
{
    return self.assetPlayer.rate > 0 ? YES : NO;
}

#pragma mark - Private

- (void)initialSetupWithURL:(NSURL *)url
{
    NSDictionary *assetOptions = @{ AVURLAssetPreferPreciseDurationAndTimingKey : @YES };
    self.urlAsset = [AVURLAsset URLAssetWithURL:url options:assetOptions];
}

- (void)prepareToPlay
{
    NSArray *keys = @[@"tracks"];
    [self.urlAsset loadValuesAsynchronouslyForKeys:keys completionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self startLoading];
        });
    }];
}

- (void)startLoading
{
    NSError *error;
    AVKeyValueStatus status = [self.urlAsset statusOfValueForKey:@"tracks" error:&error];
    if (status == AVKeyValueStatusLoaded) {
        
        self.assetDuration = CMTimeGetSeconds(self.urlAsset.duration);
        NSDictionary *videoOutputOptions = [NSDictionary dictionaryWithObjectsAndKeys:
                                   [NSNumber numberWithInt:kCVPixelFormatType_32BGRA], kCVPixelBufferPixelFormatTypeKey,
                                   [NSDictionary dictionary], kCVPixelBufferIOSurfacePropertiesKey,
                                   nil];
        self.videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:videoOutputOptions];
        
        self.playerItem = [AVPlayerItem playerItemWithAsset: self.urlAsset];
        [self.playerItem addObserver:self
                          forKeyPath:@"status"
                             options:NSKeyValueObservingOptionInitial
                             context:&ItemStatusContext];
        [self.playerItem addObserver:self
                          forKeyPath:@"loadedTimeRanges"
                             options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld
                             context:&ItemStatusContext];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playerItemDidReachEnd:)
                                                     name:AVPlayerItemDidPlayToEndTimeNotification
                                                   object:self.playerItem];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didFailedToPlayToEnd)
                                                     name:AVPlayerItemFailedToPlayToEndTimeNotification
                                                   object:nil];
        [self.playerItem addOutput:self.videoOutput];
        
        self.assetPlayer = [AVPlayer playerWithPlayerItem:self.playerItem];
        [self addPeriodicalObserver];
        
        NSLog(@"Player created");
        
    } else {
        NSLog(@"The asset's tracks were not loaded:\n%@", error.localizedDescription);
    }
}

#pragma mark - Observation

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    BOOL isOldKey = [change[NSKeyValueChangeNewKey] isEqual:change[NSKeyValueChangeOldKey]];
    
    if (!isOldKey) {
        if (context == &ItemStatusContext) {
            if ([keyPath isEqualToString:@"status"]) {
                NSLog(@"Status updated");
                [self moviePlayerDidChangeStatus:self.assetPlayer.status];
            } else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
                 NSLog(@"Loaded range changed");
                [self moviewPlayerLoadedTimeRangeDidUpdated:self.playerItem.loadedTimeRanges];
            }
            return;
        }
    }
}

- (void)moviePlayerDidChangeStatus:(AVPlayerStatus)status
{
    if (status == AVPlayerStatusFailed) {
        NSLog(@"Failed to load video");
    } else if (status == AVPlayerItemStatusReadyToPlay) {
        NSLog(@"Player ready to play");
        self.volume = self.assetPlayer.volume;
        [self.delegate isReadyToPlayVideo];
    } else {
        return;
    }
}

- (void)moviewPlayerLoadedTimeRangeDidUpdated:(NSArray *)ranges
{
    NSTimeInterval max = 0;
    BOOL loadedRangesContainsCurrentTime = NO;
    
    CMTime time = self.playerItem.currentTime;
    
    for (NSValue *value in ranges) {
        CMTimeRange range;
        [value getValue:&range];
        if (CMTimeRangeContainsTime(range, time)) {
            loadedRangesContainsCurrentTime = YES;
        }        
        NSTimeInterval currentMax = CMTimeGetSeconds(range.start) + CMTimeGetSeconds(range.duration);
        if (currentMax > max) {
            max = currentMax;
        }
    }
    CGFloat progress = (self.assetDuration == 0) ? 0 : max / self.assetDuration;
    
    [self.delegate progressUpdateToTime:progress];
}

- (void)playerItemDidReachEnd:(NSNotification *)notification
{
    [self.assetPlayer seekToTime:kCMTimeZero];
    [self.assetPlayer play];
}

- (void)didFailedToPlayToEnd
{
    NSLog(@"Failed play video to the end");
}

- (void)addPeriodicalObserver
{
    CMTime interval = CMTimeMake(1, 1);
    __weak typeof(self) weakSelf = self;
    [self.assetPlayer addPeriodicTimeObserverForInterval:interval queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        [weakSelf playerTimeDidChange:time];
    }];
}

- (void)playerTimeDidChange:(CMTime)time
{
    double timeNow = CMTimeGetSeconds(self.assetPlayer.currentTime);
    [self.delegate progressUpdateToTime:(CGFloat) (timeNow / self.assetDuration)];
}

#pragma mark - Notification

- (void)setupAppNotification
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)didEnterBackground
{
    self.assetPlayer.rate = 0.0f;
}

- (void)willEnterForeground
{
    self.assetPlayer.rate = 1.0f;
}

#pragma mark - GetImagesFromVideoPlayer

- (BOOL)canProvideFrame
{
    return self.assetPlayer.status == AVPlayerItemStatusReadyToPlay;
}

- (UIImage *)getCurrentFramePicture
{
    /* uncomment for log progress review
    CMTime outputItemTime = self.playerItem.currentTime;
    CMTime assetDuration = self.playerItem.duration;
    NSLog(@"Video : %f/%f - speed : %f", (float)outputItemTime.value / (float)outputItemTime.timescale, (float)assetDuration.value / (float)assetDuration.timescale, self.assetPlayer.rate);
     */

    CMTime currentTime = [self.videoOutput itemTimeForHostTime:CACurrentMediaTime()];
    if (![self.videoOutput hasNewPixelBufferForItemTime:currentTime]) {
        return nil;
    }
    CVPixelBufferRef buffer = [self.videoOutput copyPixelBufferForItemTime:currentTime itemTimeForDisplay:NULL];
    
    UIImage *image;
    if (buffer) {
          image = [SPHTextureProvider imageWithCVPixelBufferUsingUIGraphicsContext:buffer];
    }
    return image;
}

#pragma mark - CleanUp

- (void)removeObserversFromPlayer
{
    @try {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        [[NSNotificationCenter defaultCenter] removeObserver:self.assetPlayer];
    }
    @catch (NSException *ex) {
        NSLog(@"Cant remove observer in Player - %@", ex.description);
    }
}

- (void)dealloc
{
    [self removeObserversFromPlayer];
}

@end
