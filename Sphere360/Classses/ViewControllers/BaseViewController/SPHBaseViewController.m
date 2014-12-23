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
static CGFloat const kPreMinimumLittlePlanetZoomValue = 0.7375f;
static CGFloat const kMinimumZoomValue = 0.975f;
static CGFloat const kMaximumZoomValue = 1.7f;
static CGFloat const kPreMinimumZoomValue = 1.086f;
static CGFloat const kPreMaximumZoomValue = 1.60f;

static CGFloat const kAdditionalMovementCoef = 0.01f;

static CGFloat const NormalAngle = 90.0f;
static CGFloat const LittlePlanetAngle = 115.0f;

static CGFloat const NormalNear = 0.1f;
static CGFloat const LittlePlanetNear = 0.01f;;

enum {
    UNIFORM_MVPMATRIX,
    UNIFORM_SAMPLER,
    UNIFORM_Y,
    UNIFORM_UV,
    UNIFORM_COLOR_CONVERSION_MATRIX,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

static const GLfloat kColorConversion709[] = {
    1.1643,  0.0000,  1.2802,
    1.1643, -0.2148, -0.3806,
    1.1643,  2.1280,  0.0000
};

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
    
    unsigned int sphereVertices;
    
    const GLfloat *_preferredConversion;
    
    CVOpenGLESTextureRef _lumaTexture;
    CVOpenGLESTextureRef _chromaTexture;
    CVOpenGLESTextureCacheRef _videoTextureCache;
}

@property (strong, nonatomic) SPHGLProgram *program;
@property (strong, nonatomic) EAGLContext *context;
@property (strong, atomic) GLKTextureInfo *texture;

@property (assign, nonatomic) CGFloat angle;
@property (assign, nonatomic) CGFloat near;

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
    self.view.opaque = YES;
    
    [self setInitialParameters];
    
    [self setupContext];
    [self setupGL];
    
    [self addGestures];
    [self setupGyroscope];
    
    [self setupTextureLoader];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self tearDownGL];
}

#pragma mark - OpenGL Setup

- (void)setupGL
{
    self.preferredFramesPerSecond = 60;
    
    [EAGLContext setCurrentContext:self.context];
    [self buildProgram];
    
    glDisable(GL_DEPTH_TEST);
    glDepthMask(GL_FALSE);
    glDisable(GL_CULL_FACE);
    
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
    
    if (self.mediaType == MediaTypeVideo && !_videoTextureCache) {
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _context, NULL, &_videoTextureCache);
        if (err != noErr) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
            return;
        }
    }
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
    [self.textureloader textureWithCGImage:image options:nil queue:NULL completionHandler:^(GLKTextureInfo *textureInfo, NSError *outError) {
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
    
    CGFloat angle = [self normalizedAngle];
    CGFloat near = [self normalizedNear];
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
    [super glkView:view drawInRect:rect];
    [_program use];	
    [self drawArraysGL];
}

- (void)drawArraysGL
{
    if (self.mediaType == MediaTypePhoto) {
        glBindVertexArrayOES(_vertexArrayID);
    }
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glBlendFunc(GL_ONE, GL_ZERO);
    glUniformMatrix4fv(uniforms[UNIFORM_MVPMATRIX], 1, 0, _modelViewProjectionMatrix.m);
    if (self.mediaType == MediaTypePhoto && _texture) {
        glBindTexture(GL_TEXTURE_2D, _texture.name);
    }
    if (self.mediaType == MediaTypeVideo) {
        glUniform1i(uniforms[UNIFORM_Y], 0);
        glUniform1i(uniforms[UNIFORM_UV], 1);
    }
    glDrawArrays(GL_TRIANGLES, 0, sphereVertices);
}

#pragma mark - OpenGL Setup

- (void)buildProgram
{
    if (self.mediaType == MediaTypePhoto) {
        _program = [[SPHGLProgram alloc] initWithVertexShaderFilename:@"Shader" fragmentShaderFilename:@"Shader"];
    } else if (self.mediaType == MediaTypeVideo) {
        _program = [[SPHGLProgram alloc] initWithVertexShaderFilename:@"Shader" fragmentShaderFilename:@"ShaderVideo"];
    }
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
    if (self.mediaType == MediaTypePhoto) {
        uniforms[UNIFORM_SAMPLER] = [_program uniformIndex:@"u_Sampler"];
    } else if (self.mediaType == MediaTypeVideo) {
        uniforms[UNIFORM_UV] = [_program uniformIndex:@"SamplerUV"];
        uniforms[UNIFORM_Y] = [_program uniformIndex:@"SamplerY"];
        uniforms[UNIFORM_COLOR_CONVERSION_MATRIX] = [_program uniformIndex:@"colorConversionMatrix"];
    }
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
    _preferredConversion = kColorConversion709;
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

#pragma mark - SphereMode

- (void)turnPlanetMode
{
    self.planetMode = self.planetMode ? PlanetModeNormal : PlanetModeLittlePlanet;
}

- (CGFloat)normalizedAngle
{
    switch (self.planetMode) {
        case PlanetModeNormal: {
            if (self.angle > NormalAngle) {
                self.angle--;
            }
            break;
        }
        case PlanetModeLittlePlanet: {
            if (self.angle < LittlePlanetAngle) {
                self.angle++;
            }
            break;
        }
    }
    return self.angle;
}

- (CGFloat)normalizedNear
{
    switch (self.planetMode) {
        case PlanetModeNormal: {
            if (self.near < NormalNear) {
                self.near+=0.005;
            }
            break;
        }
        case PlanetModeLittlePlanet: {
            if (self.near > LittlePlanetNear) {
                self.near-=0.005;
            }
            break;
        }
    }
    return self.near;
}

#pragma mark - Touches

- (void)moveToPointX:(CGFloat)pointX andPointY:(CGFloat)pointY
{
    if (self.isGyroModeActive) {
        return;
    }
    pointX *= 0.005;
    pointY *= 0.005;
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
        self.zoomValue *= 0.99;
    } else if (self.zoomValue <  minValue) {
        self.zoomValue *= 1.01;
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
    self.angle = NormalAngle;
    self.near = NormalNear;
    sphereVertices = SphereNumVerts;
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

#pragma mark - VideoTextures

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    CVReturn err;
    if (pixelBuffer != NULL) {
        int frameWidth = (int)CVPixelBufferGetWidth(pixelBuffer);
        int frameHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
        
        if (!_videoTextureCache) {
            NSLog(@"No video texture cache");
            return;
        }
        [self cleanUpTextures];
        
        //Create Y and UV textures from the pixel buffer. These textures will be drawn on the frame buffer
        
        //Y-plane.
        glActiveTexture(GL_TEXTURE0);
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _videoTextureCache, pixelBuffer, NULL,  GL_TEXTURE_2D, GL_LUMINANCE, frameWidth, frameHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &_lumaTexture);
        if (err) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
        }
        
        glBindTexture(CVOpenGLESTextureGetTarget(_lumaTexture), CVOpenGLESTextureGetName(_lumaTexture));
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        // UV-plane.
        glActiveTexture(GL_TEXTURE1);
        err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _videoTextureCache, pixelBuffer, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, frameWidth / 2, frameHeight / 2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &_chromaTexture);
        if (err) {
            NSLog(@"Error at CVOpenGLESTextureCacheCreateTextureFromImage %d", err);
        }
        
        glBindTexture(CVOpenGLESTextureGetTarget(_chromaTexture), CVOpenGLESTextureGetName(_chromaTexture));
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glEnableVertexAttribArray(_vertexBufferID);
        glBindFramebuffer(GL_FRAMEBUFFER, _vertexBufferID);
        
        CFRelease(pixelBuffer);
        
        glUniformMatrix3fv(uniforms[UNIFORM_COLOR_CONVERSION_MATRIX], 1, GL_FALSE, _preferredConversion);
    }
}

- (void)cleanUpTextures
{
    if (_lumaTexture) {
        CFRelease(_lumaTexture);
        _lumaTexture = NULL;
    }
    
    if (_chromaTexture) {
        CFRelease(_chromaTexture);
        _chromaTexture = NULL;
    }
    
    // Periodic texture cache flush every frame
    CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
}


@end
