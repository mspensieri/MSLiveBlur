/***********************************************************************************
 *
 * MSViewController.m
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

#import "MSViewController.h"
#import "MSImageView.h"

@implementation MSViewController

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self initImageView];
        [self initTintView];
    }
    return self;
}

-(void)loadView
{
    self.view = [[MSViewControllerView alloc] init];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor clearColor];
    
    [self.view addSubview:self.imageView];
    [self.view addSubview:self.tintView];
}

-(void)initImageView
{
    self.imageView = [[MSImageView alloc] init];
}

-(void)initTintView
{
    self.tintView = [[UIView alloc] init];
    self.tintView.alpha = 0.1;
    self.tintView.backgroundColor = [UIColor lightGrayColor];
}

-(void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    self.imageView.frame = self.view.bounds;
    self.tintView.frame = self.view.bounds;
}

@end
