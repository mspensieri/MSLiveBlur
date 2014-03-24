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

@end

@implementation MSLiveBlurView

@synthesize frame = _frame;
@synthesize tintColor = _tintColor;

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

-(id)initWithFrame:(CGRect)frame
{
    return [self initWithFrame:frame blurInterval:kDefaultBlurInterval radius:kDefaultBlurRadius];
}

- (id)initWithFrame:(CGRect)frame blurInterval:(double)interval radius:(int)radius
{
    self = [super init];
    if (self) {
        [self.class ensureWindowExists];
        
        self.blurredImageView = [[UIImageView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        [blurWindow addSubview:self.blurredImageView];
        
        self.tintView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
        self.tintView.alpha = 0.1;
        self.tintView.backgroundColor = [UIColor lightGrayColor];
        [blurWindow addSubview:self.tintView];
        
        [self initGPUImageElementsWithBlurRadius:radius];
        [self setFrame:frame];
        
        if(interval != kLiveBlurIntervalStatic){
            self.blurTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(updateBlur) userInfo:nil repeats:YES];
        }
    }
    return self;
}

-(void)initGPUImageElementsWithBlurRadius:(double)radius
{
    self.stillImageSource = [[GPUImageUIElement alloc] initWithView:[UIApplication sharedApplication].delegate.window];
    self.filter = [[GPUImageGaussianBlurFilter alloc] init];
    self.filter.blurRadiusInPixels = radius;
    
    [self.stillImageSource addTarget:self.filter];
}

-(void)setFrame:(CGRect)frame
{
    _frame = frame;
    
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    CGRect maskRect = _frame;
    CGPathRef path = CGPathCreateWithRect(maskRect, NULL);
    maskLayer.path = path;
    CGPathRelease(path);
    
    blurWindow.layer.mask = maskLayer;
}

-(CGRect)frame
{
    return _frame;
}

-(void)setTintColor:(UIColor *)tintColor
{
    _tintColor = tintColor;
    
    self.tintView.backgroundColor = tintColor;
}

-(UIColor*)tintColor
{
    return _tintColor;
}

-(void)setBlurRadius:(double)blurRadius
{
    self.filter.blurRadiusInPixels = blurRadius;
}

-(double)blurRadius
{
    return self.filter.blurRadiusInPixels;
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

-(void)dealloc
{
    [self.blurTimer invalidate];
    [self.blurredImageView removeFromSuperview];
}

@end
