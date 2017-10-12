//
//  WYCallVC.m
//  09-PJSipDemo
//
//  Created by 王俨 on 2017/9/13.
//  Copyright © 2017年 https://github.com/wangyansnow. All rights reserved.
//

#import "WYCallVC.h"
#import "PJSipManager.h"

@interface WYCallVC ()<PJSipDelegate>

@property (weak, nonatomic) IBOutlet UITextField *callField;
@property (weak, nonatomic) IBOutlet UIStackView *stackView;

@end

@implementation WYCallVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(callComing:) name:SipOnInComingCall object:nil];
    PJSipManager *manager = [PJSipManager sharedManager];
    manager.delegate = self;
}

- (void)callComing:(NSNotification *)n {
    NSLog(@"n.userinfo = %@", n.userInfo);
    
    self.stackView.hidden = NO;
}

- (IBAction)hangupBtnClick {
    self.stackView.hidden = YES;
    
    [PJSipManager sipHangup];
}

- (IBAction)answerBtnClick {
    [PJSipManager sipAnswer];
}

- (IBAction)callBtnClick {
    if (!self.callField.hasText) return;
    
    [PJSipManager sipCall:self.callField.text];
}

- (IBAction)updateRegistration {
    [PJSipManager sipUpdateRegistration];
}


#pragma mark - PJSipDelegate

- (void)onCallStateCalling {
    NSLog(@"%s", __func__);
}

- (void)onCallStateEarly {
     NSLog(@"%s", __func__);
}

- (void)onCallStateConnecting {
     NSLog(@"%s", __func__);
}

- (void)onCallStateConfirmed {
     NSLog(@"%s", __func__);
}

- (void)onCallStateDisconnected:(NSInteger)code {
    NSLog(@"disconnected.code = %ld", code);
}

@end
