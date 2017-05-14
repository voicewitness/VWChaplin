//
//  NormalDownloaderViewController.m
//  VWChaplinDemo
//
//  Created by VoiceWitness on 13/05/2017.
//  Copyright © 2017 voicewh. All rights reserved.
//

#import "NormalDownloaderViewController.h"
#import "DownloadCell.h"
#import "VWChaplin.h"

@interface NormalDownloaderViewController ()<UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) NSMutableArray *tasks;

@property (nonatomic, strong) NSMutableArray *cells;

@property (nonatomic, strong) VWChaplin *downloader;

@property (nonatomic) BOOL getPersistence;

@end

@implementation NormalDownloaderViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addTask)];
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    UITableView *tableView = [[UITableView alloc]initWithFrame:CGRectMake(0, 0, CGRectGetWidth(screenBounds), CGRectGetHeight(screenBounds))];
    tableView.dataSource = self;
    tableView.delegate = self;
    [self.view addSubview:tableView];
    self.tableView = tableView;
    self.downloader = [VWChaplin new];
    self.tasks = [NSMutableArray new];
    self.cells = [NSMutableArray new];
    if (self.getPersistence) {
        self.title = @"Auto resume persisted task";
        NSArray<VWChaplinSmile *> *smiles = [VWChaplin persistedSmiles];
        
        for (VWChaplinSmile *smile in smiles) {
            DownloadCell *cell = [DownloadCell new];
            [self.downloader resumeDownladWithChaplinSmlie:smile progress:^(NSProgress *downloadProgress) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [cell updateProgress:downloadProgress];
                });
            } destination:nil completionHandler:^(NSURL *filePath, NSError *error) {
                if (error) {
                    NSLog(@">>>>>>>>error:%@",error);
                }
            }];
            [cell setUpWithTask:smile];
            [self.tasks addObject:smile];
            [self.cells addObject:cell];
        }
        if (smiles.count > 0) {
            [self.tableView reloadData];
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)addTask {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Add URL" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.font = [UIFont systemFontOfSize:13];
        textField.textColor = [UIColor redColor];
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        DownloadCell *cell = [DownloadCell new];
        VWChaplinSmile *task = [self.downloader downloadWithMethod:@"GET" URLString:alert.textFields.lastObject.text params:nil options:0 progress:^(NSProgress *downloadProgress) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [cell updateProgress:downloadProgress];
            });
        } destination:nil completionHandler:^(NSURL *filePath, NSError *error) {
            if (error) {
                NSLog(@">>>>>>>>error:%@",error);
            }
        }];
        [cell setUpWithTask:task];
        [self.tasks addObject:task];
        [self.cells addObject:cell];
        [self.tableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"CANCEL" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.tasks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.cells[indexPath.row];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 100;
}

@end
