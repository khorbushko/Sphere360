//
//  SPHTextureProvider.m
//  Sphere360
//
//  Created by Kirill on 12/1/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

#import "SPHTextureProvider.h"
#import <CoreImage/CoreImage.h>

@implementation SPHTextureProvider

+ (CGImageRef)imageWithCVPixelBufferUsingUIGraphicsContext:(CVPixelBufferRef)pixelBuffer
{
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    int width = (int)CVPixelBufferGetWidth(pixelBuffer);
    int hight = (int)CVPixelBufferGetHeight(pixelBuffer);
    int rows = (int)CVPixelBufferGetBytesPerRow(pixelBuffer);
    int bytesPerPixel = rows/width;
    
    unsigned char *bufferPointer = CVPixelBufferGetBaseAddress(pixelBuffer);
    UIGraphicsBeginImageContext(CGSizeMake(width, hight));
    
    CGContextRef context = UIGraphicsGetCurrentContext();

    unsigned char* data = CGBitmapContextGetData(context);
    if (data) {
        int maxY = hight;
        for(int y = 0; y < maxY; y++) {
            for(int x = 0; x < width; x++) {
                int offset = bytesPerPixel*((width*y)+x);
                data[offset] = bufferPointer[offset];     // R
                data[offset+1] = bufferPointer[offset+1]; // G
                data[offset+2] = bufferPointer[offset+2]; // B
                data[offset+3] = bufferPointer[offset+3]; // A
            }
        }
    }
    CGImageRef cgImage = CGBitmapContextCreateImage(context);
    UIGraphicsEndImageContext();

    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    CVBufferRelease(pixelBuffer);
//    CFRelease(pixelBuffer);
    
    return cgImage;
}

@end
