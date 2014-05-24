/***********************************************************************************
 *
 * MSBlurWindow.m
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

#import "MSBlurWindow.h"

@implementation MSBlurWindow

-(BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    CGSize size = self.bounds.size;
    
    // Convert point to correct orientation
    switch ([UIApplication sharedApplication].statusBarOrientation) {
        case UIInterfaceOrientationLandscapeLeft:
            point = CGPointMake(size.height - point.y, point.x);
            break;
        case UIInterfaceOrientationLandscapeRight:
            point = CGPointMake(point.y, size.width - point.x);
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            point = CGPointMake(size.width - point.x, size.height - point.y);
            break;
        case UIInterfaceOrientationPortrait:
            break;
    }
    return [self.rootViewController.view pointInside:point withEvent:event];
}

@end
