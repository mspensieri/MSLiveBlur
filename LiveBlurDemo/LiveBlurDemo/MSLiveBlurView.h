//
//  MSLiveBlurView.h
//  SupportKit
//
//  Created by Michael Spensieri on 3/4/14.
//  Copyright (c) 2014 Radialpoint. All rights reserved.
//

#import <UIKit/UIKit.h>

extern const int kLiveBlurIntervalStatic;

@interface MSLiveBlurView : NSObject

- (id)initWithFrame:(CGRect)frame;
- (id)initWithFrame:(CGRect)frame blurInterval:(double)interval radius:(int)radius;

-(void)forceUpdateBlur;

@end
