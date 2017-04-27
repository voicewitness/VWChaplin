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

@interface VWChaplinSmile : NSObject

@property (nonatomic) int64_t totalWrittenBytes;

@property (nonatomic, copy) VWChaplinDownloadProgressBlock downloadProgressBlock;

@property (nonatomic, copy) VWChaplinDownloadCompletionBlock downloadCompletionBlock;

@property (nonatomic, strong) NSData *resumedData;

@end

@implementation VWChaplinSmile


@end

@interface VWChaplin()<NSURLSessionDownloadDelegate>

@property (nonatomic, strong) NSMutableArray *waitingQueue;

@property (nonatomic, strong) NSMutableDictionary *mutableSmilesKeyedByTaskIdentifier;

@property (nonatomic, strong) NSURLSession *session;

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
}

- (void)resumeDownladWithChaplinSmlie:(VWChaplinSmile *)smile {
    if (!smile.resumedData) {
        
    }
}

- (void)addSmileForSessionDownloadTask:(NSURLSessionDownloadTask *)task
                      downloadProgress:(VWChaplinDownloadProgressBlock)downloadProgressBlock
                           destination:(VWChaplinDownloadDestinationBlock)destination
                     completionHandler:(VWChaplinDownloadCompletionBlock)completionHandler {
    VWChaplinSmile *smile = [VWChaplinSmile new];
    smile.downloadProgressBlock = downloadProgressBlock;
    smile.downloadCompletionBlock = completionHandler;
    [self.mutableSmilesKeyedByTaskIdentifier setObject:smile forKey:@(task.taskIdentifier)];
}

- (NSMutableURLRequest *)mutableRequestWithMehod:(NSString *)method URLString:(NSString *)URLString params:(NSDictionary *)params {
    NSMutableURLRequest *mutableRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:URLString]];
    mutableRequest.HTTPMethod = method;
    return mutableRequest;
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes {
    
}

@end
