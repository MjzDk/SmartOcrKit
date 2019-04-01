//
//  DKViewController.m
//  OCR
//
//  Created by MjzDK on 03/28/2019.
//  Copyright (c) 2019 MjzDK. All rights reserved.
//

#import "DKViewController.h"
#import "SmartOCRCameraViewController.h"
@interface DKViewController ()

@end

@implementation DKViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}
-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
    SmartOCRCameraViewController *vc = [[SmartOCRCameraViewController alloc] init];
    [self presentViewController:vc animated:YES completion:nil];
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
