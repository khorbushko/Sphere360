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
@property (strong, nonatomic) AVURLAsset *urlAsset;
@property (strong, atomic) AVPlayerItemVideoOutput *videoOutput;

@property (assign, nonatomic) CGFloat assetDuration;

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
    if ((self.assetPlayer.currentItem) && (self.assetPlayer.currentItem.status == AVPlayerItemStatusReadyToPlay)) {
        [self.assetPlayer play];
    }
}

- (void)pause
{
    [self.assetPlayer pause];
}

- (void)seekPositionAtProgress:(CGFloat)progressValue withPlayingStatus:(BOOL)isPlaying
{
    [self.assetPlayer seekToTime:CMTimeMakeWithSeconds(self.assetDuration * progressValue, NSEC_PER_SEC)];
    if (isPlaying) {
        [self.assetPlayer play];
    }
}

- (void)setPlayerVolume:(CGFloat)volume
{
    self.assetPlayer.volume = volume > .0 ? MAX(volume, 0.7) : 0.0f;
    [self.assetPlayer play];
}

- (void)setPlayerRate:(CGFloat)rate
{
    self.assetPlayer.rate = rate > .0 ? rate : 0.0f;
}

- (void)stop
{
    [self.assetPlayer seekToTime:kCMTimeZero];
    self.assetPlayer.rate =.0f;
}

- (BOOL)isPlaying
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
    __weak SPHVideoPlayer *weakSelf = self;
    [weakSelf.urlAsset loadValuesAsynchronouslyForKeys:keys completionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf startLoading];
        });
    }];
}

- (void)startLoading
{
    NSError *error;
    AVKeyValueStatus status = [self.urlAsset statusOfValueForKey:@"tracks" error:&error];
    if (status == AVKeyValueStatusLoaded) {
        self.assetDuration = CMTimeGetSeconds(self.urlAsset.duration);
        NSDictionary* videoOutputOptions = @{ (id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInt:kCVPixelFormatType_32BGRA] };
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
                [self moviePlayerDidChangeStatus:self.assetPlayer.status];
            } else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
                [self moviewPlayerLoadedTimeRangeDidUpdated:self.playerItem.loadedTimeRanges];
            }
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
        [self.delegate isReadyToPlay];
    } else {
        NSLog(@"Player do not tried to load new media resources for playback yet");
    }
}

- (void)moviewPlayerLoadedTimeRangeDidUpdated:(NSArray *)ranges
{
    NSTimeInterval maximum = 0;
    
    for (NSValue *value in ranges) {
        CMTimeRange range;
        [value getValue:&range];
        NSTimeInterval currenLoadedRangeTime = CMTimeGetSeconds(range.start) + CMTimeGetSeconds(range.duration);
        if (currenLoadedRangeTime > maximum) {
            maximum = currenLoadedRangeTime;
        }
    }
    CGFloat progress = (self.assetDuration == 0) ? 0 : maximum / self.assetDuration;
    
    [self.delegate downloadingProgress:progress];
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
    [self.delegate progressDidUpdate:(CGFloat) (timeNow / self.assetDuration)];
}

#pragma mark - Notification

- (void)setupAppNotification
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
}

- (void)didEnterBackground
{
    [self.assetPlayer pause];
}

- (void)willEnterForeground
{
    [self.assetPlayer pause];
}

#pragma mark - GetImagesFromVideoPlayer

- (BOOL)canProvideFrame
{
    return self.assetPlayer.status == AVPlayerItemStatusReadyToPlay;
}

- (CGImageRef)getCurrentFramePicture
{
    /* uncomment for log progress review
    CMTime outputItemTime = self.playerItem.currentTime;
    CMTime assetDuration = self.playerItem.duration;
    NSLog(@"Video : %f/%f - speed : %f", (float)outputItemTime.value / (float)outputItemTime.timescale, (float)assetDuration.value / (float)assetDuration.timescale, self.assetPlayer.rate);
     */

    CMTime currentTime = [self.videoOutput itemTimeForHostTime:CACurrentMediaTime()];
    CGImageRef image;
    [self.delegate progressTimeChanged:currentTime];
    if (![self.videoOutput hasNewPixelBufferForItemTime:currentTime]) {
        return nil;
    }
    CVPixelBufferRef buffer = [self.videoOutput copyPixelBufferForItemTime:currentTime itemTimeForDisplay:NULL];

    if (buffer) {
        image = [SPHTextureProvider imageWithCVPixelBufferUsingUIGraphicsContext:buffer];
    } else {
        return nil;
    }
    [self.delegate progressDidUpdate: CMTimeGetSeconds(currentTime)/self.assetDuration];
    return image;
}

#pragma mark - CleanUp

- (void)removeObserversFromPlayer
{
    @try {
        [self.playerItem removeObserver:self forKeyPath:@"status"];
        [self.playerItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        [[NSNotificationCenter defaultCenter] removeObserver:self.assetPlayer];        
    }
    @catch (NSException *ex) {
        NSLog(@"Cant remove observer in Player - %@", ex.description);
    }
}

- (void)cleanUp
{
    [self removeObserversFromPlayer];
    
    self.assetPlayer.rate = 0;
    self.assetPlayer = nil;
    self.playerItem = nil;
    self.urlAsset = nil;
}

- (void)dealloc
{
    [self cleanUp];    
}

@end
