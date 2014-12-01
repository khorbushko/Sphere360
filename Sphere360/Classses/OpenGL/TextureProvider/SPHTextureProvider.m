//
//  SPHTextureProvider.m
//  Sphere360
//
//  Created by Kirill on 12/1/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

#import "SPHTextureProvider.h"
#import <AVFoundation/AVFoundation.h>

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
    
    // Sets the CoreGraphic Image to work on it.
    cgImage = [image CGImage];
    
    // Sets the image's size.
    _width = CGImageGetWidth(cgImage);
    _height = CGImageGetHeight(cgImage);
    
    // Extracts the pixel informations and place it into the data.
    colorSpace = CGColorSpaceCreateDeviceRGB();
    _data = malloc(_width * _height * 4);
    context = CGBitmapContextCreate(_data, _width, _height, 8, 4 * _width, colorSpace,
                                    kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    
    // Adjusts position and invert the image.
    // The OpenGL uses the image data upside-down compared commom image files.
    CGContextTranslateCTM(context, 0, _height);
    CGContextScaleCTM(context, 1.0, -1.0);
    
    // Clears and ReDraw the image into the context.
    CGContextClearRect(context, CGRectMake(0, 0, _width, _height));
    CGContextDrawImage(context, CGRectMake(0, 0, _width, _height), cgImage);
    
    // Releases the context.
    CGContextRelease(context);
    
    GLuint texturePointer = newTexture(_width, _height, _data);
    
    return texturePointer;
}

+ (UIImage *)imageWithCVImageBuffer:(CVImageBufferRef)imageBuffer
{
    /*Lock the image buffer*/
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    /*Get information about the image*/
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    /*We unlock the  image buffer*/
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    /*Create a CGImageRef from the CVImageBufferRef*/
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef newContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    CGImageRef newImage = CGBitmapContextCreateImage(newContext);
    
    /*We release some components*/
    CGContextRelease(newContext);
    CGColorSpaceRelease(colorSpace);
    
    /*We display the result on the image view (We need to change the orientation of the image so that the video is displayed correctly)*/
    UIImage *image= [UIImage imageWithCGImage:newImage scale:1.0 orientation:UIImageOrientationRight];
    /*We relase the CGImageRef*/
    CGImageRelease(newImage);
    return image;
}

#pragma mark - Video Operations

#pragma mark - Private

GLuint newTexture(GLsizei width, GLsizei height, const GLvoid *data)
{
	GLuint newTexture;
	
	// Generates a new texture name/id.
	glGenTextures(1, &newTexture);
	
	// Binds the new name/id to really create the texture and hold it to set its properties.
	glBindTexture(GL_TEXTURE_2D, newTexture);
	
	// Uploads the pixel data to the bound texture.
	glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
	
	// Defines the Minification and Magnification filters to the bound texture.
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	
	// Generates a full MipMap chain to the current bound texture.
	glGenerateMipmap(GL_TEXTURE_2D);
	
	return newTexture;
}

@end
