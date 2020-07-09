//
//  UIImage+HAdd.h
//  HcdImageVideoMaker
//
//  Created by Salvador on 2020/7/5.
//  Copyright © 2020 Salvador. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIImage (HAdd)

+ (UIImage *)imageWithView:(UIView *)view;

/// blur image
/// @param image origin image
/// @param blur blur 0~1
+ (UIImage *)blurImage:(UIImage *)image blurLevel:(CGFloat)blur;

- (UIImage *)applyAlpha:(CGFloat)alpha;

@end

NS_ASSUME_NONNULL_END
