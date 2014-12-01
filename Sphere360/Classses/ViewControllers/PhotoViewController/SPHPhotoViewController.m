//
//  SPHPhotoViewController.m
//  Sphere360
//
//  Created by Kirill on 12/1/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

#import "SPHPhotoViewController.h"
#import "Sphere.h"
#import "GLProgram.h"

static CGFloat const defStartY = -1.8;
static CGFloat const defStartX = -3.;

static CGFloat const minZoomDegree = 20.;
static CGFloat const maxZoomDegree = 130.;
static CGFloat const defaultZoomDegree = 90;

enum {
    UNIFORM_MVPMATRIX,
    UNIFORM_SAMPLER,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

@interface SPHPhotoViewController () {
    GLuint _vertexArrayID;
    GLuint _vertexBufferID;
    GLuint _vertexTexCoordID;
    GLuint _vertexTexCoordAttributeIndex;
    GLKMatrix4 _modelViewProjectionMatrix;
    
    GLuint name;
    
    float _rotationX;
    float _rotationY;
}

@property (strong, nonatomic) GLProgram *program;
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKTextureInfo *texture;

@property (strong, nonatomic) NSMutableArray *currentTouches;
@property (assign, nonatomic) CGFloat zoomValueCurrent;

@end

@implementation SPHPhotoViewController

#pragma mark - LifeCycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setStartPosition];
    
    [self setupContext];
    [self addPinchGesture];
    [self setupGL];
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
    
    [self setupTexture];
}

- (void)setupTexture
{
    NSString *textureFile = [[NSBundle mainBundle] pathForResource:kTestImage ofType:@"jpeg"];
    UIImage *sourceImage = [UIImage imageWithContentsOfFile:textureFile];
    UIImage* flippedImage = [UIImage flipAndMirrorImageHorizontally:sourceImage];
    NSError *error;
    _texture = [GLKTextureLoader textureWithCGImage:flippedImage.CGImage options:nil error:&error];
    if (error) {
        NSLog(@"Error during loading texture: %@", error);
    }
}

#pragma mark - Draw & update methods

- (void)update
{
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
    _program = [[GLProgram alloc] initWithVertexShaderFilename:@"Shader" fragmentShaderFilename:@"Shader"];
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
    if (defaultZoomDegree * scaleValue > maxZoomDegree) {
        self.zoomValueCurrent = maxZoomDegree;
    } else if (defaultZoomDegree * scaleValue < minZoomDegree) {
        self.zoomValueCurrent = minZoomDegree;
    } else {
        self.zoomValueCurrent  = defaultZoomDegree * scaleValue;
    }
}

#pragma mark - Private

- (void)setupContext
{
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    self.preferredFramesPerSecond = 10.0;
}

- (void)addPinchGesture
{
    UIPinchGestureRecognizer *pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchForZoom:)];
    [(GLKView *)self.view addGestureRecognizer:pinch];
}

- (void)setStartPosition
{
    _rotationX = defStartX;
    _rotationY = defStartY;
    self.zoomValueCurrent = defaultZoomDegree;
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


@end
