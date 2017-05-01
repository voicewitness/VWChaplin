//
//  ViewController.m
//  VWChaplinDemo
//
//  Created by VoiceWitness on 27/04/2017.
//  Copyright © 2017 voicewh. All rights reserved.
//

#import "ViewController.h"
#import "DownloadCell.h"
#import "VWChaplin.h"

@interface ViewController ()<UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;

@property (nonatomic, strong) NSMutableArray *tasks;

@property (nonatomic, strong) NSMutableArray *cells;

@property (nonatomic, strong) VWChaplin *downloader;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    UITableView *tableView = [[UITableView alloc]initWithFrame:CGRectMake(0, 64, CGRectGetWidth(screenBounds), CGRectGetHeight(screenBounds)-64)];
    tableView.dataSource = self;
    tableView.delegate = self;
    [self.view addSubview:tableView];
    self.tableView = tableView;
    UIToolbar *toolBar = [[UIToolbar alloc]initWithFrame:CGRectMake(0, 20, CGRectGetWidth(screenBounds), 44)];
    UIBarButtonItem *item = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addTask)];
    [toolBar setItems:@[item]];
    [self.view addSubview:toolBar];
    self.downloader = [VWChaplin new];
    self.tasks = [NSMutableArray new];
    self.cells = [NSMutableArray new];
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
        VWChaplinSmile *task = [self.downloader downloadWithMethod:@"GET" URLString:alert.textFields.lastObject.text params:nil progress:^(NSProgress *downloadProgress) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [cell updateProgress:downloadProgress.completedUnitCount/downloadProgress.totalUnitCount];
            });
        } destination:nil completionHandler:^(NSURL *filePath, NSError *error) {
            
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
