/***********************************************************************************
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

#import "MSLiveBlurView.h"
#import "GPUImageUIElement.h"
#import "GPUImageGaussianBlurFilter.h"

static UIWindow* blurWindow;

const int kLiveBlurIntervalStatic = -1;

static const int kDefaultBlurRadius = 5;
static const int kDefaultBlurInterval = 0.5;

@interface MSLiveBlurView()

@property UIImageView* blurredImageView;
@property UIView* tintView;

@property GPUImageUIElement* stillImageSource;
@property GPUImageGaussianBlurFilter* filter;
@property NSTimer* blurTimer;

@property NSMutableArray* activeBlurAreas;

@property dispatch_queue_t taskQueue;
@property dispatch_semaphore_t semaphore;

@end

@implementation MSLiveBlurView

+(void)load
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidFinishLaunching) name:UIApplicationDidFinishLaunchingNotification object:nil];
}

+(void)applicationDidFinishLaunching
{
    [self ensureWindowExists];
    blurWindow.hidden = NO;
}

+(void)ensureWindowExists
{
    if(blurWindow == nil){
        blurWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        blurWindow.backgroundColor = [UIColor clearColor];
        blurWindow.windowLevel = UIWindowLevelNormal + 1;
        blurWindow.userInteractionEnabled = NO;
    }
}

+(instancetype)sharedInstance
{
    [self ensureWindowExists];
    
    static MSLiveBlurView* sharedInstance;
    if(!sharedInstance){
        sharedInstance = [[MSLiveBlurView alloc] init];
    }
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _activeBlurAreas = [NSMutableArray new];
        _blurInterval = kDefaultBlurInterval;
        
        _blurredImageView = [[UIImageView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [blurWindow addSubview:_blurredImageView];
        
        [self initGPUImageElements];
        [self initTintView];
        
        [self updateSubviewOrientations:[UIApplication sharedApplication].statusBarOrientation];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationChange:) name:UIApplicationWillChangeStatusBarOrientationNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(enterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    return self;
}

-(void)initGPUImageElements
{
    self.taskQueue = dispatch_queue_create("SupportKitGPUImageContextQueue", DISPATCH_QUEUE_SERIAL);
    dispatch_set_target_queue(self.taskQueue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
    self.semaphore = dispatch_semaphore_create(1);
    
    dispatch_sync(self.taskQueue, ^{
        _stillImageSource = [[GPUImageUIElement alloc] initWithView:[UIApplication sharedApplication].delegate.window];
        _filter = [[GPUImageGaussianBlurFilter alloc] init];
        _filter.blurRadiusInPixels = kDefaultBlurRadius;
        
        [_stillImageSource addTarget:_filter];
    });
}

-(void)initTintView
{
    _tintView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _tintView.alpha = 0.1;
    _tintView.backgroundColor = [UIColor lightGrayColor];
    [blurWindow addSubview:_tintView];
}

-(void)orientationChange:(NSNotification*)notification
{
    [self updateSubviewOrientations:[[notification.userInfo objectForKey:UIApplicationStatusBarOrientationUserInfoKey] intValue]];
}

-(CGRect)blurRect:(CGRect)rect
{
    [self.activeBlurAreas addObject:[NSValue valueWithCGRect:rect]];
    
    [self updateMaskedAreas];
    
    if(self.blurTimer == nil && self.blurInterval != kLiveBlurIntervalStatic){
        [self startTimer];
    }
    
    return rect;
}

-(void)startTimer
{
    dispatch_sync(self.taskQueue, ^{
        self.blurTimer = [NSTimer scheduledTimerWithTimeInterval:self.blurInterval target:self selector:@selector(updateBlur) userInfo:nil repeats:YES];
    });
}

-(void)stopBlurringRect:(CGRect)rect
{
    [self.activeBlurAreas removeObject:[NSValue valueWithCGRect:rect]];
    
    if(self.activeBlurAreas.count == 0){
        [self.blurTimer invalidate];
        self.blurTimer = nil;
    }
    
    [self updateMaskedAreas];
}

-(void)addSubview:(UIView *)view
{
    [blurWindow addSubview:view];
    
    [self updateSubviewOrientations:[UIApplication sharedApplication].statusBarOrientation];
}

-(void)updateMaskedAreas
{
    CGMutablePathRef path = CGPathCreateMutable();
    
    CGPathMoveToPoint(path, NULL, 0, 0);
    
    for(int i = 0; i < self.activeBlurAreas.count; i++){
        CGRect frame = [self.activeBlurAreas[i] CGRectValue];
        CGPathAddRect(path, NULL, frame);
    }
    
    CGPathCloseSubpath(path);
    
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.path = path;
    CGPathRelease(path);
    
    blurWindow.layer.mask = maskLayer;
}

-(void)updateSubviewOrientations:(UIInterfaceOrientation)orientation
{
    CGAffineTransform transform;
    switch (orientation) {
        case UIInterfaceOrientationLandscapeLeft:
            transform = CGAffineTransformMakeRotation(3*M_PI_2);
            break;
        case UIInterfaceOrientationLandscapeRight:
            transform = CGAffineTransformMakeRotation(M_PI_2);
            break;
        case UIInterfaceOrientationPortrait:
            transform = CGAffineTransformMakeRotation(0);
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            transform = CGAffineTransformMakeRotation(M_PI);
            break;
    }
    
    for(UIView* view in blurWindow.subviews){
        view.transform = transform;
    }
    
    self.tintView.frame = [UIScreen mainScreen].bounds;
    self.blurredImageView.frame = [UIScreen mainScreen].bounds;
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
    UIImage *processedImage = [self.filter imageFromCurrentlyProcessedOutput];
    
    dispatch_semaphore_signal(self.semaphore);
    
    CABasicAnimation *crossFade = [CABasicAnimation animationWithKeyPath:@"contents"];
    crossFade.duration = 0.1;
    crossFade.fromValue = (__bridge id)(self.blurredImageView.image.CGImage);
    crossFade.toValue = (__bridge id)(processedImage.CGImage);
    
    [self.blurredImageView.layer addAnimation:crossFade forKey:kCATransition];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.blurredImageView setImage:processedImage];
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
    self.tintView.backgroundColor = tintColor;
}

-(UIColor*)tintColor
{
    return self.tintView.backgroundColor;
}

-(void)dealloc
{
    [self.blurTimer invalidate];
    [self.blurredImageView removeFromSuperview];
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
