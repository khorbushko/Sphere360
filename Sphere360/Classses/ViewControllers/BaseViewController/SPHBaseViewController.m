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

typedef NS_ENUM (NSInteger, PlanetMode) {
    PlanetModeNormal,
    PlanetModeLittlePlanet
};

static CGFloat const kMinimumLittlePlanetZoomValue = 0.7195f;
static CGFloat const kPreMinimumLittlePlanetZoomValue = 0.7475f;
static CGFloat const kMinimumZoomValue = 0.771f;
static CGFloat const kMaximumZoomValue = 1.7f;
static CGFloat const kPreMinimumZoomValue = 0.83f;
static CGFloat const kPreMaximumZoomValue = 1.45f;

static CGFloat const kAdditionalMovementCoef = 0.01f;

enum {
    UNIFORM_MVPMATRIX,
    UNIFORM_SAMPLER,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

@interface SPHBaseViewController () <AVAssetResourceLoaderDelegate, UIGestureRecognizerDelegate> {
    GLuint _vertexArrayID;
    GLuint _vertexBufferID;
    GLuint _vertexTexCoordID;
    GLuint _vertexTexCoordAttributeIndex;
    GLKMatrix4 _modelViewProjectionMatrix;
    GLKMatrix4 _currentProjectionMatrix;
    GLKMatrix4 _cameraProjectionMatrix;
    
    float _rotationX;
    float _rotationY;
    
    GLuint texturePointer;
}

@property (strong, nonatomic) SPHGLProgram *program;
@property (strong, nonatomic) EAGLContext *context;
@property (strong, atomic) GLKTextureInfo *texture;

@property (assign, nonatomic) CGFloat zoomValue;
@property (assign, nonatomic) CGPoint velocityValue;
@property (assign, nonatomic) CGPoint prevTouchPoint;

@property (strong, nonatomic) CMMotionManager *motionManager;
@property (assign, nonatomic) BOOL isGyroModeActive;
@property (assign, nonatomic) BOOL isZooming;

@property (strong, atomic) GLKTextureLoader *textureloader;

@property (assign, nonatomic) PlanetMode planetMode;

@end

@implementation SPHBaseViewController

#pragma mark - LifeCycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setInitialParameters];
    
    [self setupContext];
    [self setupGL];
    
    [self addGestures];
    [self setupGyroscope];
    
    [self setupTextureLoader];
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
    
    glDisable(GL_DEPTH_TEST);
    glDepthMask(GL_FALSE);
    
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
    //dummy
}

- (void)setupTextureWithImage:(CGImageRef)image
{
    if (!image) {
        return;
    }
    NSDictionary *textureOption = @{GLKTextureLoaderOriginBottomLeft : @YES};
    [self.textureloader textureWithCGImage:image options:textureOption queue:NULL completionHandler:^(GLKTextureInfo *textureInfo, NSError *outError) {
        if (outError){
            NSLog(@"GL Error = %u", glGetError());
        } else {
            if (_texture.name) {
                GLuint textureName = _texture.name;
                glDeleteTextures(1, &textureName);
            }
            _texture = textureInfo;
            if (!self.sourceImage) {
                CFRelease(image);
            }
        }
    }];
}

#pragma mark - GLKViewDelegate & GLKVIewControllerDelegte

- (void)update
{
    if (!CGPointEqualToPoint(self.velocityValue, CGPointZero)) {
        [self setAdditionalMovement];
    }
    if (!self.isZooming) {
        [self updateZoomValue];
    }
    
    CGFloat angle = self.planetMode ? 115.0f : 90.0f;
    CGFloat near = self.planetMode ? 0.01f : 0.1f;
    CGFloat FOVY = GLKMathDegreesToRadians(angle) / self.zoomValue;
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    
    CGFloat cameraDistanse = - (self.zoomValue - kMaximumZoomValue);
    GLKMatrix4 cameraTranslation = GLKMatrix4MakeTranslation(0, 0, -cameraDistanse / 2.0);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(FOVY, aspect, near, 2.4);
    projectionMatrix = GLKMatrix4Multiply(projectionMatrix, cameraTranslation);
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;

    if (self.isGyroModeActive) {
        CMQuaternion quat = self.motionManager.deviceMotion.attitude.quaternion;
        GLKQuaternion glQuat = GLKQuaternionMake(-quat.y, -quat.z, -quat.x, quat.w);
        if (self.interfaceOrientation == UIInterfaceOrientationPortrait) {
            projectionMatrix = GLKMatrix4Rotate(projectionMatrix, M_PI / 2, 0, 0, 1);
        }
        modelViewMatrix = GLKMatrix4MakeWithQuaternion(glQuat);
        projectionMatrix = GLKMatrix4Rotate(projectionMatrix, M_PI / 2, 1, 0, 0);
        _modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    } else {
        projectionMatrix = GLKMatrix4Multiply(projectionMatrix, _cameraProjectionMatrix);
        modelViewMatrix = _currentProjectionMatrix;
        _modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    }
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    [_program use];	
    [self drawArraysGL];
}

- (void)drawArraysGL
{
    glBindVertexArrayOES(_vertexArrayID);
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glBlendFunc(GL_ONE, GL_ZERO);
    glUniformMatrix4fv(uniforms[UNIFORM_MVPMATRIX], 1, 0, _modelViewProjectionMatrix.m);
    if (_texture) {
        glBindTexture(GL_TEXTURE_2D, _texture.name);
    }
    glDrawArrays(GL_TRIANGLES, 0, SphereNumVerts);
}

#pragma mark - OpenGL Setup

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
}

- (void)setupTextureLoader
{
    self.textureloader = [[GLKTextureLoader alloc] initWithSharegroup:self.context.sharegroup];
}

#pragma mark - Gyroscope

- (void)setupGyroscope
{
    self.motionManager = [[CMMotionManager alloc] init];
}

- (void)gyroscopeChoose
{
    [self tapGesture];
    if ([self.motionManager isDeviceMotionAvailable]) {
        if (!self.motionManager.isDeviceMotionActive) {
            self.isGyroModeActive = YES;
            self.motionManager.gyroUpdateInterval = 1 / 60;
            [self.motionManager startDeviceMotionUpdatesUsingReferenceFrame:CMAttitudeReferenceFrameXMagneticNorthZVertical];
        } else {
            [self.motionManager stopDeviceMotionUpdates];
            self.isGyroModeActive = NO;
        }
    } else {
        [self showAlertNoGyroscopeAvaliable];
    }
}

#pragma mark - Public

- (void)turnPlanetMode
{
    self.planetMode = self.planetMode ? PlanetModeNormal : PlanetModeLittlePlanet;
}

#pragma mark - Touches

- (void)moveToPointX:(CGFloat)pointX andPointY:(CGFloat)pointY
{
    if (self.isGyroModeActive) {
        return;
    }
    pointX *= 0.004;
    pointY *= 0.004;
    GLKMatrix4 rotatedMatrix = GLKMatrix4MakeRotation(-pointX / self.zoomValue, 0, 1, 0);
    _currentProjectionMatrix = GLKMatrix4Multiply(_currentProjectionMatrix, rotatedMatrix);
    
    GLKMatrix4 cameraMatrix = GLKMatrix4MakeRotation(-pointY / self.zoomValue, 1, 0, 0);
    _cameraProjectionMatrix = GLKMatrix4Multiply(_cameraProjectionMatrix, cameraMatrix);
}

#pragma mark - Zoom

- (void)updateZoomValue
{
    CGFloat minValue = self.planetMode ? kPreMinimumLittlePlanetZoomValue : kPreMinimumZoomValue;
    if (self.zoomValue > kPreMaximumZoomValue) {
        self.zoomValue *= 0.97;
    } else if (self.zoomValue <  minValue) {
        self.zoomValue *= 1.03;
    }
}

#pragma mark - GestureActions

- (void)pinchForZoom:(UIPinchGestureRecognizer *)gesture
{
    if (gesture.state == UIGestureRecognizerStateBegan) {
        self.isZooming = YES;
        gesture.scale = self.zoomValue;
    } else if (gesture.state == UIGestureRecognizerStateChanged) {
        CGFloat zoom = gesture.scale;
        zoom = MAX(MIN(zoom, kMaximumZoomValue), self.planetMode ? kMinimumLittlePlanetZoomValue : kMinimumZoomValue);
        self.zoomValue = zoom;
    } else if (gesture.state == UIGestureRecognizerStateEnded) {
        self.isZooming = NO;
    }
}

- (void)tapGesture
{
    //dummy
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

- (void)setAdditionalMovement
{
    self.prevTouchPoint = CGPointZero;
    self.velocityValue = CGPointMake(0.9 * self.velocityValue.x, 0.9 * self.velocityValue.y);
    CGPoint nextPoint = CGPointMake(kAdditionalMovementCoef * self.velocityValue.x, kAdditionalMovementCoef * self.velocityValue.y);
    
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
    NSString *title = [[[NSBundle mainBundle] localizedInfoDictionary] objectForKey:@"CFBundleDisplayName"];
    [[[UIAlertView alloc] initWithTitle:title message:@"Gyroscope is not avaliable on your device" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
}

#pragma mark - Private

- (void)setEmptyImage
{
    [self setupTextureWithImage:[[UIImage alloc] init].CGImage];
}

- (void)addGestures
{
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchForZoom:)];
    pinch.delegate = self;
    [self.view addGestureRecognizer:pinch];
    
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGesture)];
    tapGesture.delegate = self;
    [self.view addGestureRecognizer:tapGesture];

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
    _currentProjectionMatrix = GLKMatrix4Identity;
    _cameraProjectionMatrix = GLKMatrix4Identity;
    self.zoomValue = 1.2f;
    self.planetMode = PlanetModeNormal;
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

@end
