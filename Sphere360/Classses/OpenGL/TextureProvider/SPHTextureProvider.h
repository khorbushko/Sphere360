//
//  SPHTextureProvider.h
//  Sphere360
//
//  Created by Kirill on 12/1/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

@interface SPHTextureProvider : NSObject

+ (GLuint)getPoinerToTextureFrom:(UIImage *)image;
+ (UIImage *)imageWithCVImageBuffer:(CVImageBufferRef)imageBuffer;
+ (UIImage *)imageWithCVPixelBuffer:(CVPixelBufferRef)pixelBuffer;
+ (UIImage *)imageWithCVPixelBufferUsingUIGraphicsContext:(CVPixelBufferRef)pixelBuffer;

@end
