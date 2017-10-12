//
//  AppDelegate.m
//  09-PJSipDemo
//
//  Created by 王俨 on 2017/9/12.
//  Copyright © 2017年 https://github.com/wangyansnow. All rights reserved.
//

#import "AppDelegate.h"
#import "PJSipManager.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    [PJSipManager sipStart];
    return YES;
}

@end

