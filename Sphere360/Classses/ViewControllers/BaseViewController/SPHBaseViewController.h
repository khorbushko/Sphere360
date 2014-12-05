//
//  SPHBaseViewController.h
//  Sphere360
//
//  Created by Kirill on 12/5/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

#import "SPHAnimationProvider.h"
#import "SPHVideoPlayer.h"

typedef enum {
    PhotoViewController,
    VideoViewController,
    LiveViewController,
} MediaType;

@interface SPHBaseViewController : GLKViewController

@property (strong, nonatomic) NSString *sourceURL;
@property (assign, nonatomic) MediaType selectedController;

- (void)setEmptyImage;
- (void)setupTextureWithImage:(UIImage *)image;
- (void)setupUI;
- (void)gyroscopeChoose;
- (void)tapGesture;
- (void)update;
- (void)applyImageTexture;
- (void)hideBottomBarView:(UIView *)bottomView;
- (void)drawArrayOfData;

@end
