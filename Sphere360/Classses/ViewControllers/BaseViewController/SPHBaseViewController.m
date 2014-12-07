//
//  SPHBaseViewController.m
//  Sphere360
//
//  Created by Kirill on 12/5/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//
#import "Sphere.h"
#import "SPHBaseViewController.h"
#import "SPHGLProgram.h"
#import <AVFoundation/AVFoundation.h>
#import "SPHTextureProvider.h"
#import <CoreMedia/CoreMedia.h>

static CGFloat const kDefStartY = -1.8f;
static CGFloat const kDefStartX = -3.f;

static CGFloat const kMinimumZoomValue = 0.8f;
static CGFloat const kMaximumZoomValue = 1.7f;
static CGFloat const kDefaultZoomDegree = 90.0f;

static CGFloat const kVelocityCoef = 0.01f;

enum {
    UNIFORM_MVPMATRIX,
    UNIFORM_SAMPLER,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

@interface SPHBaseViewController ()<AVAssetResourceLoaderDelegate, UIGestureRecognizerDelegate> {
    GLuint _vertexArrayID;
    GLuint _vertexBufferID;
    GLuint _vertexTexCoordID;
    GLuint _vertexTexCoordAttributeIndex;
    GLKMatrix4 _modelViewProjectionMatrix;
    
    float _rotationX;
    float _rotationY;
    
    GLKMatrix4 rotationMatrixFromGyro;
}

@property (strong, nonatomic) SPHGLProgram *program;
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKTextureInfo *texture;

@property (assign, nonatomic) CGFloat zoomValue;
@property (assign, nonatomic) CGPoint velocityValue;
@property (assign, nonatomic) CGPoint prevTouchPoint;

@property (strong, nonatomic) CMMotionManager *motionManager;
@property (assign, nonatomic) BOOL isGyroModeActive;

@end

@implementation SPHBaseViewController

#pragma mark - LifeCycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setInitialParameters];
    
    [self setupContext];
    [self setupGL];
    
    [self addPinchGesture];
    [self addTapGesture];
    [self addPanGesture];
    [self setupGyroscope];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self tearDownGL];
}

#pragma mark - OpenGL Setup

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
    [self buildProgram];
    
    glGenVertexArraysOES(1, &_vertexArrayID);
    glBindVertexArrayOES(_vertexArrayID);
    
    glGenBuffers(1, &_vertexBufferID);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBufferID);
    glBufferData(GL_ARRAY_BUFFER, sizeof(SphereVerts), SphereVerts, GL_STATIC_DRAW);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, sizeof(float) * 3, NULL);
    
    glGenBuffers(1, &_vertexTexCoordID);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexTexCoordID);
    glBufferData(GL_ARRAY_BUFFER, sizeof(SphereTexCoords), SphereTexCoords, GL_STATIC_DRAW);
    glEnableVertexAttribArray(_vertexTexCoordAttributeIndex);
    glVertexAttribPointer(_vertexTexCoordAttributeIndex, 2, GL_FLOAT, GL_FALSE, sizeof(float) * 2, NULL);
}

#pragma mark - Textures

- (void)applyImageTexture
{
    UIImage *sourceImage = [UIImage imageWithContentsOfFile:self.sourceURL];
    if (!sourceImage) {
        NSData *imageData = [NSData dataWithContentsOfURL: [NSURL URLWithString:self.sourceURL]];
        sourceImage = [UIImage imageWithData:imageData];
    }
    UIImage* flippedImage = [UIImage flipAndMirrorImageHorizontally:sourceImage];
    [self setupTextureWithImage:flippedImage];
}

- (void)setupTextureWithImage:(UIImage *)image
{
    if (!image) {
        return;
    }
    UIImage *textureImage = [image copy];
    GLKTextureLoader *textureloader = [[GLKTextureLoader alloc] initWithSharegroup:self.context.sharegroup];
    [textureloader textureWithCGImage:textureImage.CGImage options:nil queue:nil completionHandler:^(GLKTextureInfo *textureInfo, NSError *outError) {
        if (_texture.name) {
            GLuint textureName = _texture.name;
            glDeleteTextures(1, &textureName);
        }
        [EAGLContext setCurrentContext:self.context];
        _texture = textureInfo;
        if (outError){
            NSLog(@"GL Error = %u", glGetError());
        }
    }];
}

#pragma mark - Draw & update methods

- (void)update
{
    if (!CGPointEqualToPoint(self.velocityValue, CGPointZero)) {
        [self updateMovement];
    }
    
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(kDefaultZoomDegree / self.zoomValue), aspect, 0.1f, 60.0f);
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
    
    if (self.isGyroModeActive) {
        modelViewMatrix = rotationMatrixFromGyro;
    } else {
        modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, _rotationX, 1.0f, 0.0f, 0.0f);
        modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, _rotationY, 0.0f,  1.0f, 0.0f);
    }
    
    _modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    [_program use];
    [self drawArrayOfData];
}

- (void)drawArrayOfData
{
    glBindVertexArrayOES(_vertexArrayID);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glUniformMatrix4fv(uniforms[UNIFORM_MVPMATRIX], 1, 0, _modelViewProjectionMatrix.m);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(_texture.target, _texture.name);
    glEnable(_texture.target);
    glDrawArrays(GL_TRIANGLES, 0, SphereNumVerts);
}

#pragma mark - OpenGL Program

- (void)buildProgram
{
    _program = [[SPHGLProgram alloc] initWithVertexShaderFilename:@"Shader" fragmentShaderFilename:@"Shader"];
    [_program addAttribute:@"a_position"];
    [_program addAttribute:@"a_textureCoord"];
    if (![_program link])
	{
		NSString *programLog = [_program programLog];
		NSLog(@"Program link log: %@", programLog);
		NSString *fragmentLog = [_program fragmentShaderLog];
		NSLog(@"Fragment shader compile log: %@", fragmentLog);
		NSString *vertexLog = [_program vertexShaderLog];
		NSLog(@"Vertex shader compile log: %@", vertexLog);
		_program = nil;
        NSAssert(NO, @"Falied to link Spherical shaders");
	}
    _vertexTexCoordAttributeIndex = [_program attributeIndex:@"a_textureCoord"];
    uniforms[UNIFORM_MVPMATRIX] = [_program uniformIndex:@"u_modelViewProjectionMatrix"];
    uniforms[UNIFORM_SAMPLER] = [_program uniformIndex:@"u_Sampler"];
}

- (void)setupContext
{
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    [EAGLContext setCurrentContext:self.context];
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    self.preferredFramesPerSecond = 24.0;
}

#pragma mark - Gyroscope

- (void)setupGyroscope
{
    self.motionManager = [[CMMotionManager alloc] init];
}

- (void)gyroscopeChoose
{
    [self tapGesture];
    if ([self.motionManager isGyroAvailable]) {
        if (![self.motionManager isGyroActive]) {
            self.isGyroModeActive = YES;
            [self removeAllGesture];
            
            [self.motionManager setGyroUpdateInterval:1.0f / 2.0f];
            [self.motionManager startGyroUpdatesToQueue:[NSOperationQueue mainQueue] withHandler:^(CMGyroData *gyroData, NSError *error) {
                
                //CGFloat xRotation = gyroData.rotationRate.x;
                //CGFloat yRotation = gyroData.rotationRate.y;
                
                CMAttitude *attitude = self.motionManager.deviceMotion.attitude;
                CMRotationMatrix rotationMatrix = attitude.rotationMatrix;
                rotationMatrixFromGyro = [self getRotationMatrixFromGyroscope:rotationMatrix];
            }];
        } else {
            [self.motionManager stopGyroUpdates];
            self.isGyroModeActive = NO;
            
            [self addPinchGesture];
            [self addTapGesture];
            [self addPanGesture];
        }
    } else {
        [self showAlertNoGyroscopeAvaliable];
    }
}

- (GLKMatrix4)getRotationMatrixFromGyroscope:(CMRotationMatrix)gyroRotationMatrix
{
    GLKMatrix4 rotationMatrix;
    
    rotationMatrix.m00 = gyroRotationMatrix.m11;
    rotationMatrix.m01 = gyroRotationMatrix.m12;
    rotationMatrix.m02 = gyroRotationMatrix.m13;
    rotationMatrix.m03 = 0;
    
    rotationMatrix.m10 = gyroRotationMatrix.m21;
    rotationMatrix.m11 = gyroRotationMatrix.m22;
    rotationMatrix.m12 = gyroRotationMatrix.m23;
    rotationMatrix.m13 = 0;
    
    rotationMatrix.m20 = gyroRotationMatrix.m31;
    rotationMatrix.m21 = gyroRotationMatrix.m32;
    rotationMatrix.m22 = gyroRotationMatrix.m33;
    rotationMatrix.m23 = 0;
    
    rotationMatrix.m20 = 0;
    rotationMatrix.m21 = 0;
    rotationMatrix.m22 = 0;
    rotationMatrix.m23 = 1;
    
    return rotationMatrix;
}

#pragma mark - Touches

- (void)moveToPointX:(CGFloat)pointX andPointY:(CGFloat)pointY
{
    pointX *= -0.008;
    pointY *= 0.008;
    _rotationX += -pointY;
    _rotationY += -pointX;
}

#pragma mark - GestureActions

- (void)pinchForZoom:(UIPinchGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan) {
        gesture.scale = self.zoomValue;
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGFloat zoom = gesture.scale;
        zoom = MAX(MIN(zoom, kMaximumZoomValue), kMinimumZoomValue);
        self.zoomValue = zoom;
    }
}

- (void)tapGesture
{
    [self hideShowNavigationBar];
}

- (void)panGesture:(UIPanGestureRecognizer *)panGesture
{
    CGPoint currentPoint = [panGesture locationInView:panGesture.view];
    
    switch (panGesture.state) {
        case UIGestureRecognizerStateEnded: {
            self.velocityValue = [panGesture velocityInView:panGesture.view];
            break;
        }
        case UIGestureRecognizerStateBegan: {
            self.prevTouchPoint = currentPoint;
            [self disableExtraMovement];
            break;
        }
        case UIGestureRecognizerStateChanged: {
            [self moveToPointX:currentPoint.x - self.prevTouchPoint.x andPointY:currentPoint.y - self.prevTouchPoint.y];
            self.prevTouchPoint = currentPoint;
            break;
        }
        default:
            break;
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if ([touch.view isKindOfClass:[GLKView class]]) {
        [self disableExtraMovement];
        return YES;
    } else {
        return NO;
    }
}

#pragma mark - Velocity

- (void)updateMovement
{
    self.velocityValue = CGPointMake(0.9 * self.velocityValue.x, 0.9 * self.velocityValue.y);
    CGPoint nextPoint = CGPointMake(kVelocityCoef * self.velocityValue.x, kVelocityCoef * self.velocityValue.y);
    
    if (fabsf(nextPoint.x) < 0.1 && fabsf(nextPoint.y) < 0.1) {
        self.velocityValue = CGPointZero;
    }
    
    [self moveToPointX:nextPoint.x andPointY:nextPoint.y];
}

- (void)disableExtraMovement
{
    self.velocityValue = CGPointZero;
}

#pragma mark - UIConfiguration

- (void)showAlertNoGyroscopeAvaliable
{
    [[[UIAlertView alloc] initWithTitle:@"Panaroma" message:@"No gyroscope avaliable on your device" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
}

- (void)removeAllGesture
{
    for (UIGestureRecognizer *recognizer in self.view.gestureRecognizers) {
        [self.view removeGestureRecognizer:recognizer];
    }
}

#pragma mark - Animation

- (void)hideBottomBarView:(UIView *)bottomView
{
    CGPoint toValue = bottomView.center;
    CGPoint fromValue = bottomView.center;
    CABasicAnimation *animation;
    if (self.navigationController.navigationBarHidden) {
        toValue.y += bottomView.bounds.size.height;
        animation = [SPHAnimationProvider animationForMovingViewFromValue:[NSValue valueWithCGPoint:fromValue] toValue:[NSValue valueWithCGPoint:toValue]  withDuration:0.3];
    } else {
        animation = [SPHAnimationProvider animationForMovingViewFromValue:[NSValue valueWithCGPoint:fromValue] toValue:[NSValue valueWithCGPoint:toValue]  withDuration:0.9];
    }
    [bottomView.layer addAnimation:animation forKey:nil];
    bottomView.layer.position = toValue;
}

#pragma mark - Private

- (void)setEmptyImage
{
    [self setupTextureWithImage:[[UIImage alloc] init]];
}

- (void)hideShowNavigationBar
{
    [self.navigationController setNavigationBarHidden:!self.navigationController.navigationBarHidden animated:YES];
}

- (void)addPinchGesture
{
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchForZoom:)];
    pinch.delegate = self;
    [self.view addGestureRecognizer:pinch];
}

- (void)addTapGesture
{
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGesture)];
    tapGesture.delegate = self;
    [self.view addGestureRecognizer:tapGesture];
}

- (void)addPanGesture
{
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panGesture:)];
    panGesture.delegate = self;
    panGesture.maximumNumberOfTouches = 1;
    [self.view addGestureRecognizer:panGesture];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if ([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]] && [otherGestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        return YES;
    }
    return NO;
}

- (void)setInitialParameters
{
    _rotationX = kDefStartX;
    _rotationY = kDefStartY;
    self.zoomValue = 1.0f;
}

#pragma mark - Cleanup

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    glDeleteBuffers(1, &_vertexBufferID);
    glDeleteVertexArraysOES(1, &_vertexArrayID);
    glDeleteBuffers(1, &_vertexTexCoordID);
    _program = nil;
    if (_texture.name) {
        GLuint textureName = _texture.name;
        glDeleteTextures(1, &textureName);
    }
    _texture = nil;
}

- (void)dealloc
{
    [self tearDownGL];
}

@end
