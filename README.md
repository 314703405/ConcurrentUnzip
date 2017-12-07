# ConcurrentUnzip
利用dispatch_group和dispatch_semaphore做最大并发控制,实现高效流解压


## zipzap解压库
iOS中用到解压操作不会太多,所以很多人会选择SSZipArchive来进行解压, SSZipArchive是基于C语言库miniZip来进行解压的,并且SSZipArchive源码中在一个线程中以一个while循环来解压,循环中因为要保证解压进度和实时取消解压操作所以是在一个线程中同步进行解压,效率很低.

SSZipArchive是解压一个文件包,如果网络下载一个zip包,开发者必须先把zip包写成文件,然后再让SSZipArchive库去读取文件进行解压,其中损失了写文件和读取文件的时间.

最近在做公司SDK的时候用到了SSZipArchive,并且是在多个同步下载任务完成后,在各个子线程中进行解压,大数据量测试的时候挂掉了,解压效率太慢,而且会有1%左右的几率出现zip解压失败和解压出来文件为空的bug.后来写测试demo,在主线程或者多个子线程中做解压并不会出现解压失败的情况,一时很是头大, SSZipArchive源码中大多为C语言,定位问题到底出在哪里非常费事.

同一个碎片化很严重的压缩包(10M),在安卓端解压并写入sd卡中耗时大概5秒,而iOS端使用SSZipArchive解压(iPhone 5s iOS 10系统)需要50秒,很是无奈,最终定位问题的时候发现是iOS写文件的速率很慢,然后想到了开启多条线程来写文件.

在更改SSZipArchive源码的同时,找到了[zipzap库](https://github.com/pixelglow/ZipZap),该库使用的是iOS系统的原生库libz.tbd做解压,没有任何第三方依赖,可能是由于该库只提供解压或者压缩的方法,没有提供进度,实时取消的代理方法,所以在github上星星很少,抱着试一试的态度决定使用该库替换SSZipArchive,替换以后惊奇的发现大数据量测试的时候并不是减少了解压失败问题,而是彻底解决了该问题.

剩下的就是多线程写文件的了,为保证线程安全并且保证开启线程数量不能太多,所以采用了GCD来实现.

## 线程安全及最大并发实现
### dispatch_semaphore 信号量简介
dispatch_semaphore_create() 创建一个信号量,参数是这个信号量的值,在该信号量为0时,是一种上锁状态,其他线程访问不了改资源,所以该操作线程安全.

dispatch_semaphore_wait() 该函数对参数进行信号量减1操作,参数一:所操作的信号量,参数二:信号量等待时间.

dispatch_semaphore_signal() 该函数对现有信号量加1,参数为所操作的信号量

### dispatch_group简介
dispatch groups是专门用来监视多个异步任务。dispatch_group_t实例用来追踪不同队列中的不同任务。

当group里所有事件都完成GCD API有两种方式发送通知，第一种是dispatch_group_wait，会阻塞当前线程，等所有任务都完成或等待超时。第二种方法是使用dispatch_group_notify，异步执行block，不会阻塞。

dispatch_group_enter() 和 dispatch_group_leave() 进入和出组操作需要成对出现的.

dispatch_group_async 等价于 dispatch_group_enter() 和 dispatch_group_leave() 的组合.

###具体实现
```
	// 创建一个队列组
 	dispatch_group_t group = dispatch_group_create();
 	// 创建一个异步队列(这里采用全局队列)
 	dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
 	// 创建信号量(也就是最大并发的线程数量,可以根据设备类型自定义数量)
	dispatch_semaphore_t semaphore = dispatch_semaphore_create(3);
   	// 循环遍历所有需要解压的文件
   	for() 
   	{
   		// 每新增一个任务使当前信号量-1,为0时线程锁死
	   	dispatch_semaphore_wait(semaphore,DISPATCH_TIME_FOREVER);
		// 入组,并开启子线程来执行解压操作
		dispatch_group_async(group, queue, ^{
			// 解压操作
			
			// 没完成一个解压任务使当前信号量+1,解除当前线程锁
			dispatch_semaphore_signal(semaphore);
		});
   	}
	// 一直等待所有任务都完成
	dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
	// 解压完成
```

