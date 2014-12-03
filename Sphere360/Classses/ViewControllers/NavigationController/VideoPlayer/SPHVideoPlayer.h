//
//  SPHVideoPlayer.h
//  Sphere360
//
//  Created by Kirill on 12/2/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//
#import <AVFoundation/AVFoundation.h>

@protocol SPHVideoPlayerDelegate

@required
- (void)progressUpdateToTime:(CGFloat)progress;
- (void)progressChangedToTime:(CMTime)time;

@end

@interface SPHVideoPlayer : NSObject

@property (weak, nonatomic) id <SPHVideoPlayerDelegate> delegate;

- (instancetype)initVideoPlayerWithURL:(NSURL *)urlAsset;
- (void)prepareToPlay;

- (void)play;
- (void)pause;
- (void)seekPositionAtProgress:(CGFloat)progressValue;
- (void)setPlayerVolume:(CGFloat)volume;
- (void)stop;

- (BOOL)canProvideFrame;
- (UIImage *)getCurrentFramePicture;

@end
