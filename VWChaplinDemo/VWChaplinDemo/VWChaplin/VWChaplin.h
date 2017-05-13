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

typedef NS_OPTIONS(NSInteger, VWChaplinDownloadOption) {
    VWChaplinDownloadOptionResumable
};

VWChaplinRange ChaplinMakeRange(int64_t location, int64_t length);

@class VWChaplin;
@interface VWChaplinSmile : NSObject

@property (nonatomic, strong, readonly) NSString *smileIdentifier;

@property (nonatomic) BOOL resumable;

- (void)pause;

- (void)resume;

- (void)resumeInChaplin:(VWChaplin *)master;

@end

@interface VWChaplin : NSObject

@property (nonatomic, strong) dispatch_queue_t completionQueue;

+ (NSArray<VWChaplinSmile *> *)persistedSmiles;

- (VWChaplinSmile *)downloadWithMethod:(NSString *)method URLString:(NSString *)URLString params:(NSDictionary *)params options:(VWChaplinDownloadOption)options progress:(void (^)(NSProgress *downloadProgress))downloadProgress destination:(NSURL *(^)(NSURL *targetPath, NSURLResponse *response))destination completionHandler:(void(^)(NSURL *filePath, NSError *error))completionHandler;


- (void)resumeDownladWithChaplinSmlie:(VWChaplinSmile *)smile;
//- (void)resumeDownladWithChaplinSmlieId:(NSString *)smileId;

- (void)setTaskDidPausedBlock:(void(^)(VWChaplinSmile *smile))block;

@end
