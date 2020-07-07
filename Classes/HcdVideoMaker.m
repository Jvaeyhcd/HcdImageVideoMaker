//
//  HcdVideoMaker.m
//  HcdImageVideoMaker
//
//  Created by Salvador on 2020/7/4.
//  Copyright © 2020 Salvador. All rights reserved.
//

#import "HcdVideoMaker.h"
#import "HcdFileManager.h"
#import <AVFoundation/AVFoundation.h>
#import "HcdVideoExporter.h"
#import "UIImage+HAdd.h"

#define SCREEN_WIDTH [UIScreen mainScreen].bounds.size.width
#define SCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height

@interface HcdVideoMaker ()

@property (nonatomic, strong) AVAssetWriter *videoWriter;
@property (nonatomic, strong) HcdVideoExporter *videoExporter;
@property (nonatomic, assign) NSInteger timescale;
@property (nonatomic, assign) double transitionRate;
@property (nonatomic, assign) BOOL isMixed;
@property (nonatomic, assign) BOOL isMovement;
@property (nonatomic, assign) CGFloat fadeOffset;
@property (nonatomic) dispatch_queue_t mediaInputQueue;
@property (nonatomic, assign) CVPixelBufferLockFlags flags;
@property (nonatomic, assign) float exportTimeRate;
@property (nonatomic, assign) float waitTranstionTimeRate;;
@property (nonatomic, assign) float transitionTimeRate;
@property (nonatomic, assign) float writerTimeRate;
@property (nonatomic, assign) float currentProgress;
@end

@implementation HcdVideoMaker

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self initData];
    }
    return self;
}

- (instancetype)initWithImages:(NSMutableArray *)images transition:(ImageTransition)transition
{
    self = [super init];
    if (self) {
        [self initData];
        self.images = images;
        self.transition = transition;
        self.isMovement = NO;
    }
    return self;
}

- (instancetype)initWithImages:(NSMutableArray *)images movement:(ImageMovement)movement
{
    self = [super init];
    if (self) {
        [self initData];
        self.images = images;
        self.movement = movement;
        self.isMovement = YES;
    }
    return self;
}

/// 初始化数据
- (void)initData {
    self.images = [NSMutableArray array];
    self.transition = ImageTransitionNone;
    self.movement = ImageMovementNone;
    self.movementFade = MovementFadeUpLeft;
    self.contentMode = UIViewContentModeScaleAspectFill;
    
    self.quarity = kCGInterpolationLow;
    self.size = CGSizeMake(640, 640 * SCREEN_HEIGHT / SCREEN_WIDTH);
    self.definition = 1;
    self.frameDuration = 2;
    self.transitionDuration = 1;
    self.transitionFrameCount = 60;
    self.framesToWaitBeforeTransition = 30;
    
    self.videoExporter = [[HcdVideoExporter alloc] init];
    self.timescale = 10000000;
    self.transitionRate = 1;
    self.isMixed = NO;
    self.isMovement = NO;
    self.fadeOffset = SCREEN_WIDTH / 4;
    self.mediaInputQueue = dispatch_queue_create("mediaInputQueue", DISPATCH_QUEUE_SERIAL);
    self.flags = 0;
    
    self.exportTimeRate = 0.0;
    self.waitTranstionTimeRate = 0;
    self.transitionTimeRate = 0;
    self.writerTimeRate = 0.9;
}

- (HcdVideoMaker *)exportVideo:(AVURLAsset *)audio audioTimeRange:(CMTimeRange)audioTimeRange completed:(CompletedCombineBlock)completed {
    
    [self createDirectory];
    self.currentProgress = 0.0;
    __weak typeof(self) weakSelf = self;
    [self combineVideo:^(BOOL success, NSURL * _Nullable videoURL) {
        if (success && videoURL != nil) {
            AVURLAsset *video = [AVURLAsset assetWithURL:videoURL];
            HcdVideoItem *item = [[HcdVideoItem alloc] init];
            item.video = video;
            item.audio = audio;
            item.audioTimeRange = audioTimeRange;
            self.videoExporter = [[HcdVideoExporter alloc] initWithVideoItem:item];
            [self.videoExporter startExport];
            float timeRate = self.currentProgress;
            __strong typeof(weakSelf) strongSelf = weakSelf;
            self.videoExporter.exportingBlock = ^(BOOL exportCompleted, CGFloat progress, NSURL * _Nonnull url, NSError * _Nonnull error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    strongSelf.currentProgress = exportCompleted ? 1 : timeRate + (progress > 0 ? progress : 1) * self.exportTimeRate;
                    completed(exportCompleted, url);
                });
            };
        }
    }];
    return self;
}

- (void)cancelExport {
    
    [self.videoWriter cancelWriting];
    [self.videoExporter cancelExport];
}

#pragma mark - Setter

- (void)setWriterTimeRate:(float)writerTimeRate {
    
    _writerTimeRate = writerTimeRate;
    [self calculatorTimeRate];
}

- (void)setCurrentProgress:(float)currentProgress {
    _currentProgress = currentProgress;
    if (self.progress) {
        self.progress(self.currentProgress);
    }
}

#pragma mark - private

- (void)calculatorTimeRate {
    
    if (self.images && self.images.count > 0) {
        self.exportTimeRate = 1 - self.writerTimeRate;
        float frameTimeRate = self.writerTimeRate / (float)self.images.count;
        self.waitTranstionTimeRate = self.isMovement ? 0 : frameTimeRate * 0.2;
        self.transitionTimeRate = frameTimeRate - self.waitTranstionTimeRate;
    }
}

- (void)calculateTime {
    
    if (!self.images || self.images.count == 0) {
        return;
    }
    
    BOOL isFadeLong = self.transition == ImageTransitionCrossFadeLong;
    BOOL hasSetDuration = self.videoDuration > 0;
    self.timescale = hasSetDuration ? 100000 : 1;
    NSInteger average = 2;
    if (hasSetDuration) {
        average = (int)(self.videoDuration * self.timescale / self.images.count);
    }
    
    if (self.isMovement) {
        self.frameDuration = 0;
        self.transitionDuration = hasSetDuration ? average : 2;
    } else {
        self.frameDuration = hasSetDuration ? average : (isFadeLong ? 3 : 2);
        self.transitionDuration = isFadeLong ? (int)(self.frameDuration * 2 / 3) : (int)(self.frameDuration / 2);
    }
    
    NSInteger frame = self.isMovement ? 20 : 60;
    self.transitionFrameCount = (int)(frame * self.transitionDuration / self.timescale);
    self.framesToWaitBeforeTransition = isFadeLong ? self.transitionFrameCount / 3 : self.transitionFrameCount / 2;
    
    self.transitionRate = 1 / (double)self.transitionDuration / (double)self.timescale;
    self.transitionRate = self.transitionRate == 0 ? 1 : self.transitionRate;
    
    if (hasSetDuration == NO) {
        self.videoDuration = self.frameDuration * self.timescale * self.images.count;
    }
    
    [self calculatorTimeRate];
}

- (void)makeImageFit {
    NSMutableArray *newImages = [NSMutableArray array];
    for (UIImage *image in self.images) {
        CGSize size = CGSizeMake(self.size.width * self.definition, self.size.height * self.definition);
        
        CGSize viewSize = self.isMovement && self.movement == ImageMovementFade ? CGSizeMake(size.width + self.fadeOffset, size.height + self.fadeOffset) : size;
        
        UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, viewSize.width, viewSize.height)];
        view.backgroundColor = [UIColor blackColor];
        
        if (self.blurBackground) {
            UIImageView *bgImageView = [[UIImageView alloc] initWithImage:[UIImage blurImage:image blurLevel:0.6]];
            bgImageView.frame = view.bounds;
            bgImageView.contentMode = UIViewContentModeScaleAspectFill;
            [view addSubview:bgImageView];
        }
        
        UIImageView *imageView = [[UIImageView alloc] initWithImage:image];
        imageView.contentMode = self.contentMode;
        imageView.backgroundColor = [UIColor clearColor];
        imageView.frame = view.bounds;
        [view addSubview:imageView];
        UIImage *newImage = [UIImage imageWithView:view];
        [newImages addObject:newImage];
        
    }
    self.images = newImages;
}

- (void)combineVideo:(CompletedCombineBlock)completed {
    [self makeImageFit];
    if (self.isMovement) {
        if (self.movement == ImageMovementNone) {
            self.isMovement = NO;
            self.transition = ImageTransitionNone;
            [self makeTransitionVideo:self.transition completed:completed];
        } else {
            [self makeMovementVideo:self.movement completed:completed];
        }
    } else {
        [self makeTransitionVideo:self.transition completed:completed];
    }
}

- (void)makeMovementVideo:(ImageMovement)movement completed:(CompletedCombineBlock)completed {
    if (!self.images || self.images.count == 0) {
        return;
    }
    
    // Config
    self.isMixed = self.movement == ImageMovementFixed;
    [self changeNextIfNeeded];
    
    // path
    NSURL *path = [[HcdFileManager MovURL] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.mov", @(self.movement)]];
    [self deletePreviousTmpVideo:path];
    
    // config
    [self calculateTime];
    
    // writer
    self.videoWriter = [[AVAssetWriter alloc] initWithURL:path fileType:AVFileTypeQuickTimeMovie error:nil];
    if (!self.videoWriter) {
        completed(NO, nil);
        return;
    }
    
    // input
    NSDictionary *videoSettings = @{
        AVVideoCodecKey: AVVideoCodecH264,
        AVVideoWidthKey: @(self.size.width),
        AVVideoHeightKey: @(self.size.height)
    };
    AVAssetWriterInput *writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    [self.videoWriter addInput:writerInput];
    
    // adapter
    NSDictionary *bufferAttributes = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32ARGB)
    };
    AVAssetWriterInputPixelBufferAdaptor *bufferAdapter = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput
                                                                                                                           sourcePixelBufferAttributes:bufferAttributes];
    
    [self startCombine:self.videoWriter
           writerInput:writerInput
         bufferAdapter:bufferAdapter
             completed:^(BOOL success, NSURL * _Nonnull videoURL) {
        completed(success, path);
    }];
}

- (void)startCombine:(AVAssetWriter *)videoWriter writerInput:(AVAssetWriterInput *)writerInput bufferAdapter:(AVAssetWriterInputPixelBufferAdaptor *)bufferAdapter completed:(CompletedCombineBlock)completed {
    
    [videoWriter startWriting];
    [videoWriter startSessionAtSourceTime:kCMTimeZero];
    
    __block CMTime presentTime = CMTimeMakeWithSeconds(0, (int32_t)self.timescale);
    __block NSInteger i = 0;
    
    [writerInput requestMediaDataWhenReadyOnQueue:self.mediaInputQueue usingBlock:^{
        while (true) {
            if (i >= self.images.count) {
                break;
            }
            
            NSInteger duration = self.isMovement ? self.transitionDuration : self.frameDuration;
            presentTime = CMTimeMake(i * duration, (int32_t)self.timescale);
            
            UIImage *presentImage = self.images[i];
            UIImage *nextImage = self.images.count > 1 && i != self.images.count - 1 ? self.images[i + 1] : nil;
            
            if (self.isMovement) {
                presentTime = [self appendMovementBuffer:i
                                            presentImage:presentImage
                                               nextImage:nextImage
                                                    time:presentTime
                                             writerInput:writerInput
                                           bufferAdapter:bufferAdapter];
            } else {
                presentTime = [self appendTransitionBuffer:i
                                              presentImage:presentImage
                                                 nextImage:nextImage
                                                      time:presentTime
                                               writerInput:writerInput
                                             bufferAdapter:bufferAdapter];
            }
            
            i += 1;
            [self changeNextIfNeeded];
        }
        [writerInput markAsFinished];
        [videoWriter finishWritingWithCompletionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                if (videoWriter.error) {
                    NSLog(@"%@", videoWriter.error);
                }
                completed(videoWriter.error == nil, nil);
            });
        }];
    }];
}

- (CMTime)appendMovementBuffer:(NSInteger)position
                  presentImage:(UIImage *)presentImage
                     nextImage:(UIImage *)nextImage
                          time:(CMTime)time
                   writerInput:(AVAssetWriterInput *)writerInput
                 bufferAdapter:(AVAssetWriterInputPixelBufferAdaptor *)bufferAdapter {
    
    CMTime presentTime = time;
    
    CGImageRef cgImage = presentImage.CGImage;
    
    CMTime movementTime = CMTimeMake(self.transitionDuration, (int32_t)(self.transitionFrameCount * self.timescale));
    
    float timeRate = self.currentProgress;
    for (NSInteger j = 1; j <= self.transitionFrameCount; j++) {
        CGFloat rate = j / (CGFloat)self.transitionFrameCount;
        
        CVPixelBufferRef movementBuffer = [self movementPixelBuffer:cgImage movement:self.movement rate:rate];
        while (!writerInput.isReadyForMoreMediaData) {
            [NSThread sleepForTimeInterval:0.1];
        }
        
        [bufferAdapter appendPixelBuffer:movementBuffer withPresentationTime:presentTime];
        CFRelease(movementBuffer);
        movementBuffer = NULL;
        
        self.currentProgress = timeRate + self.transitionTimeRate * rate;
        presentTime = CMTimeAdd(presentTime, movementTime);
    }
    
    return presentTime;
}

- (CMTime)appendTransitionBuffer:(NSInteger)position
                    presentImage:(UIImage *)presentImage
                       nextImage:(UIImage *)nextImage
                            time:(CMTime)time
                     writerInput:(AVAssetWriterInput *)writerInput
                   bufferAdapter:(AVAssetWriterInputPixelBufferAdaptor *)bufferAdapter {
    
    CMTime presentTime = time;
    
    CGImageRef cgImage = presentImage.CGImage;
    
    CVPixelBufferRef buffer = [self transitionPixelBuffer:cgImage toImage:nextImage.CGImage transition:ImageTransitionNone rate:0];
    while (!writerInput.isReadyForMoreMediaData) {
        [NSThread sleepForTimeInterval:0.1];
    }
    
    [bufferAdapter appendPixelBuffer:buffer withPresentationTime:presentTime];
    CFRelease(buffer);
    buffer = NULL;
    
    self.currentProgress += self.waitTranstionTimeRate;
    
    CMTime transitionTime = CMTimeMake(self.transitionDuration, (int32_t)(self.transitionFrameCount * self.timescale));
    presentTime = CMTimeAdd(presentTime, CMTimeMake(self.frameDuration - self.transitionDuration, (int32_t)self.timescale));
    
    if (position + 1 < self.images.count) {
        if (self.transition != ImageTransitionNone) {
            NSInteger framesToTransitionCount = self.transitionFrameCount - self.framesToWaitBeforeTransition;
            
            float timeRate = self.currentProgress;
            for (NSInteger j = 1; j <= framesToTransitionCount; j++) {
                
                CGFloat rate = j / (double)framesToTransitionCount;
                
                CVPixelBufferRef transitionBuffer = [self transitionPixelBuffer:cgImage toImage:nextImage.CGImage transition:self.transition rate:rate];
                while (!writerInput.isReadyForMoreMediaData) {
                    [NSThread sleepForTimeInterval:0.1];
                }
                
                [bufferAdapter appendPixelBuffer:transitionBuffer withPresentationTime:presentTime];
                CFRelease(transitionBuffer);
                transitionBuffer = NULL;
                
                self.currentProgress = timeRate + self.transitionTimeRate * rate;
//                NSLog(@"j = %@, position = %@, currentProgress = %lf", @(j), @(position), self.currentProgress);
                
                presentTime = CMTimeAdd(presentTime, transitionTime);
            }
        }
    }
    
    return presentTime;
}

- (CVPixelBufferRef)movementPixelBuffer:(CGImageRef)cgImage movement:(ImageMovement)movement rate:(CGFloat)rate {
    
    CVPixelBufferRef buffer = [self createBuffer];
    if (!buffer) {
        return nil;
    }
    
    CVPixelBufferLockBaseAddress(buffer, self.flags);
    
    void *pxdata = CVPixelBufferGetBaseAddress(buffer);
    NSParameterAssert(pxdata != NULL);
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef context = CGBitmapContextCreate(pxdata, self.size.width, self.size.height, 8, CVPixelBufferGetBytesPerRow(buffer), rgbColorSpace, kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);
    
    CGContextSetInterpolationQuality(context, self.quarity);
    [self performMovementDrawing:context cgImage:cgImage movement:self.movement rate:rate];
    
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(buffer, self.flags);
    
    return buffer;
}

- (CVPixelBufferRef)transitionPixelBuffer:(CGImageRef)fromImage toImage:(CGImageRef)toImage transition:(ImageTransition)transition rate:(CGFloat)rate {
    
    CVPixelBufferRef buffer = [self createBuffer];
    if (!buffer) {
        return nil;
    }
    
    CVPixelBufferLockBaseAddress(buffer, self.flags);
    
    void *pxdata = CVPixelBufferGetBaseAddress(buffer);

    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef context = CGBitmapContextCreate(pxdata, self.size.width, self.size.height, 8, CVPixelBufferGetBytesPerRow(buffer), rgbColorSpace, kCGImageAlphaNoneSkipFirst);
    
    CGContextSetInterpolationQuality(context, self.quarity);
    [self performTransitionDrawing:context from:fromImage to:toImage transition:self.transition rate:rate];
    
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(buffer, self.flags);
    
    return buffer;
}

- (void)performTransitionDrawing:(CGContextRef)context from:(CGImageRef)from to:(CGImageRef)to  transition:(ImageTransition)transition rate:(CGFloat)rate {
    
    CGSize toSize = CGSizeZero;
    if (to) {
        toSize = CGSizeMake(CGImageGetWidth(to), CGImageGetHeight(to));
    }
    
    CGSize fromFitSize = self.size;
    CGSize toFitSize = self.size;
    
    if (to == nil) {
        CGRect rect = CGRectMake(0, 0, fromFitSize.width, fromFitSize.height);
        CGContextDrawImage(context, rect, from);
        return;
    }
    
    switch (transition) {
        case ImageTransitionNone: {
            CGRect rect = CGRectMake(0, 0, fromFitSize.width, fromFitSize.height);
            CGContextDrawImage(context, rect, from);
            break;
        }
        case ImageTransitionCrossFade: {
            CGRect fromRect = CGRectMake(0, 0, fromFitSize.width, fromFitSize.height);
            CGRect toRect = CGRectMake(0, 0, toFitSize.width, toFitSize.height);
            
            CGContextDrawImage(context, fromRect, from);
            CGContextBeginTransparencyLayer(context, nil);
            CGContextSetAlpha(context, rate);
            CGContextDrawImage(context, toRect, to);
            CGContextEndTransparencyLayer(context);
            
            break;
        }
        case ImageTransitionCrossFadeUp: {
            // Expand twice
            CGFloat width = (rate + 1) * fromFitSize.width;
            CGFloat height = (rate + 1) * fromFitSize.height;
            
            CGRect fromRect = CGRectMake(-(width - fromFitSize.width) / 2,
                                         -(height - fromFitSize.height) / 2,
                                         width,
                                         height);
            
            CGRect toRect = CGRectMake(0, 0, toFitSize.width, toFitSize.height);
            
            CGContextDrawImage(context, fromRect, from);
            CGContextBeginTransparencyLayer(context, nil);
            CGContextSetAlpha(context, rate);
            CGContextDrawImage(context, toRect, to);
            CGContextEndTransparencyLayer(context);
            
            break;
        }
        case ImageTransitionCrossFadeDown: {
            
            CGFloat width = (1 - rate) * fromFitSize.width;
            CGFloat height = (1 - rate) * fromFitSize.height;
            
            CGRect fromRect = CGRectMake((fromFitSize.width - width) / 2,
                                         (fromFitSize.height - height) / 2,
                                         width,
                                         height);
            
            CGRect toRect = CGRectMake(0, 0, toFitSize.width, toFitSize.height);
            
            // cover previous fps
            CGContextSetFillColorWithColor(context, [UIColor colorWithRed:0 green:0 blue:0 alpha:1].CGColor);
            CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
            CGContextFillRect(context, CGRectMake(0, 0, self.size.width, self.size.height));
            
            CGContextDrawImage(context, fromRect, from);
            CGContextBeginTransparencyLayer(context, nil);
            CGContextSetAlpha(context, rate);
            CGContextDrawImage(context, toRect, to);
            CGContextEndTransparencyLayer(context);
            
            break;
        }
        case ImageTransitionWipeRight: {
            
            CGRect fromRect = CGRectMake(0, 0, fromFitSize.width, fromFitSize.height);
            CGRect toRect = CGRectMake(0, 0, toFitSize.width * rate, toFitSize.height);
            CGRect clipRect = CGRectMake(0, 0, toSize.width *  rate, toSize.height);
            
            CGContextDrawImage(context, fromRect, from);
            CGImageRef mask = CGImageCreateWithImageInRect(to, clipRect);
            CGContextDrawImage(context, toRect, mask);
            break;
        }
        case ImageTransitionWipeLeft: {
            
            CGRect fromRect = CGRectMake(0, 0, fromFitSize.width, fromFitSize.height);
            CGRect toRect = CGRectMake((1 - rate) * self.size.width, 0, toFitSize.width * rate, toFitSize.height);
            CGRect clipRect = CGRectMake((1 - rate) * toSize.width, 0, toSize.width * rate, toSize.height);
            
            CGContextDrawImage(context, fromRect, from);
            CGImageRef mask = CGImageCreateWithImageInRect(to, clipRect);
            CGContextDrawImage(context, toRect, mask);
            break;
        }
        case ImageTransitionWipeUp: {
            
            CGRect fromRect = CGRectMake(0, 0, fromFitSize.width, fromFitSize.height);
            CGRect toRect = CGRectMake(0, 0, toFitSize.width, toFitSize.height * rate);
            CGRect clipRect = CGRectMake(0, (1 - rate) * toSize.height, toSize.width, toSize.height * rate);
            
            CGContextDrawImage(context, fromRect, from);
            CGImageRef mask = CGImageCreateWithImageInRect(to, clipRect);
            CGContextDrawImage(context, toRect, mask);
            break;
        }
        case ImageTransitionWipeDown: {
            
            CGRect fromRect = CGRectMake(0, 0, fromFitSize.width, fromFitSize.height);
            CGRect toRect = CGRectMake(0, (1 - rate) * toFitSize.height, toFitSize.width, toFitSize.height * rate);
            CGRect clipRect = CGRectMake(0, 0, toSize.width, toSize.height * rate);
            
            CGContextDrawImage(context, fromRect, from);
            CGImageRef mask = CGImageCreateWithImageInRect(to, clipRect);
            CGContextDrawImage(context, toRect, mask);
            break;
        }
        case ImageTransitionSlideLeft: {
            
            CGRect fromRect = CGRectMake(0, 0, fromFitSize.width, fromFitSize.height);
            CGRect toRect = CGRectMake((1 - rate) * self.size.width, 0, toFitSize.width, toFitSize.height);
            
            CGContextDrawImage(context, fromRect, from);
            CGContextDrawImage(context, toRect, to);
            
            break;
        }
        case ImageTransitionSlideRight: {
            
            CGRect fromRect = CGRectMake(0, 0, fromFitSize.width, fromFitSize.height);
            CGRect toRect = CGRectMake(-(1 - rate) * self.size.width, 0, toFitSize.width, toFitSize.height);
            
            CGContextDrawImage(context, fromRect, from);
            CGContextDrawImage(context, toRect, to);
            
            break;
        }
        case ImageTransitionSlideUp: {
            
            CGRect fromRect = CGRectMake(0, 0, fromFitSize.width, fromFitSize.height);
            CGRect toRect = CGRectMake(0, -(1 - rate) * self.size.height, toFitSize.width, toFitSize.height);
            
            CGContextDrawImage(context, fromRect, from);
            CGContextDrawImage(context, toRect, to);
            
            break;
        }
        case ImageTransitionSlideDown: {
            
            CGRect fromRect = CGRectMake(0, 0, fromFitSize.width, fromFitSize.height);
            CGRect toRect = CGRectMake(0, (1 - rate) * self.size.height, toFitSize.width, toFitSize.height);
            
            CGContextDrawImage(context, fromRect, from);
            CGContextDrawImage(context, toRect, to);
            
            break;
        }
        case ImageTransitionPushRight: {
            
            CGRect fromRect = CGRectMake(rate * self.size.width, 0, fromFitSize.width, fromFitSize.height);
            CGRect toRect = CGRectMake(-(1 - rate) * self.size.width, 0, toFitSize.width, toFitSize.height);
            
            CGContextDrawImage(context, fromRect, from);
            CGContextDrawImage(context, toRect, to);
            
            break;
        }
        case ImageTransitionPushLeft: {
            
            CGRect fromRect = CGRectMake(-rate * self.size.width, 0, fromFitSize.width, fromFitSize.height);
            CGRect toRect = CGRectMake((1 - rate) * self.size.width, 0, toFitSize.width, toFitSize.height);
            
            CGContextDrawImage(context, fromRect, from);
            CGContextDrawImage(context, toRect, to);
            
            break;
        }
        case ImageTransitionPushUp: {
            
            CGRect fromRect = CGRectMake(0, rate * self.size.height, fromFitSize.width, fromFitSize.height);
            CGRect toRect = CGRectMake(0, -(1 - rate) * self.size.height, toFitSize.width, toFitSize.height);
            
            CGContextDrawImage(context, fromRect, from);
            CGContextDrawImage(context, toRect, to);
            
            break;
        }
        case ImageTransitionPushDown: {
            
            CGRect fromRect = CGRectMake(0, -rate * self.size.height, fromFitSize.width, fromFitSize.height);
            CGRect toRect = CGRectMake(0, (1 - rate) * self.size.height, toFitSize.width, toFitSize.height);
            
            CGContextDrawImage(context, fromRect, from);
            CGContextDrawImage(context, toRect, to);
            
            break;
        }
        default:
            break;
    }
}

- (void)performMovementDrawing:(CGContextRef)context cgImage:(CGImageRef)cgImage movement:(ImageMovement)movement rate:(CGFloat)rate {
    
    CGSize fromFitSize = self.size;
    
    switch (movement) {
        case ImageMovementFade: {
            fromFitSize.width += self.fadeOffset;
            fromFitSize.height += self.fadeOffset;
            
            CGRect rect = CGRectZero;
            
            switch (self.movementFade) {
                case MovementFadeUpLeft:
                    rect = CGRectMake(-self.fadeOffset * rate, self.fadeOffset * rate - self.fadeOffset, fromFitSize.width, fromFitSize.height);
                    break;
                case MovementFadeUpRight:
                    rect = CGRectMake(self.fadeOffset * rate - self.fadeOffset, self.fadeOffset * rate - self.fadeOffset, fromFitSize.width, fromFitSize.height);
                    break;
                case MovementFadeBottomLeft:
                    rect = CGRectMake(-self.fadeOffset * rate, -self.fadeOffset * rate, fromFitSize.width, fromFitSize.height);
                    break;
                case MovementFadeBottomRight:
                    rect = CGRectMake(self.fadeOffset * rate - self.fadeOffset, -self.fadeOffset * rate, fromFitSize.width, fromFitSize.height);
                    break;
                default:
                    break;
            }
            
            CGContextSetFillColorWithColor(context, [UIColor colorWithRed:0 green:0 blue:0 alpha:1.0].CGColor);
            CGContextSetStrokeColorWithColor(context, [UIColor blackColor].CGColor);
            CGContextFillRect(context, CGRectMake(0, 0, self.size.width, self.size.height));
            CGContextDrawImage(context, rect, cgImage);
            
            break;
        }
        case ImageMovementZoomOut: {
            CGFloat width = rate * self.fadeOffset + fromFitSize.width;
            CGFloat height = rate * self.fadeOffset + fromFitSize.height;
            
            CGRect rect = CGRectMake(-(width - fromFitSize.width) / 2, -(height - fromFitSize.height) / 2, width, height);
            
            CGContextDrawImage(context, rect, cgImage);
            
            break;
        }
        case ImageMovementZoomIn: {
            
            CGFloat width = 1.5 * fromFitSize.width - rate * self.fadeOffset;
            CGFloat height = 1.5 * fromFitSize.height - rate * self.fadeOffset;
            
            CGRect rect = CGRectMake(-(width - fromFitSize.width) / 2, -(height - fromFitSize.height) / 2, width, height);
            
            CGContextDrawImage(context, rect, cgImage);
            
            break;
        }
        default:
            break;
    }
}

- (CVPixelBufferRef)createBuffer {
    NSDictionary *options = @{
        (NSString *)kCVPixelBufferCGImageCompatibilityKey: @(YES),
        (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @(YES)
    };
    
    CVPixelBufferRef pxBuffer;
    
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, self.size.width, self.size.height, kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef _Nullable)(options), &pxBuffer);
    
    BOOL success = status == kCVReturnSuccess && pxBuffer != nil;
    return success ? pxBuffer : nil;
}

- (void)makeTransitionVideo:(ImageTransition)transition completed:(CompletedCombineBlock)completed {
    
    if (!self.images || self.images.count == 0) {
        return;
    }
    
    [self calculateTime];
    
    if (self.transition == ImageTransitionCrossFadeLong) {
        self.transition = ImageTransitionCrossFade;
    }
    
    // Config
    self.isMixed = self.transition == ImageTransitionWipeMixed || self.transition == ImageTransitionSlideMixed || self.transition == ImageTransitionPushMixed;
    [self changeNextIfNeeded];
    
    // video path
    NSURL *path = [[HcdFileManager MovURL] URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.mov", @(transition)]];
    [self deletePreviousTmpVideo:path];
    
    // writer
    self.videoWriter = [[AVAssetWriter alloc] initWithURL:path fileType:AVFileTypeQuickTimeMovie error:nil];
    
    if (!self.videoWriter) {
        completed(NO, nil);
        return;
    }
    
    // input
    NSDictionary *videoSettings = @{
        AVVideoCodecKey: AVVideoCodecH264,
        AVVideoWidthKey: @(self.size.width),
        AVVideoHeightKey: @(self.size.height)
    };
    AVAssetWriterInput *writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    [self.videoWriter addInput:writerInput];
    
    // adapter
    NSDictionary *bufferAttributes = @{
        (NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32ARGB)
    };
    AVAssetWriterInputPixelBufferAdaptor *bufferAdapter = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput
                                                                                                                           sourcePixelBufferAttributes:bufferAttributes];
    
    [self startCombine:self.videoWriter
           writerInput:writerInput
         bufferAdapter:bufferAdapter
             completed:^(BOOL success, NSURL * _Nonnull videoURL) {
        completed(success, path);
    }];
}

- (void)deletePreviousTmpVideo:(NSURL *)url {
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    }
}

- (void)changeNextIfNeeded {
    if (self.isMovement) {
        if (self.movement == ImageMovementFade) {
            // change movementFade
            self.movementFade = [self nextMovementFade:self.movementFade];
        } else if (self.isMixed) {
            // change movement
            self.movement = [self nextMovement:self.movement];
        }
    } else {
        if (self.isMixed) {
            // change transition
            self.transition = [self nextTransition:self.transition];
        }
    }
}

- (ImageTransition)nextTransition:(ImageTransition)transition {
    
    ImageTransition next = transition;
    
    switch (next) {
        case ImageTransitionWipeMixed:
        case ImageTransitionWipeUp:
        case ImageTransitionWipeDown:
        case ImageTransitionWipeLeft:
        case ImageTransitionWipeRight:
            next = [self wipeNext:next];
            break;
        case ImageTransitionSlideMixed:
        case ImageTransitionSlideUp:
        case ImageTransitionSlideDown:
        case ImageTransitionSlideLeft:
        case ImageTransitionSlideRight:
            next = [self slideNext:next];
            break;
        case ImageTransitionPushMixed:
        case ImageTransitionPushUp:
        case ImageTransitionPushDown:
        case ImageTransitionPushLeft:
        case ImageTransitionPushRight:
            next = [self pushNext:next];
            break;
        default:
            break;
    }
    
    return next;
}

- (ImageMovement)nextMovement:(ImageMovement)movement {
    
    ImageMovement next = movement;
    
    switch (next) {
        case ImageMovementFixed:
            next = ImageMovementZoomIn;
            break;
        case ImageMovementZoomIn:
            next = ImageMovementZoomOut;
            break;
        case ImageMovementZoomOut:
            next = ImageMovementFade;
            break;
        default:
            break;
    }
    
    return next;
}

- (MovementFade)nextMovementFade:(MovementFade)movementFade {
    
    MovementFade next = movementFade;
    
    switch (next) {
        case MovementFadeUpLeft:
            next = MovementFadeUpRight;
            break;
        case MovementFadeUpRight:
            next = MovementFadeBottomLeft;
            break;
        case MovementFadeBottomLeft:
            next = MovementFadeBottomRight;
            break;
        case MovementFadeBottomRight:
            next = MovementFadeUpLeft;
            break;
        default:
            break;
    }
    
    return next;
}

- (ImageTransition)wipeNext:(ImageTransition)transition {
    
    ImageTransition next = transition;
    
    switch (next) {
        case ImageTransitionWipeMixed:
            next = ImageTransitionWipeRight;
            break;
        case ImageTransitionWipeRight:
            next = ImageTransitionWipeLeft;
            break;
        case ImageTransitionWipeLeft:
            next = ImageTransitionWipeUp;
            break;
        case ImageTransitionWipeUp:
            next = ImageTransitionWipeDown;
            break;
        case ImageTransitionWipeDown:
            next = ImageTransitionWipeRight;
            break;
        default:
            break;
    }
    
    return next;
}

- (ImageTransition)slideNext:(ImageTransition)transition {
    
    ImageTransition next = transition;
    
    switch (next) {
        case ImageTransitionSlideMixed:
            next = ImageTransitionSlideRight;
            break;
        case ImageTransitionSlideRight:
            next = ImageTransitionSlideLeft;
            break;
        case ImageTransitionSlideLeft:
            next = ImageTransitionSlideUp;
            break;
        case ImageTransitionSlideUp:
            next = ImageTransitionSlideDown;
            break;
        case ImageTransitionSlideDown:
            next = ImageTransitionSlideRight;
            break;
        default:
            break;
    }
    
    return next;
}

- (ImageTransition)pushNext:(ImageTransition)transition {
    ImageTransition next = transition;
    
    switch (next) {
        case ImageTransitionPushMixed:
            next = ImageTransitionPushRight;
            break;
        case ImageTransitionPushRight:
            next = ImageTransitionPushLeft;
            break;
        case ImageTransitionPushLeft:
            next = ImageTransitionPushUp;
            break;
        case ImageTransitionPushUp:
            next = ImageTransitionPushDown;
            break;
        case ImageTransitionPushDown:
            next = ImageTransitionPushRight;
            break;
        default:
            break;
    }
    
    return next;
}

- (void)createDirectory {
    [[NSFileManager defaultManager] createDirectoryAtURL:[HcdFileManager MovURL] withIntermediateDirectories:YES attributes:nil error:nil];
}

@end

