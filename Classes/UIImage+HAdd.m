//
//  UIImage+HAdd.m
//  HcdImageVideoMaker
//
//  Created by Salvador on 2020/7/5.
//  Copyright © 2020 Salvador. All rights reserved.
//

#import "UIImage+HAdd.h"
#import <Accelerate/Accelerate.h>

@implementation UIImage (HAdd)

+ (UIImage *)imageWithView:(UIView *)view {
    
    [[UIApplication sharedApplication].keyWindow insertSubview:view atIndex:0];
    
    UIGraphicsBeginImageContextWithOptions(view.frame.size, YES, [UIScreen mainScreen].scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [view.layer renderInContext:context];
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [view removeFromSuperview];
    
    return image;
}

+ (UIImage *)blurImage:(UIImage *)image blurLevel:(CGFloat)blur {
    
    //    NSInteger boxSize = (NSInteger)(10 * 5);
    @autoreleasepool {
        if (blur < 0.f || blur > 1.f) {
            blur = 0.5f;
        }
        
        int boxSize     = (int)(blur * 100); //100为最大模糊程度
        boxSize         = boxSize - (boxSize % 2) + 1;
        CGImageRef img  = image.CGImage;
        
        vImage_Buffer     inBuffer, outBuffer;
        vImage_Error      error;
        
        //从CGImage中获取数据
        CGDataProviderRef inProvider = CGImageGetDataProvider(img);
        CFDataRef inBitmapData       = CGDataProviderCopyData(inProvider);
        
        //设置从CGImage获取对象的属性
        void *pixelBuffer;
        inBuffer.width      = CGImageGetWidth(img);
        inBuffer.height     = CGImageGetHeight(img);
        inBuffer.rowBytes   = CGImageGetBytesPerRow(img);
        inBuffer.data       = (void*)CFDataGetBytePtr(inBitmapData);
        pixelBuffer         = malloc(CGImageGetBytesPerRow(img) * CGImageGetHeight(img));
        if(!pixelBuffer)
            NSLog(@"No pixelbuffer");
        outBuffer.data      = pixelBuffer;
        outBuffer.width     = CGImageGetWidth(img);
        outBuffer.height    = CGImageGetHeight(img);
        outBuffer.rowBytes  = CGImageGetBytesPerRow(img);
        error = vImageBoxConvolve_ARGB8888(&inBuffer,
                                           &outBuffer,
                                           NULL,
                                           0,
                                           0,
                                           boxSize,
                                           boxSize,
                                           NULL,
                                           kvImageEdgeExtend);
        if (error) {
            NSLog(@"error from convolution %ld", error);
        }
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef ctx = CGBitmapContextCreate( outBuffer.data,
                                                 outBuffer.width,
                                                 outBuffer.height,
                                                 8,
                                                 outBuffer.rowBytes,
                                                 colorSpace,
                                                 kCGImageAlphaNoneSkipLast);
        CGImageRef imageRef  = CGBitmapContextCreateImage (ctx);
        UIImage *returnImage = [UIImage imageWithCGImage:imageRef];
        
        //清除;
        CGContextRelease(ctx);
        CGColorSpaceRelease(colorSpace);
        free(pixelBuffer);
        CFRelease(inBitmapData);
        CGImageRelease(imageRef);
        
        return returnImage;
    }
}

- (UIImage *)applyAlpha:(CGFloat)alpha {
    
    int bmpAlpha = MIN(255, MAX(0, (255 * alpha)));
    UIImage *image;
    int width = self.size.width * self.scale;
    int height = self.size.height * self.scale;
    
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    if (colorspace == NULL) {
        NSLog(@"Create Colorspace Error!");
        return nil;
    }
    
    Byte *imgData = NULL;
    imgData = malloc(width * height * 4);
    if (imgData == NULL) {
        NSLog(@"Memory Error!");
        CGColorSpaceRelease(colorspace);
        return nil;
    }
    
    CGContextRef bmpContext = CGBitmapContextCreate(imgData, width, height, 8, width * 4, colorspace, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    if (!bmpContext) {
        NSLog(@"Create Bitmap context Error!");
        CGColorSpaceRelease(colorspace);
        return nil;
    }
    
    CGContextDrawImage(bmpContext, CGRectMake(0, 0, width, height), self.CGImage);
    for (long i = 0; i < width * height; i++) {
        imgData[4*i+3] = bmpAlpha;
    }
    
    CGImageRef imageRef = CGBitmapContextCreateImage(bmpContext);
    if (imageRef != NULL) {
        image = [[UIImage alloc] initWithCGImage:imageRef];
        CGImageRelease(imageRef);
    }
    
    CGColorSpaceRelease(colorspace);
    CGContextRelease(bmpContext);
    free(imgData);
    
    return image;
}

@end
