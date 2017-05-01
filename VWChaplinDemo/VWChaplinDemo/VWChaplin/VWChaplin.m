//
//  VWChaplin.m
//  VWDownloaderDemo
//
//  Created by VoiceWitness on 27/04/2017.
//  Copyright © 2017 voicewh. All rights reserved.
//

#import "VWChaplin.h"
#import <UIKit/UIKit.h>

typedef void (^VWChaplinDownloadCompletionBlock) (NSURL *fileURL, NSError *error);

typedef NSURL* (^VWChaplinDownloadDestinationBlock) (NSURL *targetPath, NSURLResponse *response);

typedef void (^VWChaplinDownloadProgressBlock) (NSProgress *);

typedef NS_ENUM(NSInteger, VWChaplinTaskState) {
    VWChaplinTaskStateWait,
    VWChaplinTaskStateStarted,
    VWChaplinTaskStateCancelled,
    VWChaplinTaskStateCompleted,
};

VWChaplinRange ChaplinMakeRange(int64_t location, int64_t length) {
    return (VWChaplinRange){
        .location = location,
        .length = length
    };
}

@interface VWChaplinFileHelper : NSObject

+ (NSURL *)smileCacheDirectory;

+ (NSURL *)smileCachePath;

+ (NSURL *)targetFileCacheDirectory;

+ (NSURL *)targetFileCachePathWithDownloadURL:(NSURL *)url;

@end

@implementation VWChaplinFileHelper

+ (NSURL *)smileCacheDirectory {
    
    static NSURL *smileCacheDir;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSFileManager *fileManager = [NSFileManager new];
        NSURL *documentDir = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
        smileCacheDir = [documentDir URLByAppendingPathComponent:@"VWChaplinSmile"];
    });
    return smileCacheDir;
}

+ (NSURL *)smileCachePath {
    return nil;
}

+ (NSURL *)targetFileCacheDirectory {
    static NSURL *targetCacheDir;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSFileManager *fileManager = [NSFileManager new];
        NSURL *documentDir = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
        targetCacheDir = [documentDir URLByAppendingPathComponent:@"VWChaplinSmile"];
    });
    return targetCacheDir;
}

+ (NSURL *)targetFileCachePathWithDownloadURL:(NSURL *)url {
    return [[[self targetFileCacheDirectory]URLByAppendingPathComponent:url.lastPathComponent]URLByAppendingPathExtension:url.pathExtension];
}

@end

@interface VWChaplinSmile() <NSCoding>

@property (nonatomic, weak, readwrite) VWChaplin *session;

@property (nonatomic, weak) NSURLSessionDownloadTask *downloadTask;

@property (nonatomic, strong) NSURLRequest *request;

@property (nonatomic) VWChaplinTaskState state;

@property (nonatomic) int64_t totalWrittenBytes;

@property (nonatomic) int64_t totalBytesExpectedToWrite;

@property (nonatomic, strong) NSProgress *downloadProgress;

@property (nonatomic, copy) VWChaplinDownloadProgressBlock downloadProgressBlock;

@property (nonatomic, copy) VWChaplinDownloadDestinationBlock downloadDestinationBlock;

@property (nonatomic, copy) VWChaplinDownloadCompletionBlock downloadCompletionBlock;

@property (nonatomic, strong) NSData *resumedData;

@end

@implementation VWChaplinSmile

- (instancetype)init {
    self = [super init];
    
    self.downloadProgress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
    self.downloadProgress.totalUnitCount = NSURLSessionTransferSizeUnknown;
    
    return self;
}

- (void)setUpForDownloadTask:(NSURLSessionDownloadTask *)task {
    self.downloadTask = task;
    [task addObserver:self
           forKeyPath:NSStringFromSelector(@selector(countOfBytesExpectedToReceive))
              options:NSKeyValueObservingOptionNew
              context:NULL];
}

- (void)cleanUp {
    [self.downloadTask removeObserver:self forKeyPath:NSStringFromSelector(@selector(countOfBytesExpectedToReceive))];
}

- (void)pause {
    [self cancelWithResumeData:nil];
}

- (void)cancelWithResumeData:(void(^)(NSData *resumeData))completionHandler {
    [self.downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        !completionHandler?:completionHandler(resumeData);
    }];
    self.state = VWChaplinTaskStateCancelled;
}

- (VWChaplinRange)range {
    NSArray *rangeArr = [[[self.request valueForHTTPHeaderField:@"Range"]stringByReplacingOccurrencesOfString:@"bytes=" withString:@""]componentsSeparatedByString:@"-"];
    int64_t length = 0;
    if (rangeArr.count == 2) {
        length = [[rangeArr.lastObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]longLongValue];
    }
    VWChaplinRange range = ChaplinMakeRange([[rangeArr.firstObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]longLongValue], length);
    return range;
}

- (void)resumeCreateSession:(BOOL)shouldCreate {
    if (!self.session && shouldCreate) {
        [[VWChaplin new]resumeDownladWithChaplinSmlie:self];
    } else {
        [self resume];
    }
}

- (void)resume {
    [self.session resumeDownladWithChaplinSmlie:self];
}

- (VWChaplin *)currentSession {
    return self.session;
}

- (void)dealloc {
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(countOfBytesExpectedToReceive))]) {
        self.totalBytesExpectedToWrite = [change[NSKeyValueChangeNewKey]longLongValue];
        self.downloadProgress.totalUnitCount = self.totalBytesExpectedToWrite;
    }
}

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

- (void)setTotalWrittenBytes:(int64_t)totalWrittenBytes {
    _totalWrittenBytes = totalWrittenBytes;
    self.downloadProgress.completedUnitCount = totalWrittenBytes;
    !self.downloadProgressBlock?:self.downloadProgressBlock(self.downloadProgress);
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
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate) name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    return self;
}

- (VWChaplinSmile *)downloadWithMethod:(NSString *)method URLString:(NSString *)URLString params:(NSDictionary *)params progress:(VWChaplinDownloadProgressBlock)downloadProgress destination:(VWChaplinDownloadDestinationBlock)destination completionHandler:(VWChaplinDownloadCompletionBlock)completionHandler {
    NSMutableURLRequest *mutableRequest = [self mutableRequestWithMehod:method URLString:URLString params:params];
    return [self downloadWithRequest:mutableRequest progress:downloadProgress destination:destination completionHandler:completionHandler];
}

- (void)downloadWithMethod:(NSString *)method URLString:(NSString *)URLString params:(NSDictionary *)params range:(VWChaplinRange)range progress:(VWChaplinDownloadProgressBlock)downloadProgress destination:(VWChaplinDownloadDestinationBlock)destination completionHandler:(VWChaplinDownloadCompletionBlock)completionHandler {
    NSMutableURLRequest *mutableRequest = [self mutableRequestWithMehod:method URLString:URLString params:params];
    [self setUpRangeRequest:mutableRequest withRange:range];
    [self downloadWithRequest:mutableRequest progress:downloadProgress destination:destination completionHandler:completionHandler];
}

- (VWChaplinSmile *)downloadWithRequest:(NSURLRequest *)request progress:(void (^)(NSProgress *))downloadProgress destination:(NSURL *(^)(NSURL *targetPath, NSURLResponse *response))destination completionHandler:(void (^)(NSURL *, NSError *))completionHandler {
    NSURLSessionDownloadTask *task = [self.session downloadTaskWithRequest:request];
    
    VWChaplinSmile *smile = [self addSmileForSessionDownloadTask:task downloadProgress:downloadProgress destination:destination completionHandler:completionHandler];
    self.executingTasksCount++;
    [task resume];
    return smile;
}

- (void)setUpRangeRequest:(NSMutableURLRequest*)request withRange:(VWChaplinRange)range {
    NSString *rangeInHeader;
    if (range.length > 0) {
        rangeInHeader = [NSString stringWithFormat:@"bytes=%lld-%lld", range.location, range.location+range.length];
        
    } else {
        rangeInHeader = [NSString stringWithFormat:@"bytes=%lld", range.location];
    }
    [request setValue:rangeInHeader forHTTPHeaderField:@"Range"];
}

- (void)suspendAll {
    for (VWChaplinSmile *smile in self.mutableSmilesKeyedByTaskIdentifier.allValues) {
        [smile pause];
    }
}

- (void)resumeDownladWithChaplinSmlie:(VWChaplinSmile *)smile {
    if (!smile.resumedData) {
        NSMutableURLRequest *mutableRequest = [smile.request mutableCopy];
        [self setUpRangeRequest:mutableRequest withRange:[smile range]];
        [self downloadWithRequest:mutableRequest progress:smile.downloadProgressBlock destination:smile.downloadDestinationBlock completionHandler:smile.downloadCompletionBlock];
    }
}

- (VWChaplinSmile *)addSmileForSessionDownloadTask:(NSURLSessionDownloadTask *)task
                      downloadProgress:(VWChaplinDownloadProgressBlock)downloadProgressBlock
                           destination:(VWChaplinDownloadDestinationBlock)destination
                     completionHandler:(VWChaplinDownloadCompletionBlock)completionHandler {
    VWChaplinSmile *smile = [VWChaplinSmile new];
    [smile setUpForDownloadTask:task];
    smile.downloadProgressBlock = downloadProgressBlock;
    smile.downloadDestinationBlock = destination;
    smile.downloadCompletionBlock = completionHandler;
    [smile addObserver:self forKeyPath:@"state" options:NSKeyValueObservingOptionNew context:nil];
    [self.mutableSmilesKeyedByTaskIdentifier setObject:smile forKey:@(task.taskIdentifier)];
    return smile;
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

- (void)applicationWillTerminate {
    
}

- (void)applicationDidReceiveMemoryWarning {
    
}

- (void)applicationWillResignActive {
    
}

- (void)applicationDidBecomeActive {
    
}

- (void)persistChaplinSmile:(VWChaplinSmile *)smile {
    [NSKeyedArchiver archiveRootObject:smile toFile:[[VWChaplinFileHelper smileCachePath]path]];
}

- (NSMutableURLRequest *)mutableRequestWithMehod:(NSString *)method URLString:(NSString *)URLString params:(NSDictionary *)params {
    NSMutableURLRequest *mutableRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:URLString]];
    mutableRequest.HTTPMethod = method;
    return mutableRequest;
}

- (void)cleanUpTask:(NSURLSessionTask *)task {
    VWChaplinSmile *smile = [self smileForSessionTask:task];
    [smile cleanUp];
    [self.mutableSmilesKeyedByTaskIdentifier removeObjectForKey:@(task.taskIdentifier)];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    VWChaplinSmile *smile = [self smileForSessionTask:downloadTask];
    smile.session = self;
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
    VWChaplinSmile *smile = [self smileForSessionTask:downloadTask];
    smile.totalWrittenBytes = totalBytesWritten;
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes {
    
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if(error) {
        VWChaplinSmile *smile = [self smileForSessionTask:task];
        smile.state = VWChaplinTaskStateCompleted;
        !smile.downloadCompletionBlock?:smile.downloadCompletionBlock(nil, error);
        [smile cleanUp];
    }
    [self cleanUpTask:task];
}

@end
