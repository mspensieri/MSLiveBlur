MSLiveBlur
==========

![Screenshot](https://raw.githubusercontent.com/mspensieri/MSLiveBlur/master/screenshot.png)

The MSLiveBlurView dynamically blurs the content on the screen and updates at the given interval. 
Subviews will not be blurred but will instead appear on top of the blurred area.

I use a condensed version of [GPUImage](https://github.com/BradLarson/GPUImage) to do the blurring.

*Note:* Performance on the simulator is abysmal for blur radius >5, try it on an actual device - it's much faster!

# Usage

#### For live blur:

    #import "MSLiveBlur.h"
    UIView* someView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    [[MSLiveBlurView sharedInstance] blurRect:someView.frame];
    [[MSLiveBlurView sharedInstance] addSubview:view];

#### For static blur:

    #import "MSLiveBlur.h"
    UIView* someView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
    [[MSLiveBlurView sharedInstance] setBlurInterval:kLiveBlurIntervalStatic];
    [[MSLiveBlurView sharedInstance] blurRect:someView.frame];
    [[MSLiveBlurView sharedInstance] addSubview:view];

then, to update manually:

    [[MSLiveBlurView sharedInstance] forceUpdateBlur];

#### A note about landscape:

This library uses an additional UIWindow to host the blur and its subviews.
UIWindow does not change bounds or orientation when rotating to landscape mode, so the frames you supply to +blurRect must be specified as if the device were in portrait.
I'm working on a way to make this easier to deal with.

# Todo:
* Figure out how to only blur views beneath so as not to require a new window
* Different shapes (ex: rounded corners)
* Improve landscape

# Done
* Live blur with variable interval
* Live blur appears on top of the application and blurs underneath
* Specify the size of the blurred area so it does not blur the entire screen (i.e. actually use the given frame)
* Tint color
* Support multiple areas at once
* Allow subviews on top of the blurred area
* Landscape


Send me a message if you use this lib and you want your app listed here!