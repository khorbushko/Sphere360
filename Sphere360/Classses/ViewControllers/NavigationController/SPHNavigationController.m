//
//  SPHNavigationController.m
//  Sphere360
//
//  Created by Kirill on 12/1/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

#import "SPHNavigationController.h"

@interface SPHNavigationController ()

@end

@implementation SPHNavigationController

#pragma mark - LifeCycle

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {

    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupNavigationBar];
}

#pragma mark - Private

- (void)setupNavigationBar
{
    [self.navigationBar setBackgroundImage:[UIImage imageWithColor:[UIColor colorWithRed:248/255.0 green:248/255.0 blue:248/255.0 alpha:0.85]] forBarMetrics:UIBarMetricsDefault];
}

@end
