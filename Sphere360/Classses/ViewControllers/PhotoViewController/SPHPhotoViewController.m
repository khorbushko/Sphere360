//
//  SPHPhotoViewController.m
//  Sphere360
//
//  Created by Kirill on 12/1/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

#import "SPHPhotoViewController.h"
#import "Sphere.h"
#import "SPHGLProgram.h"
#import "SPHAnimationProvider.h"
#import <AVFoundation/AVFoundation.h>
#import "SPHTextureProvider.h"

static CGFloat const kDefStartY = -1.8;
static CGFloat const kDefStartX = -3.;
static CGFloat const kMinimumZoomDegree = 20.;
static CGFloat const kMaximumZoomDegree = 130.;
static CGFloat const kDefaultZoomDegree = 90;

enum {
    UNIFORM_MVPMATRIX,
    UNIFORM_SAMPLER,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

@interface SPHPhotoViewController () <AVAssetResourceLoaderDelegate> {
    GLuint _vertexArrayID;
    GLuint _vertexBufferID;
    GLuint _vertexTexCoordID;
    GLuint _vertexTexCoordAttributeIndex;
    GLKMatrix4 _modelViewProjectionMatrix;
    
    GLuint name;
    
    float _rotationX;
    float _rotationY;
    
    AVAssetReader *movieReader;
}

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *heightBottomViewConstraint;
@property (weak, nonatomic) IBOutlet UIView *bottomView;

@property (strong, nonatomic) SPHGLProgram *program;
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKTextureInfo *texture;

@property (strong, nonatomic) NSMutableArray *currentTouches;
@property (assign, nonatomic) CGFloat zoomValueCurrent;
@property (assign, nonatomic) BOOL isHyroscopeActive;

@end

@implementation SPHPhotoViewController

#pragma mark - LifeCycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setStartPosition];
    
    [self setupContext];
    [self setupGL];
    
    [self addPinchGesture];
    [self addTapGesture];
    
    [self readAssetWithURL:nil];
}

- (void)dealloc
{
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
    
    //start picture
    NSString *textureFile = [[NSBundle mainBundle] pathForResource:kTestImage ofType:kTestImageType];
    UIImage *sourceImage = [UIImage imageWithContentsOfFile:textureFile];
    UIImage* flippedImage = [UIImage flipAndMirrorImageHorizontally:sourceImage];
    
    [self setupTextureWithImage:flippedImage];
}

#pragma mark - Textures

- (void)setupTextureWithImage:(UIImage *)image
{
    if (_texture.name) {
        GLuint textureName = _texture.name;
        glDeleteTextures(1, &textureName);
    }
    
    NSError *error;
    _texture = [GLKTextureLoader textureWithCGImage:image.CGImage options:nil error:&error];
    if (error) {
        NSLog(@"Error during loading texture: %@", error);
    }
}

#pragma mark - Draw & update methods

- (void)update
{
    [self readNextMovieFrame];
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(self.zoomValueCurrent), aspect, 0.1f, 100.0f);
    
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, _rotationX, 1.0f, 0.0f, 0.0f);
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, _rotationY, 0.0f, 1.0f, 0.0f);
    _modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);

}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{    
    [_program use];
    
    glBindVertexArrayOES(_vertexArrayID);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    glUniformMatrix4fv(uniforms[UNIFORM_MVPMATRIX], 1, 0, _modelViewProjectionMatrix.m);
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(_texture.target, _texture.name);
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
    distX *= -0.015;
    distY *= 0.015;
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

#pragma mark - Private

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

#pragma mark - Cleanup

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
    glDeleteBuffers(1, &_vertexBufferID);
    glDeleteVertexArraysOES(1, &_vertexArrayID);
    glDeleteBuffers(1, &_vertexTexCoordID);
    _program = nil;
    _texture = nil;
}

#pragma mark - Video

- (void)readAssetWithURL:(NSURL *)assetURL
{
    NSString *path = [[NSBundle mainBundle] pathForResource:kTestVideo ofType:kTestVideoType];
    NSURL *urlToFile = [NSURL fileURLWithPath:path];
    AVURLAsset *avAsset = [[AVURLAsset alloc] initWithURL:urlToFile options:nil];
    [avAsset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            AVAssetTrack *videoTrack = nil;
            NSArray *tracks = [avAsset tracksWithMediaType:AVMediaTypeVideo];
            if (tracks.count) {
                videoTrack = tracks[0];
                NSError *error;
                movieReader = [[AVAssetReader alloc] initWithAsset:avAsset error:&error];
                if (error) {
                    NSLog(@"Error - cant read Video - %@", error.localizedDescription);
                } else {

                    NSDictionary *videoSetting = @{
                                                   (NSString *)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA]
                                                   };

                    [movieReader addOutput:[AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack outputSettings:videoSetting]];
                    [movieReader startReading];
                }
            }
        });
    }];
}

- (void)readNextMovieFrame
{
    if (movieReader.status == AVAssetReaderStatusReading) {
        AVAssetReaderTrackOutput *output = [movieReader.outputs objectAtIndex:0];
        CMSampleBufferRef samplerBuffer = [output copyNextSampleBuffer];
        if (samplerBuffer) {
            CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(samplerBuffer);
            
            [self setupTextureWithImage:[UIImage flipAndMirrorImageHorizontally:[SPHTextureProvider imageWithCVImageBuffer:imageBuffer]]];
            
            CVPixelBufferUnlockBaseAddress(imageBuffer, 0);
            CFRelease(samplerBuffer);
        }
    }
}

#pragma mark - Audio

- (void)readAudioWithUrl:(NSURL *)aassetURL
{
    NSURL *url = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:kTestVideo ofType:kTestVideoType]];
    AVURLAsset *avasset = [[AVURLAsset alloc] initWithURL:url options:nil];
    AVAssetTrack *track1 = [[avasset tracksWithMediaType:AVMediaTypeAudio] objectAtIndex:0];
    
    NSMutableDictionary *dic2 = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kAudioFormatLinearPCM], AVFormatIDKey,  [NSNumber numberWithInt:16],AVLinearPCMBitDepthKey,
                                 [NSNumber numberWithBool:NO],AVLinearPCMIsBigEndianKey,
                                 [NSNumber numberWithBool:NO],AVLinearPCMIsFloatKey,
                                 [NSNumber numberWithBool:NO],AVLinearPCMIsNonInterleaved, nil];
    
    AVAssetReaderTrackOutput *audioReaderTrackOutput = [[AVAssetReaderTrackOutput alloc] initWithTrack:track1 outputSettings:dic2];
    
    AVAssetReader *audioReader = [[AVAssetReader alloc] initWithAsset:avasset error:nil];
    
    [audioReader addOutput:audioReaderTrackOutput];
    [audioReader startReading];
    [self playAudioWithOutput:audioReaderTrackOutput];
}

- (void)playAudioWithOutput:(AVAssetReaderTrackOutput *)audioReaderTrackOutput
{
    CMSampleBufferRef sample = [audioReaderTrackOutput copyNextSampleBuffer];
    CMBlockBufferRef blockBufferRef = CMSampleBufferGetDataBuffer(sample);
    
    size_t length = CMBlockBufferGetDataLength(blockBufferRef);
    UInt8 buffer[length];
    CMBlockBufferCopyDataBytes(blockBufferRef, 0, length, buffer);
    
    NSData * data = [[NSData alloc] initWithBytes:buffer length:length];
    NSString *docDirPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *filePath = [NSString stringWithFormat:@"%@/test.mp3", docDirPath];
    [data writeToFile:filePath atomically:YES];
    
    NSError *error;
    NSURL *fileURL = [NSURL fileURLWithPath:filePath];
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:fileURL error:&error];
    player.numberOfLoops = 0;
    [player play];
}








@end
