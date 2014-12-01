//
//  SPHAnimationProvider.m
//  Sphere360
//
//  Created by Kirill on 12/1/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

#import "SPHAnimationProvider.h"

@implementation SPHAnimationProvider

#pragma mark - Public

+ (CABasicAnimation *)animationChangeOpacityFromValue:(NSInteger)startValue toValue:(NSInteger)toValue withDuration:(CGFloat)duration
{
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
    animation.fromValue = @(startValue);
    animation.toValue = @(toValue);
    animation.duration = duration;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    animation.removedOnCompletion = YES;
    return animation;
}

+ (CABasicAnimation *)animationForMovingViewFromValue:(NSValue *)fromValue toValue:(NSValue *)toValue withDuration:(CGFloat)duration
{
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:@"position"];
    animation.fromValue = fromValue;
    animation.toValue = toValue;
    animation.duration = duration;
    animation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    animation.removedOnCompletion = YES;
    return animation;
}

@end
