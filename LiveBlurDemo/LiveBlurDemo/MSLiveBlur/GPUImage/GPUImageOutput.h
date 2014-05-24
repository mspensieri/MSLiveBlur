#import "GPUImageContext.h"

#import <UIKit/UIKit.h>

typedef struct GPUTextureOptions {
    GLenum minFilter;
    GLenum magFilter;
    GLenum wrapS;
    GLenum wrapT;
    GLenum internalFormat;
    GLenum format;
    GLenum type;
} GPUTextureOptions;

void runOnMainQueueWithoutDeadlocking(void (^block)(void));
void runSynchronouslyOnVideoProcessingQueue(void (^block)(void));
void runAsynchronouslyOnVideoProcessingQueue(void (^block)(void));
void reportAvailableMemoryForGPUImage(NSString *tag);

/** GPUImage's base source object
 
 Images or frames of video are uploaded from source objects, which are subclasses of GPUImageOutput. These include:
 
 - GPUImageVideoCamera (for live video from an iOS camera) 
 - GPUImageStillCamera (for taking photos with the camera)
 - GPUImagePicture (for still images)
 - GPUImageMovie (for movies)
 
 Source objects upload still image frames to OpenGL ES as textures, then hand those textures off to the next objects in the processing chain.
 */
@interface GPUImageOutput : NSObject <GPUImageTextureDelegate>
{
    NSMutableArray *targets, *targetTextureIndices;
    
    GLuint outputTexture;
    CGSize inputTextureSize, cachedMaximumOutputSize, forcedMaximumSize;
    
    BOOL overrideInputSize;
    
    BOOL processingLargeImage;
    NSUInteger outputTextureRetainCount;
    
    __unsafe_unretained id<GPUImageTextureDelegate> firstTextureDelegate;
    BOOL shouldConserveMemoryForNextFrame;
    
    BOOL allTargetsWantMonochromeData;
}

@property(readwrite, nonatomic) BOOL shouldSmoothlyScaleOutput;
@property(readwrite, nonatomic) BOOL shouldIgnoreUpdatesToThisTarget;
@property(readwrite, nonatomic, unsafe_unretained) id<GPUImageInput> targetToIgnoreForUpdates;
@property(nonatomic, copy) void(^frameProcessingCompletionBlock)(GPUImageOutput*, CMTime);
@property(nonatomic) BOOL enabled;
@property(readwrite, nonatomic) GPUTextureOptions outputTextureOptions;

/// @name Managing targets
- (void)setInputTextureForTarget:(id<GPUImageInput>)target atIndex:(NSInteger)inputTextureIndex;
- (GLuint)textureForOutput;
- (void)notifyTargetsAboutNewOutputTexture;

/** Returns an array of the current targets.
 */
- (NSArray*)targets;

/** Adds a target to receive notifications when new frames are available.
 
 The target will be asked for its next available texture.
 
 See [GPUImageInput newFrameReadyAtTime:]
 
 @param newTarget Target to be added
 */
- (void)addTarget:(id<GPUImageInput>)newTarget;

/** Adds a target to receive notifications when new frames are available.
 
 See [GPUImageInput newFrameReadyAtTime:]
 
 @param newTarget Target to be added
 */
- (void)addTarget:(id<GPUImageInput>)newTarget atTextureLocation:(NSInteger)textureLocation;

/** Removes a target. The target will no longer receive notifications when new frames are available.
 
 @param targetToRemove Target to be removed
 */
- (void)removeTarget:(id<GPUImageInput>)targetToRemove;

/** Removes all targets.
 */
- (void)removeAllTargets;

/// @name Manage the output texture

- (void)initializeOutputTextureIfNeeded;
- (void)deleteOutputTexture;
- (void)forceProcessingAtSize:(CGSize)frameSize;
- (void)forceProcessingAtSizeRespectingAspectRatio:(CGSize)frameSize;
- (void)cleanupOutputImage;

/// @name Still image processing

- (CGImageRef)newCGImageFromCurrentlyProcessedOutput;
- (CGImageRef)newCGImageFromCurrentlyProcessedOutputWithOrientation:(UIImageOrientation)imageOrientation;
- (CGImageRef)newCGImageByFilteringCGImage:(CGImageRef)imageToFilter;
- (CGImageRef)newCGImageByFilteringCGImage:(CGImageRef)imageToFilter orientation:(UIImageOrientation)orientation;

// Platform-specific image output methods
#if TARGET_IPHONE_SIMULATOR || TARGET_OS_IPHONE
- (UIImage *)imageFromCurrentlyProcessedOutput;
- (UIImage *)imageFromCurrentlyProcessedOutputWithOrientation:(UIImageOrientation)imageOrientation;
- (UIImage *)imageByFilteringImage:(UIImage *)imageToFilter;
- (CGImageRef)newCGImageByFilteringImage:(UIImage *)imageToFilter;
#else
- (NSImage *)imageFromCurrentlyProcessedOutput;
- (NSImage *)imageFromCurrentlyProcessedOutputWithOrientation:(UIImageOrientation)imageOrientation;
- (NSImage *)imageByFilteringImage:(NSImage *)imageToFilter;
- (CGImageRef)newCGImageByFilteringImage:(NSImage *)imageToFilter;
#endif

- (BOOL)providesMonochromeOutput;

- (void)prepareForImageCapture;
- (void)conserveMemoryForNextFrame;

@end
