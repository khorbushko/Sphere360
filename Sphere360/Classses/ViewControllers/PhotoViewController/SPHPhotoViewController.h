//
//  SPHPhotoViewController.h
//  Sphere360
//
//  Created by Kirill on 12/1/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//
@protocol SHPVideoProtocolDelegate

@required
- (BOOL)readyToProvideFrame;
- (void)getPicureFromVideoInCurrentMoment;

@end

@interface SPHPhotoViewController : GLKViewController

@end
