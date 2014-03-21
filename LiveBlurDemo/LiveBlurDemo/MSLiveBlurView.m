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

@property GPUImageUIElement* stillImageSource;
@property GPUImageGaussianBlurFilter* filter;
@property NSTimer* blurTimer;

@end

@implementation MSLiveBlurView

@synthesize frame = _frame;

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
        
        self.stillImageSource = [[GPUImageUIElement alloc] initWithView:[UIApplication sharedApplication].delegate.window];
        self.filter = [[GPUImageGaussianBlurFilter alloc] init];
        self.filter.blurRadiusInPixels = radius;
        
        [self.stillImageSource addTarget:self.filter];
        
        [self setFrame:frame];
        
        if(interval != kLiveBlurIntervalStatic){
            self.blurTimer = [NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(forceUpdateBlur) userInfo:nil repeats:YES];
        }
    }
    return self;
}

-(void)setFrame:(CGRect)frame
{
    _frame = frame;
    
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    CGRect maskRect = _frame;
    CGPathRef path = CGPathCreateWithRect(maskRect, NULL);
    maskLayer.path = path;
    CGPathRelease(path);
    
    self.blurredImageView.layer.mask = maskLayer;
}

-(CGRect)frame
{
    return _frame;
}

-(void)forceUpdateBlur
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        @synchronized(self){
            [self.stillImageSource update];
        }
        UIImage *processedImage = [self.filter imageFromCurrentlyProcessedOutput];
        
        CABasicAnimation *crossFade = [CABasicAnimation animationWithKeyPath:@"contents"];
        crossFade.duration = 0.5;
        crossFade.fromValue = (__bridge id)(self.blurredImageView.image.CGImage);
        crossFade.toValue = (__bridge id)(processedImage.CGImage);
        
        [self.blurredImageView.layer addAnimation:crossFade forKey:kCATransition];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.blurredImageView setImage:processedImage];
        });
    });
}

-(void)dealloc
{
    [self.blurTimer invalidate];
    [self.blurredImageView removeFromSuperview];
}

@end
