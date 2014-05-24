#import "GPUImageOutput.h"
//#import "GPUImagePicture.h"
#import <mach/mach.h>

void runSynchronouslyOnVideoProcessingQueue(void (^block)(void))
{
    dispatch_queue_t videoProcessingQueue = [GPUImageContext sharedContextQueue];
#if (!defined(__IPHONE_6_0) || (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0))
    if (dispatch_get_current_queue() == videoProcessingQueue)
#else
	if (dispatch_get_specific([GPUImageContext contextKey]))
#endif
	{
		block();
	}else
	{
		dispatch_sync(videoProcessingQueue, block);
	}
}

void runAsynchronouslyOnVideoProcessingQueue(void (^block)(void))
{
    dispatch_queue_t videoProcessingQueue = [GPUImageContext sharedContextQueue];
    
#if (!defined(__IPHONE_6_0) || (__IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_6_0))
    if (dispatch_get_current_queue() == videoProcessingQueue)
#else
    if (dispatch_get_specific([GPUImageContext contextKey]))
#endif
	{
		block();
	}else
	{
		dispatch_async(videoProcessingQueue, block);
	}
}

@implementation GPUImageOutput

@synthesize shouldSmoothlyScaleOutput = _shouldSmoothlyScaleOutput;
@synthesize shouldIgnoreUpdatesToThisTarget = _shouldIgnoreUpdatesToThisTarget;
@synthesize targetToIgnoreForUpdates = _targetToIgnoreForUpdates;
@synthesize frameProcessingCompletionBlock = _frameProcessingCompletionBlock;
@synthesize enabled = _enabled;
@synthesize outputTextureOptions = _outputTextureOptions;

#pragma mark -
#pragma mark Initialization and teardown

- (id)init; 
{
	if (!(self = [super init]))
    {
		return nil;
    }

    targets = [[NSMutableArray alloc] init];
    targetTextureIndices = [[NSMutableArray alloc] init];
    _enabled = YES;
    allTargetsWantMonochromeData = YES;
    
    // set default texture options
    _outputTextureOptions.minFilter = GL_LINEAR;
    _outputTextureOptions.magFilter = GL_LINEAR;
    _outputTextureOptions.wrapS = GL_CLAMP_TO_EDGE;
    _outputTextureOptions.wrapT = GL_CLAMP_TO_EDGE;
    _outputTextureOptions.internalFormat = GL_RGBA;
    _outputTextureOptions.format = GL_BGRA;
    _outputTextureOptions.type = GL_UNSIGNED_BYTE;

    return self;
}

- (void)dealloc 
{
    [self removeAllTargets];
    [self deleteOutputTexture];
}

#pragma mark -
#pragma mark Managing targets

- (void)setInputTextureForTarget:(id<GPUImageInput>)target atIndex:(NSInteger)inputTextureIndex;
{
    [target setInputTexture:[self textureForOutput] atIndex:inputTextureIndex];
}

- (GLuint)textureForOutput;
{
    return outputTexture;
}

- (void)notifyTargetsAboutNewOutputTexture;
{
    for (id<GPUImageInput> currentTarget in targets)
    {
        NSInteger indexOfObject = [targets indexOfObject:currentTarget];
        NSInteger textureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
        
        [self setInputTextureForTarget:currentTarget atIndex:textureIndex];
    }
}

- (NSArray*)targets;
{
	return [NSArray arrayWithArray:targets];
}

- (void)addTarget:(id<GPUImageInput>)newTarget;
{
    NSInteger nextAvailableTextureIndex = [newTarget nextAvailableTextureIndex];
    [self addTarget:newTarget atTextureLocation:nextAvailableTextureIndex];
    
    if ([newTarget shouldIgnoreUpdatesToThisTarget])
    {
        _targetToIgnoreForUpdates = newTarget;
    }
}

- (void)addTarget:(id<GPUImageInput>)newTarget atTextureLocation:(NSInteger)textureLocation;
{
    if([targets containsObject:newTarget])
    {
        return;
    }
    
    cachedMaximumOutputSize = CGSizeZero;
    runSynchronouslyOnVideoProcessingQueue(^{
        [self setInputTextureForTarget:newTarget atIndex:textureLocation];
        [newTarget setTextureDelegate:self atIndex:textureLocation];
        [targets addObject:newTarget];
        [targetTextureIndices addObject:[NSNumber numberWithInteger:textureLocation]];
        
        allTargetsWantMonochromeData = allTargetsWantMonochromeData && [newTarget wantsMonochromeInput];
    });
}

- (void)removeTarget:(id<GPUImageInput>)targetToRemove;
{
    if(![targets containsObject:targetToRemove])
    {
        return;
    }
    
    if (_targetToIgnoreForUpdates == targetToRemove)
    {
        _targetToIgnoreForUpdates = nil;
    }
    
    cachedMaximumOutputSize = CGSizeZero;
    
    NSInteger indexOfObject = [targets indexOfObject:targetToRemove];
    NSInteger textureIndexOfTarget = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];

    runSynchronouslyOnVideoProcessingQueue(^{
        [targetToRemove setInputTexture:0 atIndex:textureIndexOfTarget];
        [targetToRemove setInputSize:CGSizeZero atIndex:textureIndexOfTarget];
        [targetToRemove setTextureDelegate:nil atIndex:textureIndexOfTarget];
		[targetToRemove setInputRotation:kGPUImageNoRotation atIndex:textureIndexOfTarget];

        [targetTextureIndices removeObjectAtIndex:indexOfObject];
        [targets removeObject:targetToRemove];
        [targetToRemove endProcessing];
    });
}

- (void)removeAllTargets;
{
    cachedMaximumOutputSize = CGSizeZero;
    runSynchronouslyOnVideoProcessingQueue(^{
        for (id<GPUImageInput> targetToRemove in targets)
        {
            NSInteger indexOfObject = [targets indexOfObject:targetToRemove];
            NSInteger textureIndexOfTarget = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            
            [targetToRemove setInputTexture:0 atIndex:textureIndexOfTarget];
            [targetToRemove setInputSize:CGSizeZero atIndex:textureIndexOfTarget];
            [targetToRemove setTextureDelegate:nil atIndex:textureIndexOfTarget];
            [targetToRemove setInputRotation:kGPUImageNoRotation atIndex:textureIndexOfTarget];
        }
        [targets removeAllObjects];
        [targetTextureIndices removeAllObjects];
        
        allTargetsWantMonochromeData = YES;
    });
}

#pragma mark -
#pragma mark Manage the output texture

- (void)initializeOutputTextureIfNeeded;
{
    runSynchronouslyOnVideoProcessingQueue(^{
        if (!outputTexture)
        {
            [GPUImageContext useImageProcessingContext];
            
            glActiveTexture(GL_TEXTURE0);
            glGenTextures(1, &outputTexture);
            glBindTexture(GL_TEXTURE_2D, outputTexture);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, self.outputTextureOptions.minFilter);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, self.outputTextureOptions.magFilter);
            // This is necessary for non-power-of-two textures
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, self.outputTextureOptions.wrapS);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, self.outputTextureOptions.wrapT);
            glBindTexture(GL_TEXTURE_2D, 0);
        }
    });
}

- (void)deleteOutputTexture;
{
    runSynchronouslyOnVideoProcessingQueue(^{
        [GPUImageContext useImageProcessingContext];

        if (outputTexture)
        {
            glDeleteTextures(1, &outputTexture);
            outputTexture = 0;
        }
    });
}

- (void)forceProcessingAtSize:(CGSize)frameSize;
{
    
}

- (void)forceProcessingAtSizeRespectingAspectRatio:(CGSize)frameSize;
{
}

- (void)cleanupOutputImage;
{
    NSLog(@"WARNING: Undefined image cleanup");
}

#pragma mark -
#pragma mark Still image processing

- (CGImageRef)newCGImageFromCurrentlyProcessedOutputWithOrientation:(UIImageOrientation)imageOrientation;
{
    return nil;
}

- (CGImageRef)newCGImageByFilteringCGImage:(CGImageRef)imageToFilter
{
    return [self newCGImageByFilteringCGImage:imageToFilter orientation:UIImageOrientationUp];
}

- (CGImageRef)newCGImageByFilteringCGImage:(CGImageRef)imageToFilter orientation:(UIImageOrientation)orientation;
{
    return nil;
//    GPUImagePicture *stillImageSource = [[GPUImagePicture alloc] initWithCGImage:imageToFilter];
//    
//    [stillImageSource addTarget:(id<GPUImageInput>)self];
//    [stillImageSource processImage];
//    
//    CGImageRef processedImage = [self newCGImageFromCurrentlyProcessedOutputWithOrientation:orientation];
//    
//    [stillImageSource removeTarget:(id<GPUImageInput>)self];
//    return processedImage;
}

- (BOOL)providesMonochromeOutput;
{
    return NO;
}

- (void)prepareForImageCapture;
{
    
}

- (void)conserveMemoryForNextFrame;
{
    shouldConserveMemoryForNextFrame = YES;
    
    for (id<GPUImageInput> currentTarget in targets)
    {
        if (currentTarget != self.targetToIgnoreForUpdates)
        {
            [currentTarget conserveMemoryForNextFrame];
        }
    }
}

#pragma mark -
#pragma mark Platform-specific image output methods

- (CGImageRef)newCGImageFromCurrentlyProcessedOutput;
{
	UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    UIImageOrientation imageOrientation = UIImageOrientationLeft;
	switch (orientation)
    {
		case UIInterfaceOrientationPortrait:
			imageOrientation = UIImageOrientationUp;
			break;
		case UIInterfaceOrientationPortraitUpsideDown:
			imageOrientation = UIImageOrientationDown;
			break;
		case UIInterfaceOrientationLandscapeLeft:
			imageOrientation = UIImageOrientationRight;
			break;
		case UIInterfaceOrientationLandscapeRight:
			imageOrientation = UIImageOrientationLeft;
			break;
		default:
			imageOrientation = UIImageOrientationUp;
			break;
	}
    
    return [self newCGImageFromCurrentlyProcessedOutputWithOrientation:imageOrientation];
}

- (UIImage *)imageFromCurrentlyProcessedOutput;
{
	UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    UIImageOrientation imageOrientation = UIImageOrientationLeft;
	switch (orientation)
    {
		case UIInterfaceOrientationPortrait:
			imageOrientation = UIImageOrientationUp;
			break;
		case UIInterfaceOrientationPortraitUpsideDown:
			imageOrientation = UIImageOrientationDown;
			break;
		case UIInterfaceOrientationLandscapeLeft:
			imageOrientation = UIImageOrientationRight;
			break;
		case UIInterfaceOrientationLandscapeRight:
			imageOrientation = UIImageOrientationLeft;
			break;
		default:
			imageOrientation = UIImageOrientationUp;
			break;
	}
    
    return [self imageFromCurrentlyProcessedOutputWithOrientation:imageOrientation];
}

- (UIImage *)imageFromCurrentlyProcessedOutputWithOrientation:(UIImageOrientation)imageOrientation;
{
    CGImageRef cgImageFromBytes = [self newCGImageFromCurrentlyProcessedOutputWithOrientation:imageOrientation];
    UIImage *finalImage = [UIImage imageWithCGImage:cgImageFromBytes scale:1.0 orientation:imageOrientation];
    CGImageRelease(cgImageFromBytes);
    
    return finalImage;
}

- (UIImage *)imageByFilteringImage:(UIImage *)imageToFilter;
{
    CGImageRef image = [self newCGImageByFilteringCGImage:[imageToFilter CGImage] orientation:[imageToFilter imageOrientation]];
    UIImage *processedImage = [UIImage imageWithCGImage:image scale:[imageToFilter scale] orientation:[imageToFilter imageOrientation]];
    CGImageRelease(image);
    return processedImage;
}

- (CGImageRef)newCGImageByFilteringImage:(UIImage *)imageToFilter
{
    return [self newCGImageByFilteringCGImage:[imageToFilter CGImage] orientation:[imageToFilter imageOrientation]];
}

#pragma mark -
#pragma mark GPUImageTextureDelegate methods

- (void)textureNoLongerNeededForTarget:(id<GPUImageInput>)textureTarget;
{
    outputTextureRetainCount--;
    if (outputTextureRetainCount < 1)
    {
        [self cleanupOutputImage];
    }
}

@end
