//
//  DownloadCell.h
//  VWChaplinDemo
//
//  Created by VoiceWitness on 01/05/2017.
//  Copyright © 2017 voicewh. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VWChaplin.h"

@interface DownloadCell : UITableViewCell

- (void)setUpWithTask:(VWChaplinSmile *)task;

- (void)updateProgress:(NSProgress *)progress;



@end
