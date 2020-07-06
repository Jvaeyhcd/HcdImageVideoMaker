//
//  VideoExporter.h
//  HcdImageVideoMaker
//
//  Created by Salvador on 2020/7/5.
//  Copyright © 2020 Salvador. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface HcdVideoItem : NSObject

@property (nonatomic, strong) AVURLAsset *video;
@property (nonatomic, strong) AVURLAsset *audio;
@property (nonatomic, assign) CMTimeRange audioTimeRange;

@end

typedef void(^ExportingBlock)(BOOL completed, CGFloat progress, NSURL * _Nullable url, NSError * _Nullable error);

@interface HcdVideoExporter : NSObject

@property (nonatomic, copy) ExportingBlock exportingBlock;

@property (nonatomic, strong) HcdVideoItem *videoItem;

@property (nonatomic, strong) AVMutableComposition *mixComposition;

- (instancetype)initWithVideoItem:(HcdVideoItem *)item;

/// 开始导出
- (void)startExport;

/// 取消导出
- (void)cancelExport;

/// 是否正在导出
- (BOOL)isExporting;

@end

NS_ASSUME_NONNULL_END
