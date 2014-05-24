//
//  MSDemoViewController.m
//  LiveBlurDemo
//
//  Created by Michael Spensieri on 3/21/14.
//  Copyright (c) 2014 Michael Spensieri. All rights reserved.
//

#import "MSDemoViewController.h"
#import "time.h"
#import "MSLiveBlur.h"

static const CGFloat kTimerInterval = 0.3;
static const CGFloat kSliderWidth = 200;

@interface MSDemoViewController()

@property NSMutableArray* textLabels;
@property CGRect movableRect;
@property UISlider* slider;
@property NSTimer* textColorTimer;

@end

@implementation MSDemoViewController

- (instancetype)init
{
    self = [super init];
    if (self) {
        srand((unsigned int)time(NULL));
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIPanGestureRecognizer* panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPan:)];
    [self.view addGestureRecognizer:panGesture];

    [self initTextLabels];
    [self initSlider];
    [self initHiddenTextLabel];
    [self configureBlur];
}

-(void)configureBlur
{
    [MSLiveBlur sharedInstance].isStatic = NO;
    
    self.movableRect = CGRectMake(0, 0, 100, 100);
    [[MSLiveBlur sharedInstance] blurRect:self.movableRect];
    
    CGRect stillRect = CGRectMake(220, 340, 100, 100);
    [[MSLiveBlur sharedInstance] blurRect:stillRect];
}

-(void)initTextLabels
{
    self.textLabels = [NSMutableArray new];
    
    NSArray* labelTitles = [@"Drag to move the blurred area. Slide to change blur radius. Yay!" componentsSeparatedByString:@" "];
    
    for(int i = 0; i < labelTitles.count; i++){
        UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(20 + 110*(i % 3), 40 + 110*(i / 3), 500, 100)];
        label.text = labelTitles[i];
        label.font = [UIFont systemFontOfSize:20];
        [label sizeToFit];
        
        [self.view addSubview:label];
        
        [self.textLabels addObject:label];
    }
    
    self.textColorTimer = [NSTimer scheduledTimerWithTimeInterval:kTimerInterval target:self selector:@selector(changeColors) userInfo:nil repeats:YES];
}

-(void)initSlider
{
    self.slider = [[UISlider alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 50, kSliderWidth, 40)];
    self.slider.center = CGPointMake(self.view.center.x, self.slider.center.y);
    self.slider.value = 0.5;
    [self.slider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.slider];
}

-(void)initHiddenTextLabel
{
    UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 30, 200, 30)];
    label.text = @"You Found it!";
    label.font = [UIFont systemFontOfSize:20];
    [label sizeToFit];
    
    [[MSLiveBlur sharedInstance] addSubview:label];
    
    [self.textLabels addObject:label];
}

-(void)sliderValueChanged:(UISlider *)sender
{
    [MSLiveBlur sharedInstance].blurRadius = 10 * sender.value;
}

-(void)onPan:(UIPanGestureRecognizer*)sender
{
    if(sender.state == UIGestureRecognizerStateChanged){
        CGPoint translation = [sender translationInView:sender.view];
        [[MSLiveBlur sharedInstance] stopBlurringRect:self.movableRect];
        
        self.movableRect = CGRectOffset(self.movableRect, translation.x, translation.y);
        [[MSLiveBlur sharedInstance] blurRect:self.movableRect];
        [sender setTranslation:CGPointZero inView:sender.view];
    }
}

-(void)changeColors
{
    for(UILabel* label in self.textLabels){
        label.textColor = [UIColor colorWithRed:[self randomFloat] green:[self randomFloat] blue:[self randomFloat] alpha:1.0];
    }
}

-(float)randomFloat
{
    return (float)rand() / (float)RAND_MAX;
}

-(void)dealloc
{
    [self.textColorTimer invalidate];
}

@end
