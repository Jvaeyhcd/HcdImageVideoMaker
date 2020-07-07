//
//  HcdVideoMaker.h
//  HcdImageHcdVideoMaker
//
//  Created by Salvador on 2020/7/4.
//  Copyright © 2020 Salvador. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    ImageTransitionNone = 0,
    ImageTransitionCrossFade,
    ImageTransitionCrossFadeLong,
    ImageTransitionCrossFadeUp,
    ImageTransitionCrossFadeDown,
    ImageTransitionWipeRight,
    ImageTransitionWipeLeft,
    ImageTransitionWipeUp,
    ImageTransitionWipeDown,
    ImageTransitionWipeMixed,
    ImageTransitionSlideLeft,
    ImageTransitionSlideRight,
    ImageTransitionSlideUp,
    ImageTransitionSlideDown,
    ImageTransitionSlideMixed,
    ImageTransitionPushRight,
    ImageTransitionPushLeft,
    ImageTransitionPushUp,
    ImageTransitionPushDown,
    ImageTransitionPushMixed,
    ImageTransitionCount
} ImageTransition;

typedef enum : NSUInteger {
    ImageMovementNone = 0,
    ImageMovementFade,
    ImageMovementZoomOut,
    ImageMovementZoomIn,
    ImageMovementFixed
} ImageMovement;

typedef enum : NSUInteger {
    MovementFadeUpLeft,
    MovementFadeUpRight,
    MovementFadeBottomLeft,
    MovementFadeBottomRight
} MovementFade;

typedef void(^CompletedCombineBlock)(BOOL success, NSURL * _Nullable videoURL);
typedef void(^ProgressBlock)(CGFloat progress);

@interface HcdVideoMaker : NSObject

@property (nonatomic, strong) NSMutableArray *images;

@property (nonatomic, assign) ImageTransition transition;
@property (nonatomic, assign) ImageMovement movement;
@property (nonatomic, assign) MovementFade movementFade;

@property (nonatomic, assign) UIViewContentMode contentMode;

@property (nonatomic, copy) ProgressBlock progress;
@property (nonatomic, assign) CGInterpolationQuality quarity;

@property (nonatomic, assign) CGSize size;
@property (nonatomic, assign) CGFloat definition;
@property (nonatomic, assign) NSInteger videoDuration;
@property (nonatomic, assign) NSInteger frameDuration;
@property (nonatomic, assign) NSInteger transitionDuration;
@property (nonatomic, assign) NSInteger transitionFrameCount;
@property (nonatomic, assign) NSInteger framesToWaitBeforeTransition;
@property (nonatomic, assign) BOOL blurBackground;

- (instancetype)initWithImages:(NSMutableArray *)images transition:(ImageTransition)transition;

- (instancetype)initWithImages:(NSMutableArray *)images movement:(ImageMovement)movement;

- (HcdVideoMaker *)exportVideo:(AVURLAsset *)audio audioTimeRange:(CMTimeRange)audioTimeRange completed:(CompletedCombineBlock)completed;

- (void)cancelExport;

@end

NS_ASSUME_NONNULL_END

