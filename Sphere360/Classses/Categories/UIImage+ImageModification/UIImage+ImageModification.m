//
//  UIImage+ImageModification.m
//  Sphere360
//
//  Created by Kirill on 12/1/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

#import "UIImage+ImageModification.h"

@implementation UIImage (ImageModification)

//flip by 180 degree and horizontal
+ (UIImage *)flipAndMirrorImageHorizontally:(UIImage *)image
{
    UIGraphicsBeginImageContext(image.size);
    CGContextDrawImage(UIGraphicsGetCurrentContext(),CGRectMake(0.,0., image.size.width, image.size.height),image.CGImage);
    CGAffineTransform verticalFlip = CGAffineTransformMake(1, 0, 0, -1, 0, image.size.height);
    CGContextConcatCTM(UIGraphicsGetCurrentContext(), verticalFlip);
    
    UIImage *imageMod = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return imageMod;
}

@end
