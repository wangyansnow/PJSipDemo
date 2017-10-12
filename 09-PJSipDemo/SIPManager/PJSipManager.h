//
//  PJSipManager.h
//  09-PJSipDemo
//
//  Created by 王俨 on 2017/9/13.
//  Copyright © 2017年 https://github.com/wangyansnow. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol PJSipDelegate<NSObject>
@optional
- (void)onRegState:(BOOL)bSuccess errorCode:(NSInteger)code;
- (void)onCallStateCalling;
- (void)onCallStateEarly;
- (void)onCallStateConnecting;
- (void)onCallStateConfirmed;
- (void)onCallStateDisconnected:(NSInteger)code;

@end

extern NSString *const SipRegStateChanged;
extern NSString *const SipOnInComingCall;

@interface PJSipManager : NSObject

@property (nonatomic, weak) id<PJSipDelegate> delegate;

+ (instancetype)sharedManager ;

+ (void)sipStart;
+ (void)sipRegist:(NSString *)server username:(NSString *)username password:(NSString *)pwd;
+ (void)sipCall:(NSString *)phoneNum;
+ (void)sipHangup;
+ (void)sipAnswer;

@end
