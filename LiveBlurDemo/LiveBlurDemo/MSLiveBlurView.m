//
//  MSLiveBlurView.m
//  SupportKit
//
//  Created by Michael Spensieri on 3/4/14.
//  Copyright (c) 2014 Radialpoint. All rights reserved.
//

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
    }
    return self;
}

-(void)initGPUImageElements
{
    _stillImageSource = [[GPUImageUIElement alloc] initWithView:[UIApplication sharedApplication].delegate.window];
    _filter = [[GPUImageGaussianBlurFilter alloc] init];
    _filter.blurRadiusInPixels = kDefaultBlurRadius;
    
    [_stillImageSource addTarget:_filter];
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
        self.blurTimer = [NSTimer scheduledTimerWithTimeInterval:self.blurInterval target:self selector:@selector(updateBlur) userInfo:nil repeats:YES];
    }
    
    return rect;
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
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self updateBlur];
    });
}

-(void)updateBlur
{
    @synchronized(self){
        [self.stillImageSource update];
    }
    UIImage *processedImage = [self.filter imageFromCurrentlyProcessedOutput];
    
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

@end
