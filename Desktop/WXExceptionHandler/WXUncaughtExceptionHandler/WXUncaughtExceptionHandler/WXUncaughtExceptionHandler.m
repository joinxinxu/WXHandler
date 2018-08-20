//
//  WXUncaughtExceptionHandler.m
//  WXUncaughtExceptionHandler
//
//  Created by wangxinxu on 2018/8/15.
//  Copyright © 2018年 wangxinxu. All rights reserved.
//

#import "WXUncaughtExceptionHandler.h"
#import <UIKit/UIKit.h>
#include <libkern/OSAtomic.h>
#include <execinfo.h>

NSString * const UncaughtExceptionHandlerSignalExceptionName = @"UncaughtExceptionHandlerSignalExceptionName";
NSString * const UncaughtExceptionHandlerSignalKey = @"UncaughtExceptionHandlerSignalKey";
NSString * const UncaughtExceptionHandlerAddressesKey = @"UncaughtExceptionHandlerAddressesKey";

volatile int32_t UncaughtExceptionCount = 0;
const int32_t UncaughtExceptionMaximum = 10;
const NSInteger UncaughtExceptionHandlerSkipAddressCount = 4;
const NSInteger UncaughtExceptionHandlerReportAddressCount = 5;

@interface WXUncaughtExceptionHandler()

@property (nonatomic,assign) BOOL isShowAlert;
@property (nonatomic,assign) BOOL dismissed;
@property (nonatomic,assign) BOOL isShowErrorInfor;
@property (nonatomic,strong) NSString *alertMessage;//警告提示消息

@end

@implementation WXUncaughtExceptionHandler

+ (instancetype)shareInstance{
    static WXUncaughtExceptionHandler *_manager = nil;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _manager = [[self alloc] init];
        [_manager uiConfig];
    });
    return _manager;
}

#pragma mark - 设置日志存取的路径
- (void)uiConfig{
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *filePath = [docPath stringByAppendingPathComponent:@"WXUncaughtExceptionHandlerLog.txt"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:filePath]) {
        [fileManager createFileAtPath:filePath contents:[@"~~~~~~~~~~~~~~~~~~程序异常日志~~~~~~~~~~~~~~~~~~\n\n" dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
    }
    self.logFilePath = filePath;
}

- (void)handleException:(NSException *)exception{
    //保存日志 可以发送日志到自己的服务器上
    [self validateAndSaveCriticalApplicationData:exception];
    NSString *_erroeMeg = nil;
    NSString *userInfo = [[exception userInfo] objectForKey:UncaughtExceptionHandlerAddressesKey];
    if(self.isShowErrorInfor){
        _erroeMeg = [NSString stringWithFormat:NSLocalizedString(@"如果点击继续，程序有可能会出现其他的问题，建议您还是点击退出按钮并重新打开\n" @"异常原因如下:\n%@\n%@", nil), [exception reason], userInfo];
    }else{
        _erroeMeg = [NSString stringWithFormat:NSLocalizedString(@"如果点击继续，程序有可能会出现其他的问题，建议您还是点击退出按钮并重新打开", nil)];
    }
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"抱歉,程序出现了异常" message:_erroeMeg delegate:self cancelButtonTitle:@"退出" otherButtonTitles:@"继续", nil];
    dispatch_async(dispatch_get_main_queue(), ^{
        if(_isShowAlert){
            [alert show];
        }
    });
    
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFArrayRef allModes = CFRunLoopCopyAllModes(runLoop);
    while (!_dismissed){
        for (NSString *mode in (__bridge NSArray *)allModes) {
            CFRunLoopRunInMode((CFStringRef)mode, 0.001, false);
        }
    }
    CFRelease(allModes);
#pragma clang diagnostic pop
    NSSetUncaughtExceptionHandler(NULL);
    signal(SIGABRT, SIG_DFL);
    signal(SIGILL, SIG_DFL);
    signal(SIGSEGV, SIG_DFL);
    signal(SIGFPE, SIG_DFL);
    signal(SIGBUS, SIG_DFL);
    signal(SIGPIPE, SIG_DFL);
    if ([[exception name] isEqual:UncaughtExceptionHandlerSignalExceptionName]) {
        kill(getpid(), [[[exception userInfo] objectForKey:UncaughtExceptionHandlerSignalKey] intValue]);
    }else{
        [exception raise];
    }
}

//点击退出
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)alertView:(UIAlertView *)anAlertView clickedButtonAtIndex:(NSInteger)anIndex {
#pragma clang diagnostic pop
    if (anIndex == 0) {
        self.dismissed = YES;
    }
}

+ (NSArray *)backtrace {
    void* callstack[128];
    int frames = backtrace(callstack, 128);
    char **strs = backtrace_symbols(callstack, frames);
    int i;
    NSMutableArray *backtrace = [NSMutableArray arrayWithCapacity:frames];
    for (i = UncaughtExceptionHandlerSkipAddressCount; i < UncaughtExceptionHandlerSkipAddressCount + UncaughtExceptionHandlerReportAddressCount; i++) {
        [backtrace addObject:[NSString stringWithUTF8String:strs[i]]];
    }
    free(strs);
    return backtrace;
}

#pragma mark - 保存错误信息日志
- (void)validateAndSaveCriticalApplicationData:(NSException *)exception{
    NSString *exceptionMessage = [NSString stringWithFormat:NSLocalizedString(@"\n******************** %@ 异常原因如下: ********************\n%@\n%@\n==================== End ====================\n\n", nil), [self currentTimeString], [exception reason], [[exception userInfo] objectForKey:UncaughtExceptionHandlerAddressesKey]];
    NSFileHandle *handle = [NSFileHandle fileHandleForUpdatingAtPath:self.logFilePath];
    [handle seekToEndOfFile];
    [handle writeData:[exceptionMessage dataUsingEncoding:NSUTF8StringEncoding]];
    [handle closeFile];
    if(self.pathBlock){
        self.pathBlock(self.logFilePath);
    }
}

- (NSString *)currentTimeString {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *currentDateStr = [dateFormatter stringFromDate:[NSDate date]];
    return currentDateStr;
}

- (WXUncaughtExceptionHandler *(^)(BOOL isShow))showAlert{
    return ^(BOOL isShow) {
        self.isShowAlert = isShow;
        return [WXUncaughtExceptionHandler shareInstance];
    };
}

- (WXUncaughtExceptionHandler *(^)(BOOL isShow))showErrorInfor{
    return ^(BOOL isShow) {
        self.isShowErrorInfor = isShow;
        return [WXUncaughtExceptionHandler shareInstance];
    };
}

- (WXUncaughtExceptionHandler *(^)(void(^ logPathBlock)(NSString *pathStr)))getlogPathBlock{
    return ^(void(^ logPathBlock)(NSString *pathStr)) {
        self.pathBlock = logPathBlock;
        return [WXUncaughtExceptionHandler shareInstance];
    };
}

@end



void HandleException(NSException *exception){
    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExceptionCount);
    //如果太多不用处理
    if (exceptionCount > UncaughtExceptionMaximum) {
        return;
    }
    //获取调用堆栈
    NSArray *callStack = [exception callStackSymbols];
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:[exception userInfo]];
    [userInfo setObject:callStack forKey:UncaughtExceptionHandlerAddressesKey];
    //在主线程中，执行制定的方法, withObject是执行方法传入的参数
    [[WXUncaughtExceptionHandler shareInstance] performSelectorOnMainThread:@selector(handleException:) withObject:[NSException exceptionWithName:[exception name] reason:[exception reason] userInfo:userInfo] waitUntilDone:YES];
}

void SignalHandler (int signal){
    int32_t exceptionCount = OSAtomicIncrement32(&UncaughtExceptionCount);
    if (exceptionCount > UncaughtExceptionMaximum) {
        return;
    }
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithObject:[NSNumber numberWithInt:signal] forKey:UncaughtExceptionHandlerSignalKey];
    NSArray *callStack = [WXUncaughtExceptionHandler backtrace];
    [userInfo setObject:callStack forKey:UncaughtExceptionHandlerAddressesKey];
    [[WXUncaughtExceptionHandler shareInstance] performSelectorOnMainThread:@selector(handleException:) withObject: [NSException exceptionWithName:UncaughtExceptionHandlerSignalExceptionName reason: [NSString stringWithFormat: NSLocalizedString(@"Signal %d was raised.", nil), signal] userInfo: [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:signal] forKey:UncaughtExceptionHandlerSignalKey]] waitUntilDone:YES];
}

WXUncaughtExceptionHandler *InstanceWXUncaughtExceptionHandler(void){
    NSSetUncaughtExceptionHandler(&HandleException);
    signal(SIGABRT, SignalHandler);
    signal(SIGILL, SignalHandler);
    signal(SIGSEGV, SignalHandler);
    signal(SIGFPE, SignalHandler);
    signal(SIGBUS, SignalHandler);
    signal(SIGPIPE, SignalHandler);
    return [WXUncaughtExceptionHandler shareInstance];
}
