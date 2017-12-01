//
//  YSPZipManager.h
//  流解压测试
//
//  Created by ZhangChao on 2017/6/15.
//  Copyright © 2017年 YunShiPei. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^StatusBlock)(id unzipMessage);

@interface YSPUnZipManager : NSObject

+ (void)unzipFileWithData:(NSData *)data targetPath:(NSString *)path success:(StatusBlock)status;

@end

