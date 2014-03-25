//
//  MSMainViewController.m
//  LiveBlurDemo
//
//  Created by Michael Spensieri on 3/21/14.
//  Copyright (c) 2014 Michael Spensieri. All rights reserved.
//

#import "MSMainViewController.h"
#import "time.h"
#import "MSLiveBlurView.h"

static const CGFloat kTimerInterval = 0.3;
static const CGFloat kSliderWidth = 200;

@interface MSMainViewController()

@property NSMutableArray* textLabels;
@property CGRect dynamicRect;
@property UISlider* slider;

@end

@implementation MSMainViewController


- (void)viewDidLoad
{
    [super viewDidLoad];

    [self initTextLabels];
    [self initSlider];
    [self initHiddenTextLabel];
    
    self.dynamicRect = [[MSLiveBlurView sharedInstance] blurRect:CGRectMake(0, 0, 100, 100)];
    
    CGRect staticRect = CGRectMake(220, 340, 100, 100);
    [[MSLiveBlurView sharedInstance] blurRect:staticRect];
    
   [NSTimer scheduledTimerWithTimeInterval:kTimerInterval target:self selector:@selector(changeColor) userInfo:nil repeats:YES];
    
    UIPanGestureRecognizer* panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPan:)];
    [self.view addGestureRecognizer:panGesture];
    
    srand(time(NULL));
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
    
    [[MSLiveBlurView sharedInstance] addSubview:label];
    
    [self.textLabels addObject:label];
}

-(void)sliderValueChanged:(UISlider *)sender {
    [MSLiveBlurView sharedInstance].blurRadius = 10 * sender.value;
}

-(void)onPan:(UIPanGestureRecognizer*)sender
{
    if(sender.state == UIGestureRecognizerStateChanged){
        CGPoint translation = [sender translationInView:sender.view];
        [[MSLiveBlurView sharedInstance] stopBlurringRect:self.dynamicRect];
        self.dynamicRect = [[MSLiveBlurView sharedInstance] blurRect:CGRectOffset(self.dynamicRect, translation.x, translation.y)];
        [sender setTranslation:CGPointZero inView:sender.view];
    }
}

-(void)changeColor
{
    for(UILabel* label in self.textLabels){
        label.textColor = [UIColor colorWithRed:[self randomFloat] green:[self randomFloat] blue:[self randomFloat] alpha:1.0];
    }
}

-(float)randomFloat
{
    return (float)rand() / (float)RAND_MAX;
}

@end
