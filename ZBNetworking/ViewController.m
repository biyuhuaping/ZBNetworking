//
//  ViewController.m
//  ZBNetworking
//
//  Created by 周博 on 2017/12/5.
//  Copyright © 2017年 zhoubo. All rights reserved.
//

#import "ViewController.h"
#import "ZBNetworking.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"缓存size is %lu",[[ZBNetworking shaerdInstance] totalCacheSize]);
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    NSString *url = @"http://news-at.zhihu.com/api/4/news/latest";
    [[ZBNetworking shaerdInstance]getWithUrl:url cache:NO params:nil progressBlock:^(int64_t bytesRead, int64_t totalBytes) {
        NSLog(@"%lld--%lld",bytesRead,totalBytes);
//        [NSThread sleepForTimeInterval:2];
    } successBlock:^(id response) {
        NSLog(@"%@",response);
//        User *user = [User mj_objectWithKeyValues:response];
//        DBLOG(@"%@,%@",user.stories[0][@"title"],user.stories[0][@"id"]);
    } failBlock:^(NSError *error) {
//        NSLog(@"%@",error);
        [[ZBNetworking shaerdInstance] totalCacheSize];
    }];
    NSLog(@"缓存size is %lu",[[ZBNetworking shaerdInstance] totalCacheSize]);
}

@end
