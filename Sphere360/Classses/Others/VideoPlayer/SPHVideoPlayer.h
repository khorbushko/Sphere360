//
//  SPHVideoPlayer.h
//  Sphere360
//
//  Created by Kirill on 12/2/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//
#import <AVFoundation/AVFoundation.h>

@protocol SPHVideoPlayerDelegate

@optional
- (void)progressUpdateToTime:(CGFloat)progress;
- (void)downloadingProgress:(CGFloat)progress;
- (void)progressChangedToTime:(CMTime)time;
- (void)isReadyToPlayVideo;

@end

@interface SPHVideoPlayer : NSObject

@property (weak, nonatomic) id <SPHVideoPlayerDelegate> delegate;
@property (assign, nonatomic) CGFloat volume;

- (instancetype)initVideoPlayerWithURL:(NSURL *)urlAsset;
- (void)prepareToPlay;

- (void)play;
- (void)pause;
- (void)stop;
- (void)seekPositionAtProgress:(CGFloat)progressValue withPlayingStatus:(BOOL)isPlaying;
- (void)setPlayerVolume:(CGFloat)volume;
- (void)setPlayerRate:(CGFloat)rate;
- (BOOL)isPlayerPlayVideo;

- (BOOL)canProvideFrame;
- (UIImage *)getCurrentFramePicture;

- (void)removeObserversFromPlayer;

@end
