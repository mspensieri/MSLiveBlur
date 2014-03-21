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

@interface MSMainViewController()

@property NSMutableArray* textLabels;
@property MSLiveBlurView* b;

@end

@implementation MSMainViewController


- (void)viewDidLoad
{
    [super viewDidLoad];

    self.textLabels = [NSMutableArray new];
    
    NSArray* labelTitles = [@"Hi My Name Is Mike, do you like live blur?" componentsSeparatedByString:@" "];
    
    for(int i = 0; i < labelTitles.count; i++){
        UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(20 + 90*(i % 3), 40 + 110*(i / 3), 500, 100)];
        label.text = labelTitles[i];
        label.font = [UIFont systemFontOfSize:40];
        [label sizeToFit];
        
        [self.view addSubview:label];
        
        [self.textLabels addObject:label];
    }
    
    self.b = [[MSLiveBlurView alloc] initWithFrame:self.view.bounds blurInterval:kLiveBlurIntervalStatic radius:5];
    
   [NSTimer scheduledTimerWithTimeInterval:kTimerInterval target:self selector:@selector(changeColor) userInfo:nil repeats:YES];
    
    srand(time(NULL));
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
