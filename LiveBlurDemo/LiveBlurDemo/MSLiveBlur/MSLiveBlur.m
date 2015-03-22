/***********************************************************************************
 *
 * MSLiveBlur.m
 *
 * Copyright (c) 2014 Michael Spensieri
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 ***********************************************************************************/

#import "MSLiveBlur.h"
#import "GPUImageUIElement.h"
#import "GPUImageGaussianBlurFilter.h"
#import "MSViewController.h"
#import "MSImageView.h"
#import "MSBlurWindow.h"

static const int kDefaultBlurRadius = 5;
static const int kDefaultBlurInterval = 0.5;

@interface MSLiveBlur()

@property GPUImageUIElement* stillImageSource;
@property GPUImageGaussianBlurFilter* filter;
@property NSTimer* blurTimer;

@property dispatch_queue_t taskQueue;
@property dispatch_semaphore_t semaphore;

@property UIWindow* blurWindow;
@property(weak) MSViewController* viewController;

@end

@implementation MSLiveBlur

+(instancetype)sharedInstance
{
    static MSLiveBlur* sharedInstance;
    if(!sharedInstance){
        sharedInstance = [[MSLiveBlur alloc] init];
    }
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _blurInterval = kDefaultBlurInterval;
        _isStatic = YES;
        
        [self initWindow];
        [self initGPUImageElements];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    return self;
}

-(void)initWindow
{
    _blurWindow = [[MSBlurWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _blurWindow.backgroundColor = [UIColor clearColor];
    _blurWindow.windowLevel = UIWindowLevelNormal + 1;
    _blurWindow.rootViewController = [[MSViewController alloc] init];
    
    _viewController = (MSViewController*)_blurWindow.rootViewController;
}

-(void)initGPUImageElements
{
    _taskQueue = dispatch_queue_create("MSLiveBlurGPUImageContextQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_set_target_queue(_taskQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
    _semaphore = dispatch_semaphore_create(1);
    
    dispatch_sync(_taskQueue, ^{
        _stillImageSource = [[GPUImageUIElement alloc] initWithView:[UIApplication sharedApplication].delegate.window];
        _filter = [[GPUImageGaussianBlurFilter alloc] init];
        _filter.blurRadiusInPixels = kDefaultBlurRadius;
        
        [_stillImageSource addTarget:_filter];
    });
}

-(void)blurRect:(CGRect)rect
{
    self.blurWindow.hidden = NO;
    
    [self.viewController.view blurRect:rect];
    if(self.blurTimer == nil && !self.isStatic){
        [self startTimer];
    }
}

-(void)startTimer
{
    dispatch_sync(self.taskQueue, ^{
        self.blurTimer = [NSTimer scheduledTimerWithTimeInterval:self.blurInterval target:self selector:@selector(updateBlur) userInfo:nil repeats:YES];
    });
}

-(void)stopBlurringRect:(CGRect)rect
{
    [self.viewController.view stopBlurringRect:rect];
    
    if(![self.viewController.view hasBlurredArea]){
        [self.blurTimer invalidate];
        self.blurTimer = nil;
        self.blurWindow.hidden = YES;
    }
}

-(void)addSubview:(UIView *)view
{
    [self.viewController.view addSubview:view];
}

-(void)forceUpdateBlur
{
    dispatch_async(self.taskQueue, ^{
        [self updateBlur];
    });
}

-(void)updateBlur
{
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    
    [self.stillImageSource update];
    UIImage *processedImage;
    if(floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_7_1){
        processedImage = [self.filter imageFromCurrentlyProcessedOutput];
    }else{
        processedImage = [self.filter imageFromCurrentlyProcessedOutputWithOrientation:UIImageOrientationUp];
    }
    
    dispatch_semaphore_signal(self.semaphore);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.viewController.imageView crossfadeToImage:processedImage];
    });
}

-(void)setBlurRadius:(double)blurRadius
{
    self.filter.blurRadiusInPixels = blurRadius;
}

-(double)blurRadius
{
    return self.filter.blurRadiusInPixels;
}

-(void)setTintColor:(UIColor *)tintColor
{
    self.viewController.tintView.backgroundColor = tintColor;
}

-(UIColor*)tintColor
{
    return self.viewController.tintView.backgroundColor;
}

-(void)dealloc
{
    [self.blurTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)enterBackground
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(becomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    [self.blurTimer invalidate];
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
}

-(void)becomeActive
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    dispatch_semaphore_signal(self.semaphore);
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    if(self.blurTimer != nil){
        [self startTimer];
    }
}

@end
