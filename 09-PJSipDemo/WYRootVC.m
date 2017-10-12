//
//  ViewController.m
//  09-PJSipDemo
//
//  Created by 王俨 on 2017/9/12.
//  Copyright © 2017年 https://github.com/wangyansnow. All rights reserved.
//

#import "WYRootVC.h"
#import "PJSipManager.h"
#import "WYCallVC.h"

@interface WYRootVC ()

@property (weak, nonatomic) IBOutlet UITextField *serverField;
@property (weak, nonatomic) IBOutlet UITextField *usernameField;
@property (weak, nonatomic) IBOutlet UITextField *passwordField;
@property (weak, nonatomic) IBOutlet UIButton *loginBtn;

@end

@implementation WYRootVC

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textFieldChanged:) name:UITextFieldTextDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(regStateChanged:) name:SipRegStateChanged object:nil];
}

- (void)regStateChanged:(NSNotification *)n {
    NSLog(@"n.userInfo = %@", n.userInfo);
    
    if ([n.userInfo[@"statusCode"] integerValue] == 200) {
        if (self.navigationController.viewControllers.count > 1) return;
        [self.navigationController pushViewController:[WYCallVC new] animated:YES];
    }
}

- (void)textFieldChanged:(NSNotification *)n {
    self.loginBtn.enabled = self.serverField.hasText && self.usernameField.hasText && self.passwordField.hasText;
}

- (IBAction)loginBtnClick {
    [PJSipManager sipRegist:self.serverField.text username:self.usernameField.text password:self.passwordField.text];
}

- (IBAction)changeBtnClick {
    BOOL flag = [[NSUserDefaults standardUserDefaults] boolForKey:@"flag"];
    [[NSUserDefaults standardUserDefaults] setBool:!flag forKey:@"flag"];
}

#pragma mark - dealloc
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"♻️ Dealloc %@", NSStringFromClass([self class]));
}


@end
