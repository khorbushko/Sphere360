//
//  SPHUniversalViewController
//  Sphere360
//
//  Created by Kirill on 12/1/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

#import "SPHUniversalViewController.h"
#import "Sphere.h"
#import "SPHGLProgram.h"
#import "SPHAnimationProvider.h"
#import <AVFoundation/AVFoundation.h>
#import "SPHTextureProvider.h"
#import <CoreMedia/CoreMedia.h>
#import "SPHVideoPlayer.h"

static CGFloat const kDefStartY = -1.8;
static CGFloat const kDefStartX = -3.;
static CGFloat const kMinimumZoomDegree = 40.;
static CGFloat const kMaximumZoomDegree = 130.;
static CGFloat const kDefaultZoomDegree = 90;

enum {
    UNIFORM_MVPMATRIX,
    UNIFORM_SAMPLER,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

@interface SPHUniversalViewController () <AVAssetResourceLoaderDelegate, SPHVideoPlayerDelegate> {
    GLuint _vertexArrayID;
    GLuint _vertexBufferID;
    GLuint _vertexTexCoordID;
    GLuint _vertexTexCoordAttributeIndex;
    GLKMatrix4 _modelViewProjectionMatrix;
    
    float _rotationX;
    float _rotationY;
}

@property (weak, nonatomic) IBOutlet UIView *bottomView;
@property (weak, nonatomic) IBOutlet UIButton *playStopButton;
@property (weak, nonatomic) IBOutlet UISlider *videoProgressSlider;
@property (weak, nonatomic) IBOutlet UISlider *volumeSlider;
@property (weak, nonatomic) IBOutlet UIButton *gyroscopeButton;

@property (strong, nonatomic) SPHGLProgram *program;
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKTextureInfo *texture;
@property (strong, nonatomic) NSMutableArray *currentTouches;
@property (assign, nonatomic) CGFloat zoomValueCurrent;
@property (assign, nonatomic) BOOL isHyroscopeActive;

//video prop
@property (assign, nonatomic) CGFloat urlAssetDuration;
@property (strong, nonatomic) AVURLAsset *urlAsset;
@property (strong, nonatomic) SPHVideoPlayer *videoPlayer;

@end

@implementation SPHUniversalViewController

#pragma mark - LifeCycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setStartPosition];
    
    [self setupContext];
    [self setupGL];
    
    [self addPinchGesture];
    [self addTapGesture];
    
    [self setupVideoPlayer];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self clearPlayer];
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
    
    if (self.selectedController == VideoViewController) {
        [self setEmptyImage];
        [self setupSlider];
    } else if (self.selectedController == PhotoViewController) {
        [self applyImageTexture];
    }
}

- (void)applyImageTexture
{
    UIImage *sourceImage = [UIImage imageWithContentsOfFile:self.sourceURL];
    UIImage* flippedImage = [UIImage flipAndMirrorImageHorizontally:sourceImage];
    [self setupTextureWithImage:flippedImage];
}

#pragma mark - Textures

- (void)setupTextureWithImage:(UIImage *)image
{
    GLKTextureLoader *textureloader = [[GLKTextureLoader alloc] initWithSharegroup:self.context.sharegroup];
    [textureloader textureWithCGImage:image.CGImage options:nil queue:nil completionHandler:^(GLKTextureInfo *textureInfo, NSError *outError) {
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
    if (self.selectedController == VideoViewController && [self.videoPlayer isPlayerPlayVideo]) {
        [self setNewTextureFromVideoPlayer];
    }
    
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(self.zoomValueCurrent), aspect, 0.1f, 60.0f);
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, _rotationX, 1.0f, 0.0f, 0.0f);
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, _rotationY, 0.0f, 1.0f, 0.0f);
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
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
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
        NSAssert(NO, @"Falied to link HalfSpherical shaders");
	}
    _vertexTexCoordAttributeIndex = [_program attributeIndex:@"a_textureCoord"];
    
    uniforms[UNIFORM_MVPMATRIX] = [_program uniformIndex:@"u_modelViewProjectionMatrix"];
    uniforms[UNIFORM_SAMPLER] = [_program uniformIndex:@"u_Sampler"];
}

#pragma mark - Touches

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    for (UITouch *touch in touches) {
        if (!_currentTouches.count) {
            _currentTouches = [[NSMutableArray alloc] init];
        }
        [_currentTouches addObject:touch];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    float distX = [touch locationInView:touch.view].x - [touch previousLocationInView:touch.view].x;
    float distY = [touch locationInView:touch.view].y - [touch previousLocationInView:touch.view].y;
    distX *= -0.003;
    distY *= 0.003;
    _rotationX += -distY;
    _rotationY += -distX;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    for (UITouch *touch in touches) {
        [_currentTouches removeObject:touch];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    for (UITouch *touch in touches) {
        [_currentTouches removeObject:touch];
    }
}

- (void)pinchForZoom:(UIGestureRecognizer *)sender
{
    CGFloat scaleValue = [(UIPinchGestureRecognizer*)sender scale];
    if (kDefaultZoomDegree * scaleValue > kMaximumZoomDegree) {
        self.zoomValueCurrent = kMaximumZoomDegree;
    } else if (kDefaultZoomDegree * scaleValue < kMinimumZoomDegree) {
        self.zoomValueCurrent = kMinimumZoomDegree;
    } else {
        self.zoomValueCurrent  = kDefaultZoomDegree * scaleValue;
    }
}

- (void)tapGesture
{
    [self hideNavigationBar];
    [self hideBottomBar];
}

#pragma mark - IBActions

- (IBAction)gyroscopeButtonPress:(id)sender
{
    [self tapGesture];
    self.isHyroscopeActive = !self.isHyroscopeActive;
}

- (IBAction)playStopButtonPress:(id)sender
{
    if ([self.videoPlayer isPlayerPlayVideo]) {
        [self.playStopButton setTitle:@"Play" forState:UIControlStateNormal];
        [self.videoPlayer pause];
    } else {
        [self.playStopButton setTitle:@"Stop" forState:UIControlStateNormal];
        [self.videoPlayer play];
        self.volumeSlider.value = self.videoPlayer.volume;
    }
}

#pragma mark - Video

- (void)setupVideoPlayer
{
    if (self.selectedController == VideoViewController) {
        NSURL *urlToFile = [NSURL fileURLWithPath:self.sourceURL];
        self.videoPlayer = [[SPHVideoPlayer alloc] initVideoPlayerWithURL:urlToFile];
        [self.videoPlayer prepareToPlay];
        self.videoPlayer.delegate = self;
    }
}

- (void)setNewTextureFromVideoPlayer
{
    if (self.videoPlayer) {
        if ([self.videoPlayer canProvideFrame]) {
            UIImage *image = [self.videoPlayer getCurrentFramePicture];
            [self setupTextureWithImage:[UIImage flipAndMirrorImageHorizontally:image]];
        }
    }
    [self drawArrayOfData];
}

- (void)clearPlayer
{
    [self.videoPlayer stop];
    [self.videoPlayer removeObserversFromPlayer];
    self.videoPlayer.delegate = nil;
    self.videoPlayer = nil;
}

#pragma mark - SPHVideoPlayerDelegate

- (void)isReadyToPlayVideo
{
    self.playStopButton.enabled = YES;
    self.videoProgressSlider.enabled = YES;
    self.gyroscopeButton.enabled = YES;
    self.volumeSlider.enabled = YES;
}

- (void)progressUpdateToTime:(CGFloat)progress
{
    if ([self.videoPlayer isPlayerPlayVideo]) {
        self.videoProgressSlider.value = progress;
    }
}

#pragma mark - Private

- (void)setEmptyImage
{
    [self setupTextureWithImage:[[UIImage alloc] init]];
}

- (void)hideBottomBar
{
    CGPoint toValue = self.bottomView.center;
    CGPoint fromValue = self.bottomView.center;
    CABasicAnimation *animation;
    if (self.navigationController.navigationBarHidden) {
        toValue.y += self.bottomView.bounds.size.height;
        animation = [SPHAnimationProvider animationForMovingViewFromValue:[NSValue valueWithCGPoint:fromValue] toValue:[NSValue valueWithCGPoint:toValue]  withDuration:0.3];
    } else {
        animation = [SPHAnimationProvider animationForMovingViewFromValue:[NSValue valueWithCGPoint:fromValue] toValue:[NSValue valueWithCGPoint:toValue]  withDuration:0.9];
    }
    
    [self.bottomView.layer addAnimation:animation forKey:nil];
    self.bottomView.layer.position = toValue;
}

- (void)hideNavigationBar
{
    [self.navigationController setNavigationBarHidden:!self.navigationController.navigationBarHidden animated:YES];
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

- (void)addPinchGesture
{
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchForZoom:)];
    [self.view addGestureRecognizer:pinch];
}

- (void)addTapGesture
{
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapGesture)];
    [self.view addGestureRecognizer:tapGesture];
}

- (void)setStartPosition
{
    _rotationX = kDefStartX;
    _rotationY = kDefStartY;
    self.zoomValueCurrent = kDefaultZoomDegree;
}
#pragma mark - UIConfiguration

- (void)setupSlider
{
    [self.videoProgressSlider addTarget:self action:@selector(progressSliderTouchedDown) forControlEvents:UIControlEventTouchDown];
    [self.videoProgressSlider addTarget:self action:@selector(progressSliderTouchedUp) forControlEvents:UIControlEventTouchUpInside];
    [self.volumeSlider addTarget:self action:@selector(volumeSliderTouchedUp) forControlEvents:UIControlEventTouchUpInside];
}

#pragma mark - Slider

- (void)progressSliderTouchedDown
{
    if ([self.videoPlayer isPlayerPlayVideo]) {
        [self.videoPlayer pause];
    }
}

- (void)progressSliderTouchedUp
{
    [self.videoPlayer seekPositionAtProgress:self.videoProgressSlider.value];
}

- (void)volumeSliderTouchedUp
{
    [self.videoPlayer setPlayerVolume:self.volumeSlider.value];
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
    [self clearPlayer];
    [self tearDownGL];
}

@end
