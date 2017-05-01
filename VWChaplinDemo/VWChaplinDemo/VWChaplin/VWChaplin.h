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

VWChaplinRange ChaplinMakeRange(int64_t location, int64_t length);

@interface VWChaplinSmile : NSObject

- (void)pause;

- (void)resumeCreateSession:(BOOL)shouldCreate;

@end

@interface VWChaplin : NSObject

- (VWChaplinSmile *)downloadWithMethod:(NSString *)method URLString:(NSString *)URLString params:(NSDictionary *)params progress:(void (^)(NSProgress *downloadProgress))downloadProgress destination:(NSURL *(^)(NSURL *targetPath, NSURLResponse *response))destination completionHandler:(void(^)(NSURL *filePath, NSError *error))completionHandler;


- (void)resumeDownladWithChaplinSmlie:(VWChaplinSmile *)smile;

@end
