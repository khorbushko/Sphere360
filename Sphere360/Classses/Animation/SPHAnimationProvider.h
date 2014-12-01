//
//  SPHAnimationProvider.h
//  Sphere360
//
//  Created by Kirill on 12/1/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SPHAnimationProvider : NSObject

+ (CABasicAnimation *)animationChangeOpacityFromValue:(NSInteger)startValue toValue:(NSInteger)toValue withDuration:(CGFloat)duration;
+ (CABasicAnimation *)animationForMovingViewFromValue:(NSValue *)fromValue toValue:(NSValue *)toValue withDuration:(CGFloat)duration;

@end
