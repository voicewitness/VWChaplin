//
//  VWChaplin.m
//  VWDownloaderDemo
//
//  Created by VoiceWitness on 27/04/2017.
//  Copyright © 2017 voicewh. All rights reserved.
//

#import "VWChaplin.h"

typedef void (^VWChaplinDownloadCompletionBlock) (NSURL *fileURL, NSError *error);

typedef NSURL* (^VWChaplinDownloadDestinationBlock) (NSURL *targetPath, NSURLResponse *response);

typedef void (^VWChaplinDownloadProgressBlock) (NSProgress *);

typedef NS_ENUM(NSInteger, VWChaplinTaskState) {
    VWChaplinTaskStateWait,
    VWChaplinTaskStateStarted,
    VWChaplinTaskStateCancelled,
    VWChaplinTaskStateCompleted,
};

@interface VWChaplinFileHelper : NSObject

+ (NSURL *)smileCacheDirectory;

+ (NSURL *)smileCachePath;

+ (NSURL *)targetFileCacheDirectory;

+ (NSURL *)targetFileCachePath;

@end

@implementation VWChaplinFileHelper

+ (NSURL *)smileCacheDirectory {
    return nil;
}

+ (NSURL *)smileCachePath {
    return nil;
}

+ (NSURL *)targetFileCacheDirectory {
    return nil;
}

+ (NSURL *)targetFileCachePathWithDownloadURL:(NSURL *)url {
    return nil;
}

@end

@interface VWChaplinSmile : NSObject <NSCoding>

@property (nonatomic) VWChaplinTaskState state;

@property (nonatomic) int64_t totalWrittenBytes;

@property (nonatomic, copy) VWChaplinDownloadProgressBlock downloadProgressBlock;

@property (nonatomic, copy) VWChaplinDownloadDestinationBlock downloadDestinationBlock;

@property (nonatomic, copy) VWChaplinDownloadCompletionBlock downloadCompletionBlock;

@property (nonatomic, strong) NSData *resumedData;

@end

@implementation VWChaplinSmile

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    
    self.totalWrittenBytes = [aDecoder decodeInt64ForKey:NSStringFromSelector(@selector(totalWrittenBytes))];
    self.downloadProgressBlock = [aDecoder decodeObjectForKey:@"downloadProgressBlock"];
    self.downloadDestinationBlock = [aDecoder decodeObjectForKey:@"downloadDestinationBlock"];
    self.downloadCompletionBlock = [aDecoder decodeObjectForKey:@"downloadCompletionBlock"];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInt64:self.totalWrittenBytes forKey:NSStringFromSelector(@selector(totalWrittenBytes))];
    [aCoder encodeObject:self.downloadProgressBlock forKey:@"downloadProgressBlock"];
    [aCoder encodeObject:self.downloadDestinationBlock forKey:@"downloadDestinationBlock"];
    [aCoder encodeObject:self.downloadCompletionBlock forKey:@"downloadCompletionBlock"];
}

@end

@interface VWChaplin()<NSURLSessionDownloadDelegate>

@property (nonatomic, strong) NSMutableArray *waitingQueue;

@property (nonatomic, strong) NSMutableDictionary *mutableSmilesKeyedByTaskIdentifier;

@property (nonatomic, strong) NSURLSession *session;

@property (nonatomic) NSUInteger executingTasksCount;

@end

@implementation VWChaplin

- (instancetype)init {
    self = [super init];
    
    self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil];
    self.mutableSmilesKeyedByTaskIdentifier = [NSMutableDictionary new];
    
    return self;
}

- (void)downloadWithMethod:(NSString *)method URLString:(NSString *)URLString params:(NSDictionary *)params progress:(VWChaplinDownloadProgressBlock)downloadProgress destination:(VWChaplinDownloadDestinationBlock)destination completionHandler:(VWChaplinDownloadCompletionBlock)completionHandler {
    NSMutableURLRequest *mutableRequest = [self mutableRequestWithMehod:method URLString:URLString params:params];
    [self downloadWithRequest:mutableRequest progress:downloadProgress destination:destination completionHandler:completionHandler];
}

- (void)downloadWithMethod:(NSString *)method URLString:(NSString *)URLString params:(NSDictionary *)params range:(VWChaplinRange)range progress:(VWChaplinDownloadProgressBlock)downloadProgress destination:(VWChaplinDownloadDestinationBlock)destination completionHandler:(VWChaplinDownloadCompletionBlock)completionHandler {
    NSMutableURLRequest *mutableRequest = [self mutableRequestWithMehod:method URLString:URLString params:params];
    NSString *rangeInHeader;
    if (range.length > 0) {
        rangeInHeader = [NSString stringWithFormat:@"bytes=%lld-%lld", range.location, range.location+range.length];
        
    } else {
        rangeInHeader = [NSString stringWithFormat:@"bytes=%lld", range.location];
    }
    [mutableRequest setValue:rangeInHeader forHTTPHeaderField:@"Range"];
    [self downloadWithRequest:mutableRequest progress:downloadProgress destination:destination completionHandler:completionHandler];
}

- (void)downloadWithRequest:(NSURLRequest *)request progress:(void (^)(NSProgress *))downloadProgress destination:(NSURL *(^)(NSURL *targetPath, NSURLResponse *response))destination completionHandler:(void (^)(NSURL *, NSError *))completionHandler {
    NSURLSessionDownloadTask *task = [self.session downloadTaskWithRequest:request];
    
    [self addSmileForSessionDownloadTask:task downloadProgress:downloadProgress destination:destination completionHandler:completionHandler];
    self.executingTasksCount++;
}

- (void)resumeDownladWithChaplinSmlie:(VWChaplinSmile *)smile {
    if (!smile.resumedData) {
        
    }
}

//- (void)pauseTask

- (void)addSmileForSessionDownloadTask:(NSURLSessionDownloadTask *)task
                      downloadProgress:(VWChaplinDownloadProgressBlock)downloadProgressBlock
                           destination:(VWChaplinDownloadDestinationBlock)destination
                     completionHandler:(VWChaplinDownloadCompletionBlock)completionHandler {
    VWChaplinSmile *smile = [VWChaplinSmile new];
    smile.downloadProgressBlock = downloadProgressBlock;
    smile.downloadDestinationBlock = destination;
    smile.downloadCompletionBlock = completionHandler;
    [smile addObserver:self forKeyPath:@"state" options:NSKeyValueObservingOptionNew context:nil];
    [self.mutableSmilesKeyedByTaskIdentifier setObject:smile forKey:@(task.taskIdentifier)];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([object isKindOfClass:[VWChaplinSmile class]]) {
        VWChaplinTaskState state = [change[NSKeyValueChangeNewKey] integerValue];
        if (state == VWChaplinTaskStateCancelled || state == VWChaplinTaskStateCompleted) {
            self.executingTasksCount--;
        }
    }
}

- (VWChaplinSmile *)smileForSessionTask:(NSURLSessionTask *)task {
    return [self.mutableSmilesKeyedByTaskIdentifier objectForKey:@(task.taskIdentifier)];
}

- (void)persistChaplinSmile:(VWChaplinSmile *)smile {
    [NSKeyedArchiver archiveRootObject:smile toFile:[[VWChaplinFileHelper smileCachePath]path]];
}

- (NSMutableURLRequest *)mutableRequestWithMehod:(NSString *)method URLString:(NSString *)URLString params:(NSDictionary *)params {
    NSMutableURLRequest *mutableRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:URLString]];
    mutableRequest.HTTPMethod = method;
    return mutableRequest;
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    VWChaplinSmile *smile = [self smileForSessionTask:downloadTask];
    NSURL *targetFilePath = nil;
    if (smile.downloadDestinationBlock) {
        targetFilePath = smile.downloadDestinationBlock(location, downloadTask.response);
    } else {
        targetFilePath = [VWChaplinFileHelper targetFileCachePathWithDownloadURL:downloadTask.currentRequest.URL];
    }
    NSError *fileError = nil;
    //TODO add thread
    [[NSFileManager new]moveItemAtURL:location toURL:targetFilePath error:&fileError];
    !smile.downloadCompletionBlock?:smile.downloadCompletionBlock(targetFilePath, fileError);
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes {
    
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    VWChaplinSmile *smile = [self smileForSessionTask:task];
    smile.state = VWChaplinTaskStateCompleted;
    !smile.downloadCompletionBlock?:smile.downloadCompletionBlock(nil, error);
}

@end
