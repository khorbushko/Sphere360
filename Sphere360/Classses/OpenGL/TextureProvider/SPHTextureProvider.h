//
//  SPHTextureProvider.h
//  Sphere360
//
//  Created by Kirill on 12/1/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SPHTextureProvider : NSObject

+ (GLuint)getPoinerToTextureFrom:(UIImage *)image;

@end
