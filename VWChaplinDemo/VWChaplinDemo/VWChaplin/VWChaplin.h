//
//  VWChaplin.h
//  VWDownloaderDemo
//
//  Created by VoiceWitness on 27/04/2017.
//  Copyright © 2017 voicewh. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct _VWChaplinRange {
    int64_t location;
    int64_t length;
} VWChaplinRange;

@interface VWChaplin : NSObject

- (void)downloadWithMethod:(NSString *)method URLString:(NSString *)URLString progress:(void (^)(NSProgress *downloadProgress))downloadProgress destination:(NSURL *(^)(NSURL *suggestedPath))destination completionHandler:(void(^)(NSURL *filePath, NSError *error))completionHandler;

@end
