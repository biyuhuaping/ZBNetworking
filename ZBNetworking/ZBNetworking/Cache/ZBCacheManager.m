//
//  ZBCacheManager.m
//  ZBNetworking
//
//  Created by biyuhuaping on 2017/12/10.
//  Copyright © 2017年 biyuhuaping. All rights reserved.
//

#import "ZBCacheManager.h"
#import "ZBMemoryCache.h"
#import "ZBDiskCache.h"
#import "ZBLRUManager.h"
#import <CommonCrypto/CommonDigest.h>

static NSString *const cacheDirKey = @"cacheDirKey";
static NSString *const downloadDirKey = @"downloadDirKey";
static NSUInteger diskCapacity = 50 * 1024 * 1024;
static NSTimeInterval cacheTime = 7 * 24 * 60 * 60;

@implementation ZBCacheManager

+ (instancetype)shareManager {
    static ZBCacheManager *_ZBCacheManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _ZBCacheManager = [[ZBCacheManager alloc] init];
    });
    return _ZBCacheManager;
}

- (void)setCacheTime:(NSTimeInterval)time diskCapacity:(NSUInteger)capacity {
    diskCapacity = capacity;
    cacheTime = time;
}

- (void)cacheResponseObject:(id)responseObject requestUrl:(NSString *)requestUrl params:(NSDictionary *)params {
    assert(responseObject);
    assert(requestUrl);
    
    if (!params) params = @{};
    NSString *originString = [NSString stringWithFormat:@"%@%@",requestUrl,params];
    NSString *hash = [self md5:originString];

    NSData *data = nil;
    NSError *error = nil;
    if ([responseObject isKindOfClass:[NSData class]]) {
        data = responseObject;
    }else if ([responseObject isKindOfClass:[NSDictionary class]]){
        data = [NSJSONSerialization dataWithJSONObject:responseObject options:NSJSONWritingPrettyPrinted error:&error];
    }
    
    if (error == nil) {
        //缓存到内存中
        [ZBMemoryCache writeData:responseObject forKey:hash];
        
        //缓存到磁盘中
        //磁盘路径
        NSString *directoryPath = nil;
        directoryPath = [[NSUserDefaults standardUserDefaults] objectForKey:cacheDirKey];
        if (!directoryPath) {
            directoryPath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:@"ZBNetworking"] stringByAppendingPathComponent:@"networkCache"];
            [[NSUserDefaults standardUserDefaults] setObject:directoryPath forKey:cacheDirKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        [[ZBDiskCache sharedDiskCache] writeData:data toDir:directoryPath filename:hash];
        [[ZBLRUManager shareManager] addFileNode:hash];
    }
}

- (id)getCacheResponseObjectWithRequestUrl:(NSString *)requestUrl params:(NSDictionary *)params {
    assert(requestUrl);
    
    id cacheData = nil;
    
    if (!params) params = @{};
    NSString *originString = [NSString stringWithFormat:@"%@%@",requestUrl,params];
    NSString *hash = [self md5:originString];
    
    //先从内存中查找
    cacheData = [ZBMemoryCache readDataWithKey:hash];
    
    if (!cacheData) {
        NSString *directoryPath = [[NSUserDefaults standardUserDefaults] objectForKey:cacheDirKey];
        if (directoryPath) {
            cacheData = [[ZBDiskCache sharedDiskCache] readDataFromDir:directoryPath filename:hash];
            if (cacheData) [[ZBLRUManager shareManager] refreshIndexOfFileNode:hash];
        }
    }
    
    return cacheData;
}

- (void)storeDownloadData:(NSData *)data requestUrl:(NSString *)requestUrl {
    assert(data);
    assert(requestUrl);
    
    NSString *fileName = nil;
    NSString *type = nil;
    NSArray *strArray = nil;
    
    strArray = [requestUrl componentsSeparatedByString:@"."];
    if (strArray.count > 0) {
        type = strArray[strArray.count - 1];
    }
    
    if (type) {
        fileName = [NSString stringWithFormat:@"%@.%@",[self md5:requestUrl],type];
    }else {
        fileName = [NSString stringWithFormat:@"%@",[self md5:requestUrl]];
    }
    
    NSString *directoryPath = nil;
    directoryPath = [[NSUserDefaults standardUserDefaults] objectForKey:downloadDirKey];
    if (!directoryPath) {
        directoryPath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:@"ZBNetworking"] stringByAppendingPathComponent:@"download"];
        
        [[NSUserDefaults standardUserDefaults] setObject:directoryPath forKey:downloadDirKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    [[ZBDiskCache sharedDiskCache] writeData:data toDir:directoryPath filename:fileName];
}

- (NSURL *)getDownloadDataFromCacheWithRequestUrl:(NSString *)requestUrl {
    assert(requestUrl);
    
    NSData *data = nil;
    NSString *fileName = nil;
    NSString *type = nil;
    NSArray *strArray = nil;
    NSURL *fileUrl = nil;
    
    
    strArray = [requestUrl componentsSeparatedByString:@"."];
    if (strArray.count > 0) {
        type = strArray[strArray.count - 1];
    }
    
    if (type) {
        fileName = [NSString stringWithFormat:@"%@.%@",[self md5:requestUrl],type];
    }else {
        fileName = [NSString stringWithFormat:@"%@",[self md5:requestUrl]];
    }
    
    
    NSString *directoryPath = [[NSUserDefaults standardUserDefaults] objectForKey:downloadDirKey];
    if (directoryPath) data = [[ZBDiskCache sharedDiskCache] readDataFromDir:directoryPath filename:fileName];
    if (data) {
        NSString *path = [directoryPath stringByAppendingPathComponent:fileName];
        fileUrl = [NSURL fileURLWithPath:path];
    }
    
    return fileUrl;
}

- (NSUInteger)totalCacheSize {
    NSString *diretoryPath = [[NSUserDefaults standardUserDefaults] objectForKey: cacheDirKey];
    return [[ZBDiskCache sharedDiskCache] dataSizeInDir:diretoryPath];
}

- (NSUInteger)totalDownloadDataSize {
    NSString *diretoryPath = [[NSUserDefaults standardUserDefaults] objectForKey: downloadDirKey];
    return [[ZBDiskCache sharedDiskCache] dataSizeInDir:diretoryPath];
}

- (void)clearDownloadData {
    NSString *diretoryPath = [[NSUserDefaults standardUserDefaults] objectForKey:downloadDirKey];
    
    [[ZBDiskCache sharedDiskCache] clearDataIinDir:diretoryPath];
}

- (NSString *)getDownDirectoryPath {
    NSString *diretoryPath = [[NSUserDefaults standardUserDefaults] objectForKey:downloadDirKey];
    return diretoryPath;
}

- (NSString *)getCacheDiretoryPath {
    NSString *diretoryPath = [[NSUserDefaults standardUserDefaults] objectForKey:cacheDirKey];
    return diretoryPath;
}

- (void)clearTotalCache {
    NSString *directoryPath = [[NSUserDefaults standardUserDefaults] objectForKey:cacheDirKey];
    
    [[ZBDiskCache sharedDiskCache] clearDataIinDir:directoryPath];
}

- (void)clearLRUCache {
    if ([self totalCacheSize] > diskCapacity) {
        NSArray *deleteFiles = [[ZBLRUManager shareManager] removeLRUFileNodeWithCacheTime:cacheTime];
        NSString *directoryPath = [[NSUserDefaults standardUserDefaults] objectForKey:cacheDirKey];
        if (directoryPath && deleteFiles.count > 0) {
            [deleteFiles enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSString *filePath = [directoryPath stringByAppendingPathComponent:obj];
                [[ZBDiskCache sharedDiskCache] deleteCache:filePath];
            }];
        }
    }
}

#pragma mark - 散列值
- (NSString *)md5:(NSString *)string {
    if (string == nil || string.length == 0) {
        return nil;
    }
    
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5([string UTF8String],(int)[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding],digest);
    NSMutableString *ret = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [ret appendFormat:@"%02x",digest[i]];
    }
    return [ret copy];
}

@end
