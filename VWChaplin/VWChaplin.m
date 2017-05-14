//
//  VWChaplin.m
//  VWDownloaderDemo
//
//  Created by VoiceWitness on 27/04/2017.
//  Copyright © 2017 voicewh. All rights reserved.
//

#import "VWChaplin.h"
#import <UIKit/UIKit.h>
#import <CommonCrypto/CommonDigest.h>

#define VWPrintError(where, error) NSLog(@"Error When %@:%@",where,error);

#define kDownloadConfigFile @"config.json"

typedef void (^VWChaplinDownloadCompletionBlock) (NSURL *fileURL, NSError *error);

typedef NSURL* (^VWChaplinDownloadDestinationBlock) (NSURL *targetPath, NSURLResponse *response);

typedef void (^VWChaplinDownloadProgressBlock) (NSProgress *);

typedef void (^VWChaplonTaskDidPausedBlock) (VWChaplinSmile *smile);

typedef NS_ENUM(NSInteger, VWChaplinTaskState) {
    VWChaplinTaskStateWait,
    VWChaplinTaskStateStarted,
    VWChaplinTaskStatePaused,
    VWChaplinTaskStatePersisted,
    VWChaplinTaskStateResumed,
    VWChaplinTaskStateCompleted,
};

VWChaplinRange ChaplinMakeRange(int64_t location, int64_t length) {
    return (VWChaplinRange){
        .location = location,
        .length = length
    };
}

static NSString * getMD5String(NSString *str) {
    
    if (str == nil) return nil;
    
    const char *cstring = str.UTF8String;
    unsigned char bytes[CC_MD5_DIGEST_LENGTH];
    CC_MD5(cstring, (CC_LONG)strlen(cstring), bytes);
    
    NSMutableString *md5String = [NSMutableString string];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [md5String appendFormat:@"%02x", bytes[i]];
    }
    return md5String;
}

static dispatch_semaphore_t _initChaplinFolderLock;

static dispatch_semaphore_t _smileConfigLock;

static dispatch_semaphore_t _taskConfigLock;

//static dispatch_semaphore_t _smileConfigLock;

static void _ChaplinInitConfigLock() {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _initChaplinFolderLock = dispatch_semaphore_create(1);
        _smileConfigLock = dispatch_semaphore_create(1);
        _taskConfigLock = dispatch_semaphore_create(1);
    });
}

#define ChaplinInitFolderLock() dispatch_semaphore_wait(_initChaplinFolderLock, DISPATCH_TIME_FOREVER)

#define ChaplinInitFolderUnlock() dispatch_semaphore_signal(_initChaplinFolderLock)

#define SmileConfigLock() dispatch_semaphore_wait(_smileConfigLock, DISPATCH_TIME_FOREVER)

#define SmileConfigUnlock() dispatch_semaphore_signal(_smileConfigLock)

#define TaskConfigLock() dispatch_semaphore_wait(_taskConfigLock, DISPATCH_TIME_FOREVER)

#define TaskConfigUnlock() dispatch_semaphore_signal(_taskConfigLock)

@interface VWChaplinFileHelper : NSObject

@end

@implementation VWChaplinFileHelper

+ (NSURL *)mainDirectory {
    static NSURL *targetCacheDir;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSFileManager *fileManager = [NSFileManager new];
        NSURL *documentDir = [fileManager URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
        targetCacheDir = [documentDir URLByAppendingPathComponent:@"VWChaplin"];
    });
    return targetCacheDir;
}

+ (NSURL *)archivedSmileConfigPath {
    return [[self smileCacheDirectory]URLByAppendingPathComponent:@"config.json"];
}

+ (NSURL *)smileCacheDirectory {
    static NSURL *smileCacheDir;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        smileCacheDir = [[self mainDirectory]URLByAppendingPathComponent:@"smile"];
    });
    return smileCacheDir;
}

+ (NSURL *)smileCachePathForSmile:(VWChaplinSmile *)smile {
    return [[[self smileCacheDirectory]URLByAppendingPathComponent:getMD5String(smile.smileIdentifier)]URLByAppendingPathExtension:@"data"];
}

+ (NSURL *)historyDirectory {
    return [[self mainDirectory]URLByAppendingPathComponent:@"history"];
}

+ (NSURL *)createHistoryForDownloadURL:(NSURL *)url {
    return [[self historyDirectory]URLByAppendingPathComponent:[url lastPathComponent]];
}

+ (NSMutableDictionary *)configWithConfileFile:(NSURL *)filePath error:(NSError **)errorPtr {
    NSData *configData = [NSData dataWithContentsOfURL:filePath options:NSDataReadingMappedIfSafe error:errorPtr];
    if (errorPtr!=NULL&&*errorPtr) {
        VWPrintError(@"Get Task Config", *errorPtr)
        return nil;
    }
    NSMutableDictionary *config = [NSJSONSerialization JSONObjectWithData:configData options:NSJSONReadingMutableContainers error:errorPtr];
    if (errorPtr!=NULL&&*errorPtr) {
        VWPrintError(@"Get Task Config", *errorPtr)
        return nil;
    }
    return config;
}

+ (void)updateConfig:(NSDictionary *)config toFile:(NSURL *)url {
    if (!config) {
        NSLog(@"config is nil");
        return;
    }
    NSData *configData = [NSJSONSerialization dataWithJSONObject:config options:NSJSONWritingPrettyPrinted error:nil];
    [configData writeToURL:url atomically:NO];
}

+ (NSMutableDictionary *)downloaderConfigWithError:(NSError **)errorPtr {
    return [self configWithConfileFile:[self mainDirectory] error:errorPtr];
}

+ (NSMutableDictionary *)archivedSmilesConfig {
    return [self archivedSmilesConfigWithError:nil];
}

+ (NSMutableDictionary *)archivedSmilesConfigWithError:(NSError **)errorPtr {
    return [self configWithConfileFile:[self archivedSmileConfigPath] error:errorPtr];
}

+ (NSMutableDictionary *)taskConfigWithDirectoryURL:(NSURL *)url error:(NSError **)errorPtr {
    return [self configWithConfileFile:[self configPathWithDirectory:url] error:errorPtr];
}

+ (NSURL *)configPathWithDirectory:(NSURL *)directory {
    return [directory URLByAppendingPathComponent:@"config.json"];
}

+ (void)updateSmileConfig:(NSDictionary *)config {
    [self updateConfig:config toFile:[self archivedSmileConfigPath]];
}

+ (void)updateTaskConfig:(NSDictionary *)config withDirectoryURL:(NSURL *)url {
    [self updateConfig:config toFile:[self configPathWithDirectory:url]];
}

+ (void)cleanSmileConfig {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtURL:[self smileCacheDirectory] error:nil];
    [self initDownloaderFolders];
}

+ (NSURL *)taskDirectoryWithDownloadURL:(NSURL *)url {
    return [[self mainDirectory]URLByAppendingPathComponent:getMD5String([url absoluteString])];
}

+ (NSURL *)taskConfigPathWithDownloadURL:(NSURL *)downloadURL {
    return [[self taskDirectoryWithDownloadURL:downloadURL]URLByAppendingPathComponent:@"config.json"];
}

+ (void)initDownloaderFolders {
    ChaplinInitFolderLock();
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *foldersNeedCreate = @[[self historyDirectory],[self smileCacheDirectory]];
    for (NSURL *folder in foldersNeedCreate) {
        if (![fileManager fileExistsAtPath:[folder path]]) {
            [fileManager createDirectoryAtPath:[folder path] withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    if(![fileManager fileExistsAtPath:[[self archivedSmileConfigPath]path]]) {
        [self updateSmileConfig:@{}];
    }
    ChaplinInitFolderUnlock();
}

+ (void)createTaskConfigWithURL:(NSURL *)downloadURL {
    TaskConfigLock();
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *downloadDirectory = [self taskDirectoryWithDownloadURL:downloadURL];
    NSURL *configPath = [self configPathWithDirectory:downloadDirectory];
    if (![fileManager fileExistsAtPath:[configPath path]]) {
        [fileManager createDirectoryAtPath:[downloadDirectory path] withIntermediateDirectories:YES attributes:nil error:nil];
        [self updateTaskConfig:@{} withDirectoryURL:downloadDirectory];
    }
    TaskConfigUnlock();
}
+ (void)saveSysTmpFileWithName:(NSString *)fileName forDownloadURL:(NSURL *)downloadURL {
    NSURL *tmpFilePath = [[NSURL fileURLWithPath:NSTemporaryDirectory()]URLByAppendingPathComponent:fileName];
    [self saveTmpFile:tmpFilePath forDownloadURL:downloadURL];
}

//+ (void)saveTmpData:(NSData *)fileData forDownloadURL:(NSURL *)downloadURL {
//    TaskConfigLock();
//    NSURL *taskDirectory = [self taskDirectoryWithDownloadURL:downloadURL];
//    NSError *error = nil;
//    NSMutableDictionary *taskConfig = [self taskConfigWithDirectoryURL:taskDirectory error:&error];
//    if (error) {
//        return;
//    }
//    NSMutableArray *files = taskConfig[@"files"];
//    if (!files) {
//        files = [NSMutableArray new];
//        taskConfig[@"files"] = files;
//    }
//    NSURL *fragment = [self genFileURLForOriginalFileURL:[taskDirectory URLByAppendingPathComponent:[downloadURL lastPathComponent]] withExistedFiles:files];
//    [fileData writeToURL:fragment atomically:NO];
//    [files addObject:[fragment absoluteString]];
//    [self updateTaskConfig:taskConfig withDirectoryURL:taskDirectory];
//    TaskConfigUnlock();
//}

+ (NSURL *)genFileURLForOriginalFileURL:(NSURL *)fileURL withExistedFiles:(NSArray *)existedFiles {
    NSString *extension = [@"." stringByAppendingString:[fileURL pathExtension]];
    NSString *fileURLString = [fileURL absoluteString];
    if(existedFiles.count > 0) {
        fileURL = [NSURL URLWithString:[fileURLString stringByReplacingCharactersInRange:NSMakeRange(fileURLString.length - extension.length, extension.length) withString:[NSString stringWithFormat:@"(%zd)%@",existedFiles.count,extension]]];
    }
    return fileURL;
}

+ (void)saveTmpFile:(NSURL *)tmp forDownloadURL:(NSURL *)downloadURL {
    TaskConfigLock();
    NSURL *taskDirectory = [self taskDirectoryWithDownloadURL:downloadURL];
    NSError *error = nil;
    NSMutableDictionary *taskConfig = [self taskConfigWithDirectoryURL:taskDirectory error:&error];
    if (error) {
        return;
    }
    NSMutableArray *files = taskConfig[@"files"];
    if (!files) {
        files = [NSMutableArray new];
        taskConfig[@"files"] = files;
    }
    NSURL *fragment = [self genFileURLForOriginalFileURL:[taskDirectory URLByAppendingPathComponent:[downloadURL lastPathComponent]] withExistedFiles:files];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager moveItemAtURL:tmp toURL:fragment error:nil];
    [files addObject:[fragment absoluteString]];
    [self updateTaskConfig:taskConfig withDirectoryURL:taskDirectory];
    TaskConfigUnlock();
}

+ (NSURL *)mergeTaskFragmentWithURL:(NSURL *)downloadURL toDestination:(NSURL *)destination {
    TaskConfigLock();
    NSURL *taskDirectory = [self taskDirectoryWithDownloadURL:downloadURL];
    NSError *error = nil;
    NSMutableDictionary *taskConfig = [self taskConfigWithDirectoryURL:taskDirectory error:&error];
    if (error) {
        return nil;
    }
    NSMutableArray *files = taskConfig[@"files"];
    taskConfig[@"status"] = @"merge";
    if (!destination) {
        destination = [self createHistoryForDownloadURL:downloadURL];
    }
    NSFileManager *fileManager = [NSFileManager defaultManager];
    for (NSInteger i = 0; i < files.count; i++) {
        NSString *file = files[i];
        if (i==0) {
            [fileManager moveItemAtURL:[NSURL URLWithString:file] toURL:destination error:&error];
            if (error) {
                VWPrintError(@"merge file", error);
            }
        } else {
            [self mergeFileFromURL:[NSURL URLWithString:file] toURL:destination error:nil];
        }
    }
    [fileManager removeItemAtURL:taskDirectory error:nil];
    TaskConfigUnlock();
    return destination;
}

+ (void)mergeFileFromURL:(NSURL *)from toURL:(NSURL *)to error:(NSError **)error {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:[to path]]) {
        [fileManager moveItemAtURL:from toURL:to error:error];
        return;
    }
    NSFileHandle *writerHandle = [NSFileHandle fileHandleForUpdatingURL:to error:nil];
    [writerHandle seekToEndOfFile];
    
    NSData *readerData = [NSData dataWithContentsOfURL:from options:NSDataReadingMappedIfSafe error:nil];
    [writerHandle writeData:readerData];
    [writerHandle synchronizeFile];
}

@end

@interface VWChaplinSmile() <NSCoding>

@property (nonatomic) BOOL hasParent;

@property (nonatomic, strong, readwrite) NSString *smileIdentifier;

@property (nonatomic, strong) NSURL *targetFilePath;

@property (nonatomic, weak, readwrite) VWChaplin *session;

@property (nonatomic, strong) NSURLSessionDownloadTask *downloadTask;

@property (nonatomic, strong) NSURLRequest *request;

@property (nonatomic) VWChaplinTaskState state;

@property (nonatomic) int64_t currentTaskWrittenBytes;

@property (nonatomic) int64_t currentTaskExpectedToWrite;

@property (nonatomic) int64_t totalWrittenBytes;

@property (nonatomic) int64_t totalBytesExpectedToWrite;

@property (nonatomic, strong) NSProgress *downloadProgress;

@property (nonatomic, copy) VWChaplinDownloadProgressBlock downloadProgressBlock;

@property (nonatomic, copy) VWChaplinDownloadDestinationBlock downloadDestinationBlock;

@property (nonatomic, copy) VWChaplinDownloadCompletionBlock downloadCompletionBlock;

@property (nonatomic, strong) NSData *resumeData;

@end

@implementation VWChaplinSmile

- (instancetype)init {
    self = [super init];
    self.downloadProgress = [[NSProgress alloc] initWithParent:nil userInfo:nil];
    self.downloadProgress.totalUnitCount = NSURLSessionTransferSizeUnknown;
    
    return self;
}

- (void)setUpForDownloadTask:(NSURLSessionDownloadTask *)task {
    [VWChaplinFileHelper createTaskConfigWithURL:self.request.URL];
    self.downloadTask = task;
    self.request = task.originalRequest;
    self.smileIdentifier = [task.originalRequest.URL absoluteString];
    [task addObserver:self
           forKeyPath:NSStringFromSelector(@selector(countOfBytesExpectedToReceive))
              options:NSKeyValueObservingOptionNew
              context:NULL];
}

- (void)cleanUpTask {
    [self.downloadTask removeObserver:self forKeyPath:NSStringFromSelector(@selector(countOfBytesExpectedToReceive))];
    self.downloadTask = nil;
}

- (void)cleanUp {
    [self cleanUpTask];
}

- (void)pause {
    [self cancelWithResumeData:nil];
}

- (void)pauseWithResumeData:(void(^)(NSData *resumeData))completionHandler {
    self.state = VWChaplinTaskStatePaused;
    [self cancelWithResumeData:completionHandler];
}

- (void)cancelWithResumeData:(void(^)(NSData *resumeData))completionHandler {
    [self.downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        self.resumeData = resumeData;
        self.totalWrittenBytes += self.currentTaskWrittenBytes;
        !completionHandler?:completionHandler(resumeData);
    }];
    [self cleanUpTask];
}

- (void)pauseAndPersist {
    [self pauseWithResumeData:^(NSData *resumeData) {
        [self persist];
        NSDictionary *resumeDict = [NSPropertyListSerialization propertyListWithData:resumeData options:NSPropertyListImmutable format:NULL error:nil];
        NSString *tmpFileName = resumeDict[@"NSURLSessionResumeInfoTempFileName"];
        [VWChaplinFileHelper saveSysTmpFileWithName:tmpFileName forDownloadURL:self.request.URL];
    }];
    self.state = VWChaplinTaskStatePersisted;
}

- (void)persist {
    [NSKeyedArchiver archiveRootObject:self toFile:[[VWChaplinFileHelper smileCachePathForSmile:self]path]];
}

- (VWChaplinRange)rangeForResume {
    int64_t location = 0;
    int64_t length = 0;
    location = self.totalWrittenBytes;
    length = self.totalBytesExpectedToWrite - self.totalWrittenBytes;
    VWChaplinRange range = ChaplinMakeRange(location, length);
    return range;
}

- (void)resume {
    NSAssert(self.session, @"ChaplinSmile Shoule be managed by Chaplin");
    [self.session resumeDownladWithChaplinSmlie:self];
}

- (void)resumeInChaplin:(VWChaplin *)master {
    self.session = master;
    [self resume];
}

- (void)_completeWithError:(NSError *)error {
    self.state = VWChaplinTaskStateCompleted;
    dispatch_async(self.session.completionQueue?:dispatch_get_main_queue(), ^{
        !self.downloadCompletionBlock?:self.downloadCompletionBlock(self.targetFilePath, error);
    });
}

- (VWChaplin *)currentSession {
    return self.session;
}

- (void)updateCurrentTaskWritten:(int64_t)currentTaskWrittenBytes {
    self.currentTaskWrittenBytes = currentTaskWrittenBytes;
    [self updateTotalWritten];
}

- (void)updateTotalWritten {
    self.downloadProgress.completedUnitCount = self.totalWrittenBytes + self.currentTaskWrittenBytes;
    !self.downloadProgressBlock?:self.downloadProgressBlock(self.downloadProgress);
}

- (void)dealloc {
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(countOfBytesExpectedToReceive))]) {
        int64_t expectedToWrite = [change[NSKeyValueChangeNewKey]longLongValue];
        if (self.state == VWChaplinTaskStateResumed) {
            self.currentTaskExpectedToWrite = expectedToWrite;
        } else {
            self.totalBytesExpectedToWrite = expectedToWrite;
            self.downloadProgress.totalUnitCount = self.totalBytesExpectedToWrite;
        }
    }
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [self init];
    
    self.totalWrittenBytes = [aDecoder decodeInt64ForKey:NSStringFromSelector(@selector(totalWrittenBytes))];
    self.totalBytesExpectedToWrite = [aDecoder decodeInt64ForKey:NSStringFromSelector(@selector(totalBytesExpectedToWrite))];
    self.request = [aDecoder decodeObjectForKey:NSStringFromSelector(@selector(request))];
    self.downloadProgress.completedUnitCount = self.totalWrittenBytes;
    self.downloadProgress.totalUnitCount = self.totalBytesExpectedToWrite;
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeInt64:self.totalWrittenBytes forKey:NSStringFromSelector(@selector(totalWrittenBytes))];
    [aCoder encodeInt64:self.totalBytesExpectedToWrite forKey:NSStringFromSelector(@selector(totalBytesExpectedToWrite))];
    [aCoder encodeObject:self.request forKey:NSStringFromSelector(@selector(request))];
}

@end

@interface VWChaplin()<NSURLSessionDownloadDelegate>

@property (nonatomic, strong) NSMutableArray *waitingQueue;

@property (nonatomic, strong) NSMutableDictionary *mutableSmilesKeyedByTaskIdentifier;

@property (nonatomic, strong) NSURLSession *session;

@property (nonatomic) NSUInteger executingTasksCount;

@property (nonatomic) UIBackgroundTaskIdentifier backgroundTaskId;

@property (nonatomic, copy) VWChaplonTaskDidPausedBlock taskDidPausedBlock;

@end

@implementation VWChaplin

- (instancetype)init {
    self = [super init];
    
    _ChaplinInitConfigLock();
    [VWChaplinFileHelper initDownloaderFolders];
    self.session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:nil];
    self.mutableSmilesKeyedByTaskIdentifier = [NSMutableDictionary new];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate) name:UIApplicationWillTerminateNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidReceiveMemoryWarning) name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    
    return self;
}

+ (NSArray<VWChaplinSmile *> *)persistedSmiles {
    return [self persistedSmilesShouldClean:YES];
}

+ (NSArray<VWChaplinSmile *> *)persistedSmilesShouldClean:(BOOL)shouldClean {
    SmileConfigLock();
    NSMutableDictionary *config = [VWChaplinFileHelper archivedSmilesConfig];
    if (!config) {
        return nil;
    }
    NSMutableArray<VWChaplinSmile *> *array = [NSMutableArray<VWChaplinSmile *> new];
    for(NSString *file in config.allValues) {
        VWChaplinSmile *smile = [NSKeyedUnarchiver unarchiveObjectWithFile:file];
        if(smile) [array addObject:smile];
    }
    if (shouldClean) {
        [VWChaplinFileHelper cleanSmileConfig];
    }
    SmileConfigUnlock();
    return array;
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

#pragma mark Download

- (NSMutableURLRequest *)mutableRequestWithMehod:(NSString *)method URLString:(NSString *)URLString params:(NSDictionary *)params {
    NSMutableURLRequest *mutableRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:URLString]];
    mutableRequest.HTTPMethod = method;
    return mutableRequest;
}

- (VWChaplinSmile *)downloadWithMethod:(NSString *)method URLString:(NSString *)URLString params:(NSDictionary *)params options:(VWChaplinDownloadOption)options progress:(VWChaplinDownloadProgressBlock)downloadProgress destination:(VWChaplinDownloadDestinationBlock)destination completionHandler:(VWChaplinDownloadCompletionBlock)completionHandler {
    NSMutableURLRequest *mutableRequest = [self mutableRequestWithMehod:method URLString:URLString params:params];
    return [self downloadWithRequest:mutableRequest options:options progress:downloadProgress destination:destination completionHandler:completionHandler];
}

- (void)downloadWithMethod:(NSString *)method URLString:(NSString *)URLString params:(NSDictionary *)params range:(VWChaplinRange)range progress:(VWChaplinDownloadProgressBlock)downloadProgress destination:(VWChaplinDownloadDestinationBlock)destination completionHandler:(VWChaplinDownloadCompletionBlock)completionHandler {
    NSMutableURLRequest *mutableRequest = [self mutableRequestWithMehod:method URLString:URLString params:params];
    [self setUpRangeRequest:mutableRequest withRange:range];
    [self downloadWithRequest:mutableRequest options:0 progress:downloadProgress destination:destination completionHandler:completionHandler];
}

- (VWChaplinSmile *)downloadWithRequest:(NSURLRequest *)request options:(VWChaplinDownloadOption)options progress:(void (^)(NSProgress *))downloadProgress destination:(NSURL *(^)(NSURL *targetPath, NSURLResponse *response))destination completionHandler:(void (^)(NSURL *, NSError *))completionHandler {
    NSURLSessionDownloadTask *task = [self.session downloadTaskWithRequest:request];
    
    VWChaplinSmile *smile = [VWChaplinSmile new];
    smile.request = request;
    smile.resumable = options&VWChaplinDownloadOptionResumable;
    [self setUpSmile:smile forSessionDownloadTask:task downloadProgress:downloadProgress destination:destination completionHandler:completionHandler];
    self.executingTasksCount++;
    [task resume];
    return smile;
}

- (VWChaplinSmile *)downloadWithResumeData:(NSData *)resumeData progress:(void (^)(NSProgress *))downloadProgress destination:(NSURL *(^)(NSURL *targetPath, NSURLResponse *response))destination completionHandler:(void (^)(NSURL *, NSError *))completionHandler {
    NSURLSessionDownloadTask *task = [self.session downloadTaskWithResumeData:resumeData];
    VWChaplinSmile *smile = [VWChaplinSmile new];
    smile.resumeData = resumeData;
    [self setUpSmile:smile forSessionDownloadTask:task downloadProgress:downloadProgress destination:destination completionHandler:completionHandler];
    self.executingTasksCount++;
    [task resume];
    return smile;
}

- (void)resumeDownladWithChaplinSmlie:(VWChaplinSmile *)smile {
    smile.state = VWChaplinTaskStateResumed;
    [self downloadWithLinkedSmile:smile progress:smile.downloadProgressBlock destination:smile.downloadDestinationBlock completionHandler:smile.downloadCompletionBlock];
}

- (void)resumeDownladWithChaplinSmlie:(VWChaplinSmile *)smile progress:(void (^)(NSProgress *))downloadProgress destination:(NSURL *(^)(NSURL *targetPath, NSURLResponse *response))destination completionHandler:(void (^)(NSURL *, NSError *))completionHandler {
    smile.state = VWChaplinTaskStateResumed;
    [self downloadWithLinkedSmile:smile progress:downloadProgress destination:destination completionHandler:completionHandler];
}

//- (void)resumeDownladWithChaplinSmlieId:(NSString *)smileId {
//
//}

- (void)downloadWithLinkedSmile:(VWChaplinSmile *)smile progress:(void (^)(NSProgress *))downloadProgress destination:(NSURL *(^)(NSURL *targetPath, NSURLResponse *response))destination completionHandler:(void (^)(NSURL *, NSError *))completionHandler {
    NSURLSessionDownloadTask *task;
    if (smile.resumable && smile.resumeData) {
        task = [self.session downloadTaskWithResumeData:smile.resumeData];
    } else {
        NSMutableURLRequest *mutableRequest = [smile.request mutableCopy];
        [self setUpRangeRequest:mutableRequest withRange:[smile rangeForResume]];
        task = [self.session downloadTaskWithRequest:mutableRequest];
    }
    [self setUpSmile:smile forSessionDownloadTask:task downloadProgress:downloadProgress destination:destination completionHandler:completionHandler];
    self.executingTasksCount++;
    [task resume];
}

#pragma mark Manage Task

- (void)setUpSmile:(VWChaplinSmile *)smile forSessionDownloadTask:(NSURLSessionDownloadTask *)task
                                  downloadProgress:(VWChaplinDownloadProgressBlock)downloadProgressBlock
                                       destination:(VWChaplinDownloadDestinationBlock)destination
 completionHandler:(VWChaplinDownloadCompletionBlock)completionHandler {
        smile.downloadProgressBlock = downloadProgressBlock;
        smile.downloadDestinationBlock = destination;
        smile.downloadCompletionBlock = completionHandler;
    smile.session = self;
    [self linkSmile:smile withDownloadTask:task];
}

- (void)linkSmile:(VWChaplinSmile *)smile withDownloadTask:(NSURLSessionDownloadTask *)task {
    [smile setUpForDownloadTask:task];
    [self.mutableSmilesKeyedByTaskIdentifier setObject:smile forKey:@(task.taskIdentifier)];
}

- (void)cleanUpTask:(NSURLSessionTask *)task {
    VWChaplinSmile *smile = [self smileForSessionTask:task];
    [smile cleanUp];
    [self.mutableSmilesKeyedByTaskIdentifier removeObjectForKey:@(task.taskIdentifier)];
}

- (void)suspendAll {
    for (VWChaplinSmile *smile in self.mutableSmilesKeyedByTaskIdentifier.allValues) {
        [smile pause];
    }
}

- (void)persistAll {
    SmileConfigLock();
    NSError *error = nil;
    NSMutableDictionary *config = [VWChaplinFileHelper archivedSmilesConfigWithError:&error];
    if (error) {
        if (error.code == 260) {
            config = [NSMutableDictionary new];
        } else {
            return;
        }
    }
    if (!config) {
        config = [NSMutableDictionary new];
    }
    for (VWChaplinSmile *smile in self.mutableSmilesKeyedByTaskIdentifier.allValues) {
        if (smile.state == VWChaplinTaskStatePersisted) {
            continue;
        }
        [smile pauseAndPersist];
        [config setObject:[[VWChaplinFileHelper smileCachePathForSmile:smile]path] forKey:smile.smileIdentifier];
    }
    [VWChaplinFileHelper updateSmileConfig:config];
    SmileConfigUnlock();
}

- (VWChaplinSmile *)smileForSessionTask:(NSURLSessionTask *)task {
    return [self.mutableSmilesKeyedByTaskIdentifier objectForKey:@(task.taskIdentifier)];
}

#pragma mark Action

- (void)applicationWillTerminate {
    [self persistAll];
}

- (void)applicationDidReceiveMemoryWarning {
    [self persistAll];
}

- (void)applicationWillResignActive {
    __weak __typeof__ (self) wself = self;
    UIApplication * app = [UIApplication sharedApplication];
    self.backgroundTaskId = [app beginBackgroundTaskWithExpirationHandler:^{
        __strong __typeof (wself) sself = wself;
        if (sself) {
            [sself persistAll];
            [app endBackgroundTask:sself.backgroundTaskId];
            sself.backgroundTaskId = UIBackgroundTaskInvalid;
        }
    }];
}

#pragma mark URLSessionDelegate

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    VWChaplinSmile *smile = [self smileForSessionTask:downloadTask];
    smile.session = self;
    NSURL *targetFilePath = nil;
    if (smile.downloadDestinationBlock) {
        targetFilePath = smile.downloadDestinationBlock(location, downloadTask.response);
    }
    [VWChaplinFileHelper saveTmpFile:location forDownloadURL:downloadTask.originalRequest.URL];
    if (!smile.hasParent) {
        targetFilePath = [VWChaplinFileHelper mergeTaskFragmentWithURL:downloadTask.originalRequest.URL toDestination:targetFilePath];
        smile.targetFilePath = targetFilePath;
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    VWChaplinSmile *smile = [self smileForSessionTask:downloadTask];
    [smile updateCurrentTaskWritten:totalBytesWritten];
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes {
    
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    VWChaplinSmile *smile = [self smileForSessionTask:task];
    self.executingTasksCount--;
    if (smile.state == VWChaplinTaskStatePaused || smile.state == VWChaplinTaskStatePersisted) {
        !self.taskDidPausedBlock?:self.taskDidPausedBlock(smile);
        [self.mutableSmilesKeyedByTaskIdentifier removeObjectForKey:@(smile.downloadTask.taskIdentifier)];
    } else {
        [smile _completeWithError:error];
    }
    [self cleanUpTask:task];
}

#pragma mark - Setter
- (void)setTaskDidPausedBlock:(void (^)(VWChaplinSmile *))block {
    self.taskDidPausedBlock = block;
}

@end
