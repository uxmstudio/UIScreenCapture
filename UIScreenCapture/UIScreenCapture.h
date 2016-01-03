//
//  UIScreenCapture.h
//  UIScreenCapture
//
//  Created by Chris Anderson on 12/28/15.
//  Copyright © 2015 UXM Studio. All rights reserved.
//

@import AVFoundation;
@import Foundation;
@import UIKit;

typedef void(^UIScreenCaptureCompletion)(NSURL *fileURL);

@interface UIScreenCapture : NSObject

@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, strong) AVAssetWriterInput *writerInput;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *bufferAdapter;
@property (nonatomic, strong) NSDictionary *videoSettings;
@property (nonatomic, assign) CMTime frameTime;
@property (nonatomic, strong) NSURL *fileURL;
@property (nonatomic) CGFloat height;
@property (nonatomic) CGFloat width;
@property (nonatomic) CGFloat frameRate;
@property (nonatomic, strong) UIView *view;
@property (nonatomic, copy) UIScreenCaptureCompletion completionBlock;

- (void)createVideoFromImageURLs:(NSArray *)urls withCompletion:(UIScreenCaptureCompletion)completion;
- (void)createVideoFromImages:(NSArray *)images withCompletion:(UIScreenCaptureCompletion)completion;

- (void)startRecording;
- (void)stopRecording;

+ (NSDictionary *)videoSettingsWithSize:(CGSize)size;
+ (UIImage *)takeSnapshot;
+ (UIImage *)takeSnapshotWithSize:(CGSize)size;
+ (UIImage *)takeSnapshotWithSize:(CGSize)size view:(UIView *)view;
+ (NSData *)takeSnapshotGetJPEG;
+ (NSData *)takeSnapshotGetJPEG:(CGFloat)quality;
+ (NSData *)takeSnapshotGetJPEG:(CGFloat)quality size:(CGSize)size;
+ (NSData *)takeSnapshotGetJPEG:(CGFloat)quality size:(CGSize)size view:(UIView *)view;

@end