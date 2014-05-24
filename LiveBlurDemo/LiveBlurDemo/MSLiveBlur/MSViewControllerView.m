/***********************************************************************************
 *
 * MSViewControllerView.m
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

#import "MSViewControllerView.h"

@interface MSViewControllerView()

@property NSMutableArray* activeBlurAreas;

@end

@implementation MSViewControllerView

-(id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self){
        _activeBlurAreas = [NSMutableArray new];
    }
    return self;
}

-(BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    for(NSValue* value in self.activeBlurAreas){
        CGRect frame = [value CGRectValue];
        
        if(CGRectContainsPoint(frame, point)){
            return YES;
        }
    }
    
    return NO;
}

-(BOOL)hasBlurredArea
{
    return self.activeBlurAreas.count > 0;
}

-(void)blurRect:(CGRect)rect
{
    [self.activeBlurAreas addObject:[NSValue valueWithCGRect:rect]];
    
    [self updateMaskedAreas];
}

-(void)stopBlurringRect:(CGRect)rect
{
    [self.activeBlurAreas removeObject:[NSValue valueWithCGRect:rect]];
    
    [self updateMaskedAreas];
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
    
    self.layer.mask = maskLayer;
}

@end
