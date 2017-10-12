//
//  PJSipManager.m
//  09-PJSipDemo
//
//  Created by 王俨 on 2017/9/13.
//  Copyright © 2017年 https://github.com/wangyansnow. All rights reserved.
//

#import "PJSipManager.h"
#import <pjsua-lib/pjsua.h>
#import <UIKit/UIKit.h>

#define DEBUG

NSString *const SipRegStateChanged = @"SipRegStateChanged";
NSString *const SipOnInComingCall  = @"SipOnInComingCall";

void on_incoming_call(pjsua_acc_id acc_id, pjsua_call_id call_id, pjsip_rx_data *rdata);
void on_reg_state(pjsua_acc_id acc_id);
void on_call_state(pjsua_call_id call_id, pjsip_event *e);
void on_call_media_state(pjsua_call_id call_id);

@interface PJSipManager ()

@property (nonatomic, strong) NSThread *sipThread; ///< 所有sip相关操作都在这个线程执行

@property (nonatomic, assign) int accId;
@property (nonatomic, copy) NSString *server;
@property (nonatomic, assign) int callId;

@end

@implementation PJSipManager

static PJSipManager *_manager;
+ (instancetype)sharedManager {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _manager = [self new];
    });
    
    return _manager;
}

#pragma mark - public Method
+ (void)sipStart {

    [self performSelector:@selector(start) onThread:[[self sharedManager] sipThread] withObject:nil waitUntilDone:NO modes:@[NSRunLoopCommonModes]];
}

+ (void)sipRegist:(NSString *)server username:(NSString *)username password:(NSString *)pwd {
    
    [self performSelector:@selector(regist:) onThread:[[self sharedManager] sipThread] withObject:@[server, username, pwd] waitUntilDone:NO modes:@[NSRunLoopCommonModes]];
}

+ (void)sipCall:(NSString *)phoneNum {
    [self performSelector:@selector(call:) onThread:[[self sharedManager] sipThread] withObject:phoneNum waitUntilDone:NO modes:@[NSRunLoopCommonModes]];
}

+ (void)sipHangup {
    [self performSelector:@selector(hangup) onThread:[[self sharedManager] sipThread] withObject:nil waitUntilDone:NO modes:@[NSRunLoopCommonModes]];
}

+ (void)sipAnswer {
    [self performSelector:@selector(answer) onThread:[[self sharedManager] sipThread] withObject:nil waitUntilDone:NO modes:@[NSRunLoopCommonModes]];
}

+ (void)sipUpdateRegistration {
    [self performSelector:@selector(updateRegistration) onThread:[[self sharedManager] sipThread] withObject:nil waitUntilDone:NO modes:@[NSRunLoopCommonModes]];
}

#pragma mark - SIP Method
+ (void)updateRegistration {
    if (_manager.accId == -1) return;
    // 0 will start unregistration process
    pjsua_acc_set_registration(_manager.accId, 1);
}

+ (void)answer {
    pj_str_t reason = pj_str("ok let us say");
    pjsua_call_answer(_manager.callId, 200, &reason, NULL);
}

+ (void)hangup {
    pj_str_t reason = pj_str("I am busy now");
    pjsua_call_hangup(_manager.callId, 0, &reason, NULL);
}

+ (void)call:(NSString *)phoneNum {
    PJSipManager *manager = [self sharedManager];
    
    NSString *sipId = @"yan";
    NSString *targetURI = [NSString stringWithFormat:@"\"%@\" <sip:%@@%@>", sipId, phoneNum, manager.server];
    
    pj_str_t dstURI = pj_str((char *)targetURI.UTF8String);
    pjsua_call_id callId;
    
    pj_status_t status = pjsua_call_make_call(manager.accId, &dstURI, 0, NULL, NULL, &callId);
    if ( status != PJ_SUCCESS) {
        char errorMsg[PJ_ERR_MSG_SIZE];
        pj_strerror(status, errorMsg, sizeof(errorMsg));
        NSLog(@"make call error, statusCode = %d, errorMsg = %s", status, errorMsg);
    } else {
        manager.callId = callId;
        NSLog(@"callId = %d", manager.callId);
    }
}

+ (void)regist:(NSArray *)arr {
    NSString *server = arr[0];
    NSString *username = arr[1];
    NSString *pwd = arr[2];
    
    pjsua_acc_id accId;
    pjsua_acc_config accCfg;
    
    pjsua_acc_config_default(&accCfg);
    
    // 1.先删除之前的注册
    PJSipManager *manager = [self sharedManager];
    NSLog(@"manager.accId = %d, accCount = %d", manager.accId, pjsua_acc_get_count());
    if (manager.accId >= 0 && manager.accId < pjsua_acc_get_count()) {
        if (pjsua_acc_del(manager.accId) == PJ_SUCCESS) {
            NSLog(@"删除成功");
        } else {
            NSLog(@"删除失败");
        }
    }
    
    NSString *cfgId = [NSString stringWithFormat:@"\"yan\" <sip:%@@%@>", username, server];
    accCfg.id = pj_str((char *)cfgId.UTF8String);
    accCfg.reg_uri = pj_str((char *)[NSString stringWithFormat:@"sip:%@", server].UTF8String);
    accCfg.reg_retry_interval = 10;
    accCfg.cred_count = 1;
    accCfg.cred_info[0].realm = pj_str("*");
    accCfg.cred_info[0].username = pj_str((char *)username.UTF8String);
    accCfg.cred_info[0].data_type = PJSIP_CRED_DATA_PLAIN_PASSWD;
    accCfg.cred_info[0].data = pj_str((char *)pwd.UTF8String);
    
    pjsua_acc_add(&accCfg, PJ_TRUE, &accId);
    manager.accId = accId;
}

+ (BOOL)start {
    pj_status_t status;
    // 创建SUA
    status = pjsua_create();
    if (status != PJ_SUCCESS) {
        NSLog(@"create pjsua error");
        return NO;
    }
    
    {
        // 1.SUA相关配置
        pjsua_config cfg;
        pjsua_media_config media_cfg;
        pjsua_logging_config log_cfg;
        
        pjsua_config_default(&cfg);
        
        // 2.回调函数配置
        cfg.cb.on_incoming_call = &on_incoming_call; // 来电
        cfg.cb.on_reg_state = &on_reg_state;         // 注册状态
        cfg.cb.on_call_state = &on_call_state;       // 电话状态
        cfg.cb.on_call_media_state = &on_call_media_state; // 媒体状态 (通话建立后，要播放RTP流)
        
        // 3.媒体相关配置
        pjsua_media_config_default(&media_cfg);
        media_cfg.clock_rate = 16000;
        media_cfg.snd_clock_rate = 16000;
        media_cfg.ec_tail_len = 0;
        
        // 4.日志相关配置
        pjsua_logging_config_default(&log_cfg);
#ifdef DEBUG
        log_cfg.msg_logging = PJ_TRUE;
        log_cfg.console_level = 4;
        log_cfg.level = 5;
#else
        log_cfg.msg_logging = PJ_FALSE;
        log_cfg.console_level = 0;
        log_cfg.level = 0;
#endif
        
        // 5.初始化 PJSUA
        status = pjsua_init(&cfg, &log_cfg, &media_cfg);
        if (status != PJ_SUCCESS) {
            NSLog(@"init pjsua error");
            return NO;
        }
    }
    
    // udp transport
    {
        pjsua_transport_config transport_cfg;
        pjsua_transport_config_default(&transport_cfg);
        
        // 1.传输类型配置
        status = pjsua_transport_create(PJSIP_TRANSPORT_UDP, &transport_cfg, NULL);
        if (status != PJ_SUCCESS) {
            NSLog(@"create udp transport error");
            return NO;
        }
    }
    
    // 启动 PJSUA
    status = pjsua_start();
    if (status != PJ_SUCCESS) {
        NSLog(@"start pjsua error");
        return NO;
    }
    
    PJSipManager *manager = [self sharedManager];
    manager.accId = -1;
    manager.callId = -1;
    
    return YES;
}

#pragma mark - 懒加载
- (NSThread *)sipThread {
    if (!_sipThread) {
        _sipThread = [[NSThread alloc] initWithTarget:self selector:@selector(sipThreadStart:) object:nil];
        [_sipThread start];
        _sipThread.name = @"PJSipThread";
    }
    return _sipThread;
}

- (void)sipThreadStart:(NSThread *)thread {
    [[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
    CFRunLoopRun();
}

@end

#pragma mark - pjsip回调
void on_incoming_call(pjsua_acc_id acc_id, pjsua_call_id call_id, pjsip_rx_data *rdata) {
    pjsua_call_info callInfo;
    pjsua_call_get_info(call_id, &callInfo);
    
    NSString *remoteInfo = [NSString stringWithUTF8String:callInfo.remote_info.ptr];
    _manager.callId = call_id;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *info = @{@"remoteInfo": remoteInfo};
        [[NSNotificationCenter defaultCenter] postNotificationName:SipOnInComingCall object:nil userInfo:info];
    });
}

void on_reg_state(pjsua_acc_id acc_id) {
    pjsua_acc_info accInfo;
    NSString *uri = @"";
    NSString *statusText;
    pjsip_status_code statusCode;
    
    if (pjsua_acc_get_info(acc_id, &accInfo) != PJ_SUCCESS) {
        statusText = @"pjsua_acc_get_info error";
        statusCode = 700;
    } else {
        uri = [NSString stringWithUTF8String:accInfo.acc_uri.ptr];
        statusText = [NSString stringWithUTF8String:accInfo.status_text.ptr];
        statusCode = accInfo.status;
        
        PJSipManager *manager = [PJSipManager sharedManager];
        manager.accId = acc_id;
        NSMutableString *strM = [[uri componentsSeparatedByString:@"@"].lastObject mutableCopy];
        [strM deleteCharactersInRange:NSMakeRange(strM.length - 1, 1)];
        manager.server = strM;
        // PJ_LOG(2, (__FILE__, "current value is %d", value));
        printf("strM = %s\n", strM.UTF8String);
        printf("onlineStatus = %s\n", accInfo.online_status_text.ptr);
        printf("registration status = %s\n", accInfo.status_text.ptr);
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *info = @{@"statusCode": @(statusCode), @"statusText": statusText, @"uri": uri};
        [[NSNotificationCenter defaultCenter] postNotificationName:SipRegStateChanged object:nil userInfo:info];
    });
}

void on_call_state(pjsua_call_id call_id, pjsip_event *e) {
    pjsua_call_info callInfo;
    pjsua_call_get_info(call_id, &callInfo);
    
    pjsip_inv_state invSta = callInfo.state;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (invSta == PJSIP_INV_STATE_NULL) {
            NSLog(@"PJSIP_INV_STATE_NULL");
        } else if (invSta == PJSIP_INV_STATE_CALLING) {
            if ([_manager.delegate respondsToSelector:@selector(onCallStateCalling)]) {
                [_manager.delegate onCallStateCalling];
            }
        } else if (invSta == PJSIP_INV_STATE_INCOMING) {
            NSLog(@"PJSIP_INV_STATE_INCOMING");
        } else if (invSta == PJSIP_INV_STATE_EARLY) {
            if ([_manager.delegate respondsToSelector:@selector(onCallStateEarly)]) {
                [_manager.delegate onCallStateEarly];
            }
        } else if (invSta == PJSIP_INV_STATE_CONNECTING) {
            if ([_manager.delegate respondsToSelector:@selector(onCallStateConnecting)]) {
                [_manager.delegate onCallStateConnecting];
            }
        } else if (invSta == PJSIP_INV_STATE_CONFIRMED) {
            if ([_manager.delegate respondsToSelector:@selector(onCallStateConfirmed)]) {
                [_manager.delegate onCallStateConfirmed];
            }
        } else if (invSta == PJSIP_INV_STATE_DISCONNECTED) {
            if ([_manager.delegate respondsToSelector:@selector(onCallStateDisconnected:)]) {
                [_manager.delegate onCallStateDisconnected:callInfo.last_status];
            }
        }
    });
}

void on_call_media_state(pjsua_call_id call_id) {
    pjsua_call_info callInfo;
    pjsua_call_get_info(call_id, &callInfo);
    
    if (callInfo.media_status == PJSUA_CALL_MEDIA_ACTIVE) {
        // when media is active, connect call to sound device.
        pjsua_conf_connect(callInfo.conf_slot, 0);
        pjsua_conf_connect(0, callInfo.conf_slot);
        
        pjsua_conf_adjust_rx_level(0, 1);
        pjsua_conf_adjust_tx_level(0, 1);
    }
}
