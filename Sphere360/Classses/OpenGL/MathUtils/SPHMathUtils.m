//
//  SPHMathUtils.m
//  Sphere360
//
//  Created by Kirill on 12/9/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

#import "SPHMathUtils.h"

static CGFloat const MUTolerance = 0.00001;

@implementation SPHMathUtils

#pragma mark - MatrixOperation

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

#pragma mark - Quaternions

+ (CMQuaternion)normalizeQuaternion:(CMQuaternion)inputQuaternion
{
    float mag2 = inputQuaternion.w * inputQuaternion.w + inputQuaternion.x * inputQuaternion.x + inputQuaternion.y * inputQuaternion.y + inputQuaternion.z * inputQuaternion.z;
    if (fabs(mag2) > MUTolerance && fabs(mag2 - 1.0f) > MUTolerance) {
        float mag = sqrt(mag2);
        inputQuaternion.w /= mag;
		inputQuaternion.x /= mag;
		inputQuaternion.y /= mag;
		inputQuaternion.z /= mag;
    }
    return inputQuaternion;
}

+ (GLKMatrix4)getMatrixGLK4FromQuaternion:(CMQuaternion)quaternion
{
    float x2 = quaternion.x * quaternion.x;
	float y2 = quaternion.y * quaternion.y;
	float z2 = quaternion.z * quaternion.z;
	float xy = quaternion.x * quaternion.y;
	float xz = quaternion.x * quaternion.z;
	float yz = quaternion.y * quaternion.z;
	float wx = quaternion.w * quaternion.x;
	float wy = quaternion.w * quaternion.y;
	float wz = quaternion.w * quaternion.z;
    
    GLKMatrix4 matrix = GLKMatrix4Identity;
    
    matrix.m00 = 1.0f - 2.0f * (y2 + z2); matrix.m01 = 2.0f * (xy - wz); matrix.m02 = 2.0f * (xz + wy);
    matrix.m10 = 2.0f * (xy + wz); matrix.m11 = 1.0f - 2.0f * (x2 + z2); matrix.m12 = 2.0f * (yz - wx);
    matrix.m20 = 2.0f * (xz - wy); matrix.m21 = 2.0f * (yz + wx); matrix.m22 = 1.0f - 2.0f * (x2 + y2);

    return matrix;
}

@end
