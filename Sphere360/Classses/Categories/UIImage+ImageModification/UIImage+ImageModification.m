//
//  UIImage+ImageModification.m
//  Sphere360
//
//  Created by Kirill on 12/1/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

#import "UIImage+ImageModification.h"

@implementation UIImage (ImageModification)

+ (UIImage *)flipImage180:(UIImage *)image
{
    UIImage *sourceImage = [image copy];
    if (!sourceImage) {
        return nil;
    }
    UIGraphicsBeginImageContext(image.size);
    CGContextDrawImage(UIGraphicsGetCurrentContext(),CGRectMake(0.,0., image.size.width, image.size.height),image.CGImage);
    UIImage *imageMod = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return imageMod;
}

+ (UIImage *)horizontalFlip:(UIImage *)image
{
    UIImage *sourceImage = [image copy];
    if (!sourceImage) {
        return nil;
    }
    UIGraphicsBeginImageContext(image.size);
    if (!image.size.height && !image.size.width) {
        return nil;
    }
    CGContextRef currentContext = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(currentContext, image.size.width, 0);
    CGContextScaleCTM(currentContext, -1.0, 1.0);
    [image drawInRect:CGRectMake(0, 0, image.size.width, image.size.height)];
    UIImage *flippedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    CGContextRelease(currentContext);
    
    return flippedImage;
}

+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize
{
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return newImage;
}

+ (UIImage *)imageWithColor:(UIColor *)color
{
    CGRect rect = CGRectMake(0.0f, 0.0f, 1.0f, 1.0f);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

+ (UIImage *)getImageFromSourceStringURL:(NSString *)sourceURL
{
    UIImage *sourceImage = [UIImage imageWithContentsOfFile:sourceURL];
    if (!sourceImage) {
        NSData *imageData = [NSData dataWithContentsOfURL: [NSURL URLWithString:sourceURL]];
        sourceImage = [UIImage imageWithData:imageData];
    }
    return sourceImage;
}


@end
