//
//  ViewController.m
//  HcdImageVideoMaker
//
//  Created by Salvador on 2020/7/3.
//  Copyright © 2020 Salvador. All rights reserved.
//

#import "ViewController.h"
#import "HcdVideoMaker.h"
#import <AVKit/AVKit.h>

#define SCREEN_WIDTH [UIScreen mainScreen].bounds.size.width
#define SCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height

@interface ViewController ()

@property (nonatomic, strong) UILabel *progressLbl;

@property (nonatomic, strong) NSURL *videoPath;

@property (nonatomic, strong) HcdVideoMaker *maker;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initUI];
}

- (void)initUI {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    [button setBounds:CGRectMake(0,0,SCREEN_WIDTH * 0.25,50)];
    button.center = CGPointMake(SCREEN_WIDTH * 0.25, SCREEN_HEIGHT * 0.15);
    [button setTitle:@"视频合成"forState:UIControlStateNormal];
    [button addTarget:self action:@selector(clickMakeVideo)forControlEvents:UIControlEventTouchUpInside];
    button.backgroundColor = [UIColor redColor];
    [self.view addSubview:button];
    
    UIButton *button1=[UIButton buttonWithType:UIButtonTypeRoundedRect];
    [button1 setBounds:CGRectMake(0,0,SCREEN_WIDTH * 0.25,50)];
    button1.center = CGPointMake(SCREEN_WIDTH * 0.75, SCREEN_HEIGHT * 0.15);
    [button1 setTitle:@"视频播放"forState:UIControlStateNormal];
    [button1 addTarget:self action:@selector(playAction)forControlEvents:UIControlEventTouchUpInside];
    button1.backgroundColor = [UIColor redColor];
    [self.view addSubview:button1];
    
    UILabel *lbe = [[UILabel alloc]init];
    lbe.frame = CGRectMake(0, 0, SCREEN_WIDTH * 0.25, 25);
    lbe.center = CGPointMake(SCREEN_WIDTH * 0.5, SCREEN_HEIGHT * 0.15);
    lbe.textColor = [UIColor blackColor];
    lbe.textAlignment = NSTextAlignmentCenter;
    lbe.text = @"准备就绪";
    lbe.font = [UIFont systemFontOfSize:12];
    self.progressLbl = lbe;
    [self.view addSubview:lbe];
    
    UIImageView *bgImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"wapper0"]];
    bgImageView.contentMode = UIViewContentModeScaleAspectFill;
    bgImageView.frame = CGRectMake(0, 0.25 * SCREEN_HEIGHT, SCREEN_WIDTH, 0.75 * SCREEN_HEIGHT);
    bgImageView.clipsToBounds = YES;
    [self.view addSubview:bgImageView];
    
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
    UIVisualEffectView *effectview = [[UIVisualEffectView alloc] initWithEffect:blur];
    effectview.alpha = 1.0;
    effectview.frame = bgImageView.bounds;
    [bgImageView addSubview:effectview];
}

- (void)clickMakeVideo {
    
//    __weak typeof(self) weakSelf = self;
//    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        __strong typeof(weakSelf) strongSelf = weakSelf;
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [strongSelf makeVideo];
//        });
//    });
    self.progressLbl.text = @"开始制作...";
    [self makeVideo];
}

- (void)makeVideo {
    
    NSArray *imageArray = @[
        [UIImage imageNamed:@"wapper0"],
        [UIImage imageNamed:@"wapper1"],
        [UIImage imageNamed:@"wapper2"],
        [UIImage imageNamed:@"wapper3"],
        [UIImage imageNamed:@"wapper4"],
        [UIImage imageNamed:@"wapper5"],
        [UIImage imageNamed:@"wapper6"],
        [UIImage imageNamed:@"wapper7"]
    ];
    
    NSURL *audioURL = [[NSBundle mainBundle] URLForResource:@"Sound" withExtension:@"mp3"];
    AVURLAsset *audio = [AVURLAsset assetWithURL:audioURL];
    CMTime audioDuration =  CMTimeMakeWithSeconds(30, audio.duration.timescale);
    CMTimeRange timeRange = CMTimeRangeMake(kCMTimeZero, audioDuration);
    
    __weak typeof(self) weakSelf = self;
    self.maker.images = [imageArray copy];
    [self.maker exportVideo:audio audioTimeRange:timeRange completed:^(BOOL success, NSURL * _Nullable videoURL) {
        if (success) {
            NSLog(@"videoURL:%@", videoURL);
            weakSelf.videoPath = videoURL;
        }
    }].progress = ^(CGFloat progress) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        dispatch_async(dispatch_get_main_queue(), ^{
            strongSelf.progressLbl.text = [NSString stringWithFormat:@"progress:%.2f", progress];
        });
    };
    
}

- (void)playAction {
    
    AVPlayerViewController *vc = [[AVPlayerViewController alloc] init];
    vc.player = [[AVPlayer alloc] initWithURL:self.videoPath];
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:vc animated:YES completion:nil];
    
}

#pragma mark - lazy load

- (HcdVideoMaker *)maker {
    
    if (!_maker) {
        HcdVideoMaker *maker = [[HcdVideoMaker alloc] initWithImages:[NSMutableArray array] movement:ImageMovementFixed];
        maker.contentMode = UIViewContentModeScaleAspectFit;
        maker.blurBackground = YES;
        _maker = maker;
    };
    return _maker;
}

@end
