# UIScreenCapture

[![Version](https://img.shields.io/cocoapods/v/UIScreenCapture.svg?style=flat)](http://cocoapods.org/pods/UIScreenCapture)
[![License](https://img.shields.io/cocoapods/l/UIScreenCapture.svg?style=flat)](http://cocoapods.org/pods/UIScreenCapture)
[![Platform](https://img.shields.io/cocoapods/p/UIScreenCapture.svg?style=flat)](http://cocoapods.org/pods/UIScreenCapture)
![](https://img.shields.io/badge/Supported-iOS8-4BC51D.svg?style=flat-square)

Simply capture screenshots and create screen recordings from code.


# Installation
## Cocoapods
UIScreenCapture is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "UIScreenCapture", '~> 0.0.4'
```

# Usage
## Capture Screen Recording
```objective-c
// Initialize the screen capture
UIScreenCapture *screenCapture = [UIScreenCapture new];
screenCapture.height = 480.0;
screenCapture.width = 640.0;
screenCapture.frameRate = 15.0;
screenCapture.completionBlock = ^(NSURL *fileURL) {
    NSLog(@"Finished! Video located at: %@", fileURL);
};

// Begin screen capture
[screenCapture startRecording];

dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC);
dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
    
    // Stop screen capture after ten seconds
    [screenCapture stopRecording];
});
```

## Take Screenshot
```objective-c
[UIScreenCapture takeSnapshot];
```

# Author
Chris Anderson:
- chris@uxmstudio.com
- [Home Page](http://uxmstudio.com)

# License

UIScreenCapture is available under the MIT license. See the LICENSE file for more info.