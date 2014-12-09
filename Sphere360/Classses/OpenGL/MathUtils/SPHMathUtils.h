//
//  SPHMathUtils.h
//  Sphere360
//
//  Created by Kirill on 12/9/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

@interface SPHMathUtils : NSObject

CATransform3D CATransform3DMakePerspective(CGFloat fovY, CGFloat aspectRatio, CGFloat near, CGFloat far);

+ (GLKMatrix4)GLKMatrixFromCATransform3D:(CATransform3D)transform;

@end
