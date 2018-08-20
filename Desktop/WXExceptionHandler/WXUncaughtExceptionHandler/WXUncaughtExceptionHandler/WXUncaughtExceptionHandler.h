//
//  WXUncaughtExceptionHandler.h
//  WXUncaughtExceptionHandler
//
//  Created by wangxinxu on 2018/8/15.
//  Copyright © 2018年 wangxinxu. All rights reserved.
//

#import <Foundation/Foundation.h>

//返回地址路径
typedef void(^ logPathBlock)(NSString *pathStr);

@interface WXUncaughtExceptionHandler : NSObject

+ (instancetype)shareInstance;

@property (nonatomic,copy) logPathBlock pathBlock;

//是否显示错误提示框 默认是不显示的
@property (nonatomic, copy) WXUncaughtExceptionHandler*(^showAlert)(BOOL yesOrNo);

//是否显示错误信息
@property (nonatomic, copy) WXUncaughtExceptionHandler*(^showErrorInfor)(BOOL yesOrNo);

//回调返回错误日志
@property (nonatomic, copy) WXUncaughtExceptionHandler*(^getlogPathBlock)(void(^ logPathBlock)(NSString *pathStr));

//错误日志路径
@property (nonatomic,strong) NSString *logFilePath;

WXUncaughtExceptionHandler * InstanceWXUncaughtExceptionHandler(void);

@end
