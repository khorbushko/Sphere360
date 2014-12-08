//
//  SPHTextureProvider.m
//  Sphere360
//
//  Created by Kirill on 12/1/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

#import "SPHTextureProvider.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>

@implementation SPHTextureProvider

#pragma mark - Public

#pragma mark - Image Operations

+ (GLuint)getPoinerToTextureFrom:(UIImage *)image
{
    int	_width;
	int	 _height;
	void *_data;
    
    CGImageRef cgImage;
    CGContextRef context;
    CGColorSpaceRef	colorSpace;
    
    cgImage = [image CGImage];
    
    _width = (int)CGImageGetWidth(cgImage);
    _height = (int)CGImageGetHeight(cgImage);
    
    colorSpace = CGColorSpaceCreateDeviceRGB();
    _data = malloc(_width * _height * 4);
    context = CGBitmapContextCreate(_data, _width, _height, 8, 4 * _width, colorSpace,
                                    kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    CGContextTranslateCTM(context, 0, _height);
    CGContextScaleCTM(context, 1.0, -1.0);
    
    CGContextClearRect(context, CGRectMake(0, 0, _width, _height));
    CGContextDrawImage(context, CGRectMake(0, 0, _width, _height), cgImage);
    
    CGContextRelease(context);
    
    GLuint texturePointer = newTexture(_width, _height, _data);
    
    return texturePointer;
}

+ (UIImage *)imageWithCVImageBuffer:(CVImageBufferRef)imageBuffer
{
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef newImage = CGBitmapContextCreateImage(newContext);
    
    CGContextRelease(newContext);
    CGColorSpaceRelease(colorSpace);
    
    UIImage *image= [UIImage imageWithCGImage:newImage scale:1.0 orientation:UIImageOrientationRight];
    CGImageRelease(newImage);
    return image;
}

+ (UIImage *)imageWithCVPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    
    CIContext *temporaryContext = [CIContext contextWithOptions:nil];
    CGImageRef videoImage = [temporaryContext
                             createCGImage:ciImage
                             fromRect:CGRectMake(0, 0,
                                                 CVPixelBufferGetWidth(pixelBuffer),
                                                 CVPixelBufferGetHeight(pixelBuffer))];
    
    UIImage *image = [UIImage imageWithCGImage:videoImage];
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    CFRelease(pixelBuffer);
    
    return image;
}

//must Be faster `10 times than "imageWithCVPixelBuffer:(CVPixelBufferRef)pixelBuffer" -> stackoverflow
+ (UIImage *)imageWithCVPixelBufferUsingUIGraphicsContext:(CVPixelBufferRef)pixelBuffer
{
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    int w = (int)CVPixelBufferGetWidth(pixelBuffer);
    int h = (int)CVPixelBufferGetHeight(pixelBuffer);
    int r = (int)CVPixelBufferGetBytesPerRow(pixelBuffer);
    int bytesPerPixel = r/w;
    
    unsigned char *bufferU = CVPixelBufferGetBaseAddress(pixelBuffer);
    UIGraphicsBeginImageContext(CGSizeMake(w, h));
    
    CGContextRef c = UIGraphicsGetCurrentContext();
    
    unsigned char* data = CGBitmapContextGetData(c);
    if (data) {
        int maxY = h;
        for(int y = 0; y < maxY; y++) {
            for(int x = 0; x < w; x++) {
                int offset = bytesPerPixel*((w*y)+x);
                data[offset] = bufferU[offset];     // R
                data[offset+1] = bufferU[offset+1]; // G
                data[offset+2] = bufferU[offset+2]; // B
                data[offset+3] = bufferU[offset+3]; // A
            }
        }
    }
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    CVBufferRelease(pixelBuffer);
    //CFRelease(pixelBuffer); //can cause crash in NULL pixelBuffer
    return image;
}

#pragma mark - Private

#pragma mark - C

GLuint newTexture(GLsizei width, GLsizei height, const GLvoid *data)
{
	GLuint newTexture;
	glGenTextures(1, &newTexture);
	glBindTexture(GL_TEXTURE_2D, newTexture);
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	glGenerateMipmap(GL_TEXTURE_2D);
	
	return newTexture;
}

@end
