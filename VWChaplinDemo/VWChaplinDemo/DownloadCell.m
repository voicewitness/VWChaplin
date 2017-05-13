//
//  DownloadCell.m
//  VWChaplinDemo
//
//  Created by VoiceWitness on 01/05/2017.
//  Copyright © 2017 voicewh. All rights reserved.
//

#import "DownloadCell.h"

typedef NS_ENUM(NSInteger, DownloadState) {
    DownloadStateWait,
    DownloadStateStarted,
    DownloadStatePaused,
    DownloadStateEnded,
};

#define KB 1000.0f
#define MB (KB*KB)

@interface DownloadCell()

@property (nonatomic, strong) UIProgressView *progressView;

@property (nonatomic, strong) UIButton *actionButton;

@property (nonatomic) DownloadState state;

@property (nonatomic, weak) VWChaplinSmile *task;

@property (nonatomic, strong) UILabel *progressLabel;

@end

@implementation DownloadCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    UIProgressView *progressView = [[UIProgressView alloc]initWithFrame:CGRectMake(80, 20, 200, 5)];
    [self.contentView addSubview:progressView];
    self.progressView = progressView;
    
    UILabel *progressLabel = [[UILabel alloc]initWithFrame:CGRectMake(80, 30, 200, 30)];
    [self.contentView addSubview:progressLabel];
    self.progressLabel = progressLabel;
    
    UIButton *actionButton = [UIButton buttonWithType:UIButtonTypeSystem];
    actionButton.frame = CGRectMake(CGRectGetWidth([UIScreen mainScreen].bounds)-120, 20, 100, 44);
    actionButton.backgroundColor = [UIColor grayColor];
    [actionButton addTarget:self action:@selector(exeAction) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:actionButton];
    self.actionButton = actionButton;
    
    return self;
}

- (void)setUpWithTask:(VWChaplinSmile *)task {
    self.task = task;
    self.state = DownloadStateStarted;
}

- (void)updateProgress:(NSProgress *)progress {
    self.progressView.progress = progress.completedUnitCount/progress.totalUnitCount;
    self.progressLabel.text = [NSString stringWithFormat:@"%.2f/%.2f MB",[[NSNumber numberWithLongLong:progress.completedUnitCount]doubleValue]/MB,[[NSNumber numberWithLongLong:progress.totalUnitCount]doubleValue]/MB];
    if (llabs(progress.completedUnitCount-progress.totalUnitCount)<=CGFLOAT_MIN) {
        self.state = DownloadStateEnded;
    }
}

- (void)exeAction {
    switch (self.state) {
        case DownloadStateWait:
            self.state = DownloadStateStarted;
            break;
        case DownloadStateStarted:
            [self.task pause];
            self.state = DownloadStatePaused;
            break;
        case DownloadStatePaused:
            [self.task resume];
            self.state = DownloadStateStarted;
            break;
            
        default:
            break;
    }
}

- (void)setState:(DownloadState)state {
    _state = state;
    switch (state) {
        case DownloadStateStarted:
            [self.actionButton setTitle:@"Pause" forState:UIControlStateNormal];
            break;
        case DownloadStatePaused:
            [self.actionButton setTitle:@"Resume" forState:UIControlStateNormal];
            break;
        case DownloadStateEnded:
            [self.actionButton setTitle:@"Completed" forState:UIControlStateNormal];
            break;
            
        default:
            break;
    }
}

@end
