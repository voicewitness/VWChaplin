//
//  ViewController.m
//  VWChaplinDemo
//
//  Created by VoiceWitness on 27/04/2017.
//  Copyright © 2017 voicewh. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()<UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;

@end

@implementation ViewController {
    NSArray *_pages;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    UITableView *tableView = [[UITableView alloc]initWithFrame:CGRectMake(0, 20, CGRectGetWidth(screenBounds), CGRectGetHeight(screenBounds)-20)];
    tableView.dataSource = self;
    tableView.delegate = self;
    [self.view addSubview:tableView];
    self.tableView = tableView;
    _pages = @[@{@"name":@"download",@"vc":@"NormalDownloaderViewController"},@{@"name":@"persistence",@"vc":@"NormalDownloaderViewController",@"params":@{@"getPersistence":@(YES)}}];
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _pages.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"];
    cell.textLabel.text = _pages[indexPath.row][@"name"];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 100;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *vcInfo = _pages[indexPath.row];
    UIViewController *vc = [NSClassFromString(vcInfo[@"vc"]) new];
    NSDictionary *params = vcInfo[@"params"];
    for (NSString *key in params.allKeys) {
        [vc setValue:params[key] forKey:key];
    }
    [self.navigationController pushViewController:vc animated:YES];
}


@end
