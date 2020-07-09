//
//  VideoExporter.m
//  HcdImageVideoMaker
//
//  Created by Salvador on 2020/7/5.
//  Copyright © 2020 Salvador. All rights reserved.
//

#import "HcdVideoExporter.h"
#import "HcdFileManager.h"

@implementation HcdVideoItem

@end

@interface HcdVideoExporter()

@property (nonatomic, assign) CMPersistentTrackID videoTrackID;

@property (nonatomic, assign) CMPersistentTrackID audioTrackID;

@property (nonatomic, strong) AVAssetExportSession *exporter;

@end


@implementation HcdVideoExporter

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.videoTrackID = 1;
        self.audioTrackID = 2;
    }
    return self;
}

- (instancetype)initWithVideoItem:(HcdVideoItem *)item
{
    self = [super init];
    if (self) {
        self.videoTrackID = 1;
        self.audioTrackID = 2;
        self.videoItem = item;
    }
    return self;
}

#pragma mark - public

- (void)startExport {
    if (!self.videoItem) {
        if (self.exportingBlock) {
            self.exportingBlock(NO, 0, [NSURL URLWithString:@""], [[NSError alloc] initWithDomain:@"video item is empty" code:0 userInfo:nil]);
        }
        return;
    }
    
    self.mixComposition = [[AVMutableComposition alloc] init];
    [self addTrackVideoItem:self.videoItem composition:self.mixComposition];
    AVMutableCompositionTrack *videoCompositionTrack = [self.mixComposition trackWithTrackID:self.videoTrackID];
    
    CMTimeRange timeRange = CMTimeRangeMake(kCMTimeZero, self.videoItem.video.duration);
    
    [self insertVideoItem:self.videoItem videoCompositionTrack:videoCompositionTrack timeRange:timeRange];
    
    if (self.videoItem.audio) {
        AVMutableCompositionTrack *audioCompositionTrack = [self.mixComposition trackWithTrackID:self.audioTrackID];
        [self addMusicVideoItem:self.videoItem audioCompositionTrack:audioCompositionTrack];
    }
    
    [self merge:self.mixComposition duration:timeRange.duration];
}

- (void)cancelExport {
    if (self.isExporting) {
        [self.exporter cancelExport];
    }
}

- (BOOL)isExporting {
    if (self.exporter != nil) {
        return self.exporter.status == AVAssetExportSessionStatusExporting;
    }
    return NO;
}

#pragma mark - private function

/// Add video and audio composition track
/// @param item video item
/// @param composition AVMutableComposition
- (void)addTrackVideoItem:(HcdVideoItem *)item composition:(AVMutableComposition *)composition {
    
    [composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:self.videoTrackID];
    if (item.audio) {
        [composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:self.audioTrackID];
    }
}

/// Add video to composition
/// @param item VideoItem
/// @param videoCompositionTrack AVMutableCompositionTrack
/// @param timeRange CMTimeRange
- (void)insertVideoItem:(HcdVideoItem *)item videoCompositionTrack:(AVMutableCompositionTrack *)videoCompositionTrack timeRange:(CMTimeRange)timeRange {
    NSArray *trackArray = [item.video tracksWithMediaType:AVMediaTypeVideo];
    if (trackArray && trackArray.count > 0) {
        AVAssetTrack *videoTrack = trackArray.firstObject;
        [videoCompositionTrack insertTimeRange:timeRange ofTrack:videoTrack atTime:kCMTimeZero error:nil];
    }
}

/// Add music into video
/// @param item musicItem
/// @param audioCompositionTrack audioCompositionTrack callback block
- (void)addMusicVideoItem:(HcdVideoItem *)item audioCompositionTrack:(AVMutableCompositionTrack *)audioCompositionTrack {
    
    AVURLAsset *audio = item.audio;
    if (!audio) {
        return;
    }
    
    CMTime audioStart = item.audioTimeRange.start;
    CMTime audioDuration = item.audioTimeRange.duration;
    CMTimeScale audioTimescale = audio.duration.timescale;
    CMTime videoDuration = item.video.duration;
    
    // video is lengther than audio
    long videoSeconds = videoDuration.value / videoDuration.timescale;
    long audioSeconds = audioDuration.value / audioDuration.timescale;
    if (videoSeconds > audioSeconds) {
        int repeatCount = floor(videoSeconds / audioSeconds);
        long remain = videoSeconds % audioSeconds;
        CMTimeRange timeRange = CMTimeRangeMake(audioStart, audioDuration);
        
        for (int i = 0; i < repeatCount; i++) {
            CMTime start = CMTimeMakeWithSeconds(i * audioSeconds, audioTimescale);
            
            [self addAudio:audio start:start timeRange:timeRange audioCompositionTrack:audioCompositionTrack];
        }
        
        if (remain > 0) {
            double startSeconds = (double)repeatCount * audioSeconds;
            CMTime start = CMTimeMakeWithSeconds(startSeconds, audioTimescale);
            CMTime remainDuration = CMTimeMakeWithSeconds(remain, audioTimescale);
            CMTimeRange remainTimeRange = CMTimeRangeMake(audioStart, remainDuration);
            
            [self addAudio:audio start:start timeRange:remainTimeRange audioCompositionTrack:audioCompositionTrack];
        }
    } else {
        CMTimeRange timeRange = CMTimeRangeMake(audioStart, videoDuration);
        [self addAudio:audio start:kCMTimeZero timeRange:timeRange audioCompositionTrack:audioCompositionTrack];
    }
}

- (void)addAudio:(AVURLAsset *)audio start:(CMTime)start timeRange:(CMTimeRange)timeRange audioCompositionTrack:(AVMutableCompositionTrack *)audioCompositionTrack {
    
    NSArray *trackArray = [audio tracksWithMediaType:AVMediaTypeAudio];
    if (trackArray && trackArray.count > 0) {
        AVAssetTrack *audioTrack = trackArray.firstObject;
        [audioCompositionTrack insertTimeRange:timeRange ofTrack:audioTrack atTime:start error:nil];
    }
}

- (void)merge:(AVMutableComposition *)composition duration:(CMTime)duration {
    NSString *fileName = @"merge.mov";
    NSURL *path = [[HcdFileManager MovURL] URLByAppendingPathComponent:fileName];
    [self deletePreviousTmpVideoUrl:path];
    
    self.exporter = [[AVAssetExportSession alloc] initWithAsset:composition presetName:AVAssetExportPresetHighestQuality];
    self.exporter.outputURL = path;
    self.exporter.outputFileType = AVFileTypeQuickTimeMovie;
    self.exporter.shouldOptimizeForNetworkUse = YES;
    self.exporter.timeRange = CMTimeRangeMake(kCMTimeZero, duration);
    
    __block NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(readProgress) userInfo:nil repeats:YES];
    
    __weak typeof(self) weakSelf = self;
    [self.exporter exportAsynchronouslyWithCompletionHandler:^{
        [timer invalidate];
        
        if (weakSelf.exporter.status == AVAssetExportSessionStatusFailed) {
            if (weakSelf.exportingBlock) {
                weakSelf.exportingBlock(NO, 0.0, nil, weakSelf.exporter.error);
            }
        } else {
            if (weakSelf.exportingBlock) {
                weakSelf.exportingBlock(YES, 1.0, path, nil);
            }
        }
        NSLog(@"export completed");
    }];
}

- (void)deletePreviousTmpVideoUrl:(NSURL *)url {
    if ([[NSFileManager defaultManager] fileExistsAtPath:url.path]) {
        [[NSFileManager defaultManager] removeItemAtURL:url error:nil];
    }
}

- (void)readProgress {
    if (self.exporter) {
        NSLog(@"%s %@", __func__, @(self.exporter.progress));
        self.exportingBlock(NO, self.exporter.progress, nil, nil);
    }
}

@end

