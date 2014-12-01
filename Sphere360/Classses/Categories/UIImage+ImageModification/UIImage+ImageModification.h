//
//  UIImage+ImageModification.h
//  Sphere360
//
//  Created by Kirill on 12/1/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

@interface UIImage (ImageModification)

+ (UIImage *)flipAndMirrorImageHorizontally:(UIImage *)image;
+ (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize;
+ (UIImage *)imageWithColor:(UIColor *)color;

@end
