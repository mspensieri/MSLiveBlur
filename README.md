MSLiveBlur
==========

The MSLiveBlurView dynamically blurs the content on the screen and updates at the given interval.
I use a condensed version of [GPUImage](https://github.com/BradLarson/GPUImage) to do the blurring.

# Usage

#### For live blur:

    \#import "MSLiveBlur.h"
    MSLiveBlurView* blurView = [[MSLiveBlurView alloc] initWithFrame:self.view.bounds];

#### For static blur:

    \#import "MSLiveBlur.h"
    MSLiveBlurView* blurView = [[MSLiveBlurView alloc] initWithFrame:self.view.bounds blurInterval:kLiveBlurIntervalStatic radius:5];

then, to update manually:

    [blurView forceUpdateBlur];

# Todo:
* Specify the size of the blurred area so it does not blur the entire screen (i.e. actually use the given frame)
* Figure out how to only blur views beneath so as not to require a new window
* Support multiple areas at once

# Done
* Live blur with variable interval
* Live blur appears on top of the application and blurs underneath