//
//  UIScreenCapture.m
//  UIScreenCapture
//
//  Created by Chris Anderson on 12/28/15.
//  Copyright © 2015 UXM Studio. All rights reserved.
//

#import "UIScreenCapture.h"

typedef UIImage *(^UIScreenCaptureUIImageExtractor)(NSObject* inputObject);

@interface UIScreenCapture ()

@property BOOL recording;

@end

@implementation UIScreenCapture

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        self.width = screenRect.size.width;
        self.height = screenRect.size.height;
        self.frameRate = 30.0;
    }
    return self;
}

- (void)prepareCapture
{
    NSError *error;
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths firstObject];
    NSString *tempPath = [documentsDirectory stringByAppendingFormat:@"/export.mov"];
    
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:tempPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:tempPath error:&error];
        if (error) {
            NSLog(@"Error: %@", error.debugDescription);
        }
    }
    
    _fileURL = [NSURL fileURLWithPath:tempPath];
    _assetWriter = [[AVAssetWriter alloc] initWithURL:self.fileURL
                                             fileType:AVFileTypeQuickTimeMovie error:&error];
    if (error) {
        NSLog(@"Error: %@", error.debugDescription);
    }
    NSParameterAssert(self.assetWriter);
    
    _videoSettings = [UIScreenCapture videoSettingsWithSize:CGSizeMake(self.width, self.height)];
    
    _writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                                      outputSettings:_videoSettings];
    NSParameterAssert(self.writerInput);
    NSParameterAssert([self.assetWriter canAddInput:self.writerInput]);
    
    [self.assetWriter addInput:self.writerInput];
    
    NSDictionary *bufferAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithInt:kCVPixelFormatType_32ARGB], kCVPixelBufferPixelFormatTypeKey, nil];
    
    _bufferAdapter = [[AVAssetWriterInputPixelBufferAdaptor alloc] initWithAssetWriterInput:self.writerInput sourcePixelBufferAttributes:bufferAttributes];
    _frameTime = CMTimeMake(1, self.frameRate);
}

- (void)createVideoFromImageURLs:(NSArray *)urls withCompletion:(UIScreenCaptureCompletion)completion;
{
    [self createVideoFromSource:urls extractor:^UIImage *(NSObject *inputObject) {
        return [UIImage imageWithData:[NSData dataWithContentsOfURL:((NSURL *)inputObject)]];
    } withCompletion:completion];
}

- (void)createVideoFromImages:(NSArray *)images withCompletion:(UIScreenCaptureCompletion)completion;
{
    [self createVideoFromSource:images extractor:^UIImage *(NSObject *inputObject) {
        return (UIImage *)inputObject;
    } withCompletion:completion];
}

- (void)createVideoFromSource:(NSArray *)images extractor:(UIScreenCaptureUIImageExtractor)extractor withCompletion:(UIScreenCaptureCompletion)completion;
{
    
    [self prepareCapture];
    
    self.completionBlock = completion;
    
    [self.assetWriter startWriting];
    [self.assetWriter startSessionAtSourceTime:kCMTimeZero];
    
    dispatch_queue_t mediaInputQueue = dispatch_queue_create("mediaInputQueue", NULL);
    
    __block NSInteger i = 0;
    
    NSInteger frameNumber = [images count];
    
    [self.writerInput requestMediaDataWhenReadyOnQueue:mediaInputQueue usingBlock:^{
        while (YES){
            if (i >= frameNumber) {
                break;
            }
            if ([self.writerInput isReadyForMoreMediaData]) {
                UIImage *img = extractor([images objectAtIndex:i]);
                if (img == nil) {
                    i++;
                    NSLog(@"Warning: could not extract one of the frames");
                    continue;
                }
                CVPixelBufferRef sampleBuffer = [self newPixelBufferFromCGImage:[img CGImage]];
                
                if (sampleBuffer) {
                    if (i == 0) {
                        [self.bufferAdapter appendPixelBuffer:sampleBuffer withPresentationTime:kCMTimeZero];
                    }
                    else {
                        CMTime lastTime = CMTimeMake(i-1, self.frameTime.timescale);
                        CMTime presentTime = CMTimeAdd(lastTime, self.frameTime);
                        [self.bufferAdapter appendPixelBuffer:sampleBuffer withPresentationTime:presentTime];
                    }
                    CFRelease(sampleBuffer);
                    i++;
                }
            }
        }
        
        [self.writerInput markAsFinished];
        [self.assetWriter finishWritingWithCompletionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                self.completionBlock(self.fileURL);
            });
        }];
        
        CVPixelBufferPoolRelease(self.bufferAdapter.pixelBufferPool);
    }];
}


- (CVPixelBufferRef)newPixelBufferFromCGImage:(CGImageRef)image
{
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    
    CVPixelBufferRef pxbuffer = NULL;
    
    CGFloat frameWidth = [[self.videoSettings objectForKey:AVVideoWidthKey] floatValue];
    CGFloat frameHeight = [[self.videoSettings objectForKey:AVVideoHeightKey] floatValue];
    
    
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                          frameWidth,
                                          frameHeight,
                                          kCVPixelFormatType_32ARGB,
                                          (__bridge CFDictionaryRef) options,
                                          &pxbuffer);
    
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    if (status != kCVReturnSuccess && pxbuffer == NULL) {
        [NSException raise:@"No Pixel Buffer" format:@"There was an error creating the pixel buffer."];
    }
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef context = CGBitmapContextCreate(pxdata,
                                                 frameWidth,
                                                 frameHeight,
                                                 8,
                                                 4 * frameWidth,
                                                 rgbColorSpace,
                                                 (CGBitmapInfo)kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);
    CGContextConcatCTM(context, CGAffineTransformIdentity);
    CGContextDrawImage(context, CGRectMake(0,
                                           0,
                                           CGImageGetWidth(image),
                                           CGImageGetHeight(image)),
                       image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}



- (void)startRecording
{
    
    [self prepareCapture];
    self.recording = YES;
    
    [self.assetWriter startWriting];
    [self.assetWriter startSessionAtSourceTime:kCMTimeZero];
    
    CGSize size = CGSizeMake(self.width, self.height);
    
    dispatch_queue_t mediaInputQueue = dispatch_queue_create("mediaInputQueue", NULL);
    
    __block NSInteger i = 0;
    
    [self.writerInput requestMediaDataWhenReadyOnQueue:mediaInputQueue usingBlock:^{
        while (YES) {
            if (!self.recording) {
                break;
            }
            
            NSDate *start = [NSDate date];
            if ([self.writerInput isReadyForMoreMediaData]) {
                UIImage *img = [UIScreenCapture takeSnapshotWithSize:size];
                if (img == nil) {
                    i++;
                    NSLog(@"Warning: could not extract one of the frames");
                    continue;
                }
                CVPixelBufferRef sampleBuffer = [self newPixelBufferFromCGImage:[img CGImage]];
                
                if (sampleBuffer) {
                    if (i == 0) {
                        [self.bufferAdapter appendPixelBuffer:sampleBuffer withPresentationTime:kCMTimeZero];
                    }
                    else {
                        CMTime lastTime = CMTimeMake(i-1, self.frameTime.timescale);
                        CMTime presentTime = CMTimeAdd(lastTime, self.frameTime);
                        [self.bufferAdapter appendPixelBuffer:sampleBuffer withPresentationTime:presentTime];
                    }
                    CFRelease(sampleBuffer);
                    i++;
                }
            }
            NSLog(@"WRITE FRAME %@", @(i));
            
            CGFloat processingSeconds = [[NSDate date] timeIntervalSinceDate:start];
            CGFloat delayRemaining = (1.0 / self.frameRate) - processingSeconds;
            
            [NSThread sleepForTimeInterval:delayRemaining];
        }
        
        [self.writerInput markAsFinished];
        [self.assetWriter finishWritingWithCompletionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                self.completionBlock(self.fileURL);
            });
        }];
        
        CVPixelBufferPoolRelease(self.bufferAdapter.pixelBufferPool);
    }];
}


- (void)stopRecording
{
    self.recording = NO;
}

#pragma mark - Static methods
+ (NSDictionary *)videoSettingsWithSize:(CGSize)size
{
    
    if ((int)size.width % 16 != 0 ) {
        NSLog(@"Warning: video settings width must be divisible by 16.");
    }
    
    NSDictionary *videoSettings = @{AVVideoCodecKey : AVVideoCodecH264,
                                    AVVideoWidthKey : [NSNumber numberWithInt:(int)size.width],
                                    AVVideoHeightKey : [NSNumber numberWithInt:(int)size.height]};
    
    return videoSettings;
}


+ (UIImage *)takeSnapshot
{
    UIWindow *window = [self findKeyWindow];
    
    CGSize windowSize = window.bounds.size;
    
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
        UIGraphicsBeginImageContextWithOptions(windowSize, NO, 1.0);
    }
    else {
        UIGraphicsBeginImageContext(windowSize);
    }
    
    [window.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

+ (UIImage *)takeSnapshotWithSize:(CGSize)size
{
    UIWindow *window = [self findKeyWindow];
    
    CGSize windowSize = window.bounds.size;
    
    if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) {
        UIGraphicsBeginImageContextWithOptions(windowSize, NO, 1.0);
    }
    else {
        UIGraphicsBeginImageContext(windowSize);
    }
    
    [window.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    UIGraphicsBeginImageContext(size);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return newImage;
}

+ (NSData *)takeSnapshotGetJPEG
{
    return [self takeSnapshotGetJPEG:.7];
}

+ (NSData *)takeSnapshotGetJPEG:(CGFloat)quality
{
    return UIImageJPEGRepresentation([self takeSnapshot], quality);
}

+ (NSData *)takeSnapshotGetJPEG:(CGFloat)quality size:(CGSize)size
{
    return UIImageJPEGRepresentation([self takeSnapshotWithSize:size], quality);
}

+ (UIWindow *)findKeyWindow
{
    UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
    if (![NSStringFromClass([keyWindow class]) isEqualToString:@"UIWindow"]) {
        
        NSArray *windows = [UIApplication sharedApplication].windows;
        for (UIWindow *window in windows) {
            if ([NSStringFromClass([window class]) isEqualToString:@"UIWindow"]) {
                keyWindow = window;
                break;
            }
        }
    }
    return keyWindow;
}

@end