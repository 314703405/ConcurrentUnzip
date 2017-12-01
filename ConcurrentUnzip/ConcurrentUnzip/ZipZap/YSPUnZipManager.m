//
//  YSPZipManager.m
//  流解压测试
//
//  Created by ZhangChao on 2017/6/15.
//  Copyright © 2017年 YunShiPei. All rights reserved.
//

#import "YSPUnZipManager.h"
#import "ZipZap.h"

@implementation YSPUnZipManager

+ (void)unzipFileWithData:(NSData *)data targetPath:(NSString *)path success:(StatusBlock)status
{
    NSError *error = nil;
    
    ZZArchive *zz = [ZZArchive archiveWithData:data error:&error];
    
    if (error)
    {
        if (status)
        {
            status(@{
                     @"status" : @"0",
                     @"message": error.localizedDescription
                     });
            
            return ;
        }
    }
    
    NSURL* pathUrl = [NSURL fileURLWithPath:path];
    
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    dispatch_semaphore_t sem = dispatch_semaphore_create(3);
    
    [zz.entries enumerateObjectsUsingBlock:^(ZZArchiveEntry * _Nonnull entry, NSUInteger idx, BOOL * _Nonnull stop) {
        
        dispatch_semaphore_wait(sem,DISPATCH_TIME_FOREVER);
        
        dispatch_group_async(group, queue, ^{
            
            NSFileManager *fileManager = [NSFileManager defaultManager];
            
            NSData *filenamedata = entry.rawFileName;
            
            NSString *filename = [[NSString alloc] initWithData:filenamedata encoding:NSUTF8StringEncoding];
            
            // NSLog(@"fileName=%@,currentThread=%@",filename,[NSThread currentThread]);
            
            NSURL* targetPath = [pathUrl URLByAppendingPathComponent:filename];
            
            if (entry.fileMode & S_IFDIR)
            {
                // check if directory bit is set
                [fileManager createDirectoryAtURL:targetPath
                      withIntermediateDirectories:YES
                                       attributes:nil
                                            error:nil];
            }
            else
            {
                // Some archives don't have a separate entry for each directory
                // and just include the directory's name in the filename.
                // Make sure that directory exists before writing a file into it.
                [fileManager createDirectoryAtURL:[targetPath URLByDeletingLastPathComponent]
                      withIntermediateDirectories:YES
                                       attributes:nil
                                            error:nil];
                
                [[entry newDataWithError:nil] writeToURL:targetPath atomically:NO];
            }
            
            dispatch_semaphore_signal(sem);
        });
    }];
    
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    
    if (status)
    {
        status(@{
                @"status" : @"1",
                @"message": @"解压成功"
                });
    }
}

@end
