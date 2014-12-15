//
//  SPHBaseViewController.h
//  Sphere360
//
//  Created by Kirill on 12/5/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

#import "SPHVideoPlayer.h"

typedef NS_ENUM(NSInteger, MediaType) {
    MediaTypePhoto,
    MediaTypeVideo,
    MediaTypeLive
};

@interface SPHBaseViewController : GLKViewController

@property (strong, nonatomic) NSString *sourceURL;
@property (strong, nonatomic) UIImage *sourceImage;
@property (assign, nonatomic) MediaType mediaType;

- (void)setupTextureWithImage:(CGImageRef)image;

- (void)gyroscopeChoose;
- (void)turnPlanetMode; //normal by default
- (void)tapGesture;
- (void)update;
- (void)applyImageTexture;
- (void)drawArraysGL;

@end
