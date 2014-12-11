//
//  SPHMathUtils.m
//  Sphere360
//
//  Created by Kirill on 12/9/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

#import "SPHMathUtils.h"

@implementation SPHMathUtils

CATransform3D CATransform3DMakePerspective(CGFloat fovY, CGFloat aspectRatio, CGFloat near, CGFloat far)
{
    float scaleY = 1 / tan(fovY * 0.5);
    
    CATransform3D transform3D;
    memset(&transform3D, 0, sizeof(transform3D));
    
    float distance = near - far;
    
    transform3D.m11 = scaleY / aspectRatio;
    transform3D.m22 = scaleY;
    transform3D.m33 = (far + near) / distance;
    transform3D.m43 = 2 * far * near / distance;
    transform3D.m34 = -1;
    
    return transform3D;
}

+ (GLKMatrix4)GLKMatrixFromCATransform3D:(CATransform3D)transform
{
    GLKMatrix4 rotationMatrix;

    CGFloat *srcPointer = (CGFloat *)&transform;
    float *dstPointer = (float *)&rotationMatrix;
    for (int i = 0; i < 16; i++) {
        dstPointer[i] = srcPointer[i];
    }
    
    return rotationMatrix;
}

+ (CATransform3D)CATransform3DMatrixFromCMRotationMatrix:(CMRotationMatrix)transform
{
    CATransform3D rotationMatrix = CATransform3DIdentity;
    
    rotationMatrix.m11 = transform.m11;
    rotationMatrix.m12 = transform.m12;
    rotationMatrix.m13 = transform.m13;
    
    rotationMatrix.m21 = transform.m21;
    rotationMatrix.m22 = transform.m22;
    rotationMatrix.m23 = transform.m23;
    
    rotationMatrix.m31 = transform.m31;
    rotationMatrix.m32 = transform.m32;
    rotationMatrix.m33 = transform.m33;
    
    return rotationMatrix;
}

@end
