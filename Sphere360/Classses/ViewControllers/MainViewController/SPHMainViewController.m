//
//  SPHMainViewController.m
//  Sphere360
//
//  Created by Kirill on 12/1/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

static NSString *apiURL = @"http://api.360.tv/app.json";

#import "SPHMainViewController.h"
#import "SPHContentListViewController.h"

@interface SPHMainViewController () <UIAlertViewDelegate>

@property (strong, nonatomic) NSURLSession *session;
@property (strong, nonatomic) NSArray *appJson;

@property (strong, nonatomic) NSArray *landscapeConstraints;
@property (strong, nonatomic) NSArray *portraitConstraints;
@property (strong, nonatomic) NSArray *sizeConstraints;

@property (weak, nonatomic) IBOutlet UIButton *photosButton;
@property (weak, nonatomic) IBOutlet UIButton *videosButton;
@property (weak, nonatomic) IBOutlet UIButton *liveButton;
@property (weak, nonatomic) IBOutlet UIView *containerView;

@end

@implementation SPHMainViewController

#pragma mark - LifeCycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.title = @"Menu";
    [self loadData];
    [self setupConstraints];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateUIForOrientation:self.interfaceOrientation];
}

#pragma mark - Rotation

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self updateUIForOrientation:toInterfaceOrientation];
}


- (void)updateUIForOrientation:(UIInterfaceOrientation)orientation
{
    [self updateConstraintsForOrientation:orientation];
}

#pragma mark - Private

- (void)loadData
{
    NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
    [sessionConfiguration setHTTPAdditionalHeaders:@{@"Content-Type": @"application/json", @"Accept": @"application/json"}];
    self.session = [NSURLSession sessionWithConfiguration:sessionConfiguration];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:apiURL]];
    [request setHTTPMethod:@"GET"];
    
    NSURLSessionDataTask *dataTask = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            [[[UIAlertView alloc] initWithTitle:@"No connecton" message:@"Check your Internet connection" delegate:self cancelButtonTitle:@"OK" otherButtonTitles: nil] show];
        } else {
            NSDictionary *jsonResponse = [NSJSONSerialization JSONObjectWithData:data
                                                                         options:kNilOptions
                                                                           error:&error];
            self.appJson = (NSArray *)jsonResponse;
        }
    }];
    
    [dataTask resume];
}

- (void)updateConstraintsForOrientation:(UIInterfaceOrientation)orientation
{
    if (UIInterfaceOrientationIsPortrait(orientation)) {
        [self setPortraitConstraints];
    } else {
        [self setLandscapeConstraints];
    }
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSPredicate *predicate;
    if ([segue.identifier isEqualToString:@"photo"]) {
        predicate = [NSPredicate predicateWithFormat:@"type LIKE 'photo'"];
    } else {
        predicate = [NSPredicate predicateWithFormat:@"type LIKE 'video'"];
    }
    NSArray *content = [self.appJson filteredArrayUsingPredicate:predicate];
    if (content.count) {
        ((SPHContentListViewController *)segue.destinationViewController).dataSource = content;
    } else {
        [[[UIAlertView alloc] initWithTitle:@"No connecton" message:@"Server doesn't response." delegate:self cancelButtonTitle:@"Close" otherButtonTitles: nil] show];
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    [self loadData];
    if (self.navigationController.viewControllers.count > 1) {
        [self.navigationController popToRootViewControllerAnimated:YES];
    }
}

#pragma mark - Constraints

- (void)setLandscapeConstraints
{
    [self.photosButton removeFromSuperview];
    [self.containerView addSubview:self.photosButton];
    [self.photosButton addConstraints:self.sizeConstraints[0]];
    [self.containerView addConstraints:self.landscapeConstraints[0]];
    
    [self.liveButton removeFromSuperview];
    [self.containerView addSubview:self.liveButton];
    [self.liveButton addConstraints:self.sizeConstraints[1]];
    [self.containerView addConstraints:self.landscapeConstraints[1]];
}

- (void)setPortraitConstraints
{
    [self.photosButton removeFromSuperview];
    [self.containerView addSubview:self.photosButton];
    [self.photosButton addConstraints:self.sizeConstraints[0]];
    [self.containerView addConstraints:self.portraitConstraints[0]];
    
    [self.liveButton removeFromSuperview];
    [self.containerView addSubview:self.liveButton];
    [self.liveButton addConstraints:self.sizeConstraints[1]];
    [self.containerView addConstraints:self.portraitConstraints[1]];
}

- (void)setupConstraints
{
    NSArray *photosButtonSizeConstraints = @[[NSLayoutConstraint constraintWithItem:self.photosButton
                                                                              attribute:NSLayoutAttributeWidth
                                                                              relatedBy:NSLayoutRelationEqual
                                                                                 toItem:nil
                                                                              attribute:NSLayoutAttributeWidth multiplier:1.0 constant:70],
                                                 [NSLayoutConstraint constraintWithItem:self.photosButton
                                                                              attribute:NSLayoutAttributeHeight
                                                                              relatedBy:NSLayoutRelationEqual
                                                                                 toItem:nil
                                                                              attribute:NSLayoutAttributeHeight multiplier:1.0 constant:90]];
    NSArray *liveButtonSizeConstraints = @[[NSLayoutConstraint constraintWithItem:self.liveButton
                                                                          attribute:NSLayoutAttributeWidth
                                                                          relatedBy:NSLayoutRelationEqual
                                                                             toItem:nil
                                                                          attribute:NSLayoutAttributeWidth multiplier:1.0 constant:70],
                                             [NSLayoutConstraint constraintWithItem:self.liveButton
                                                                          attribute:NSLayoutAttributeHeight
                                                                          relatedBy:NSLayoutRelationEqual
                                                                             toItem:nil
                                                                          attribute:NSLayoutAttributeHeight multiplier:1.0 constant:90]];
    
    self.sizeConstraints = @[photosButtonSizeConstraints, liveButtonSizeConstraints];
    
    
    NSArray *photoButtonPortraitConstraints = @[[NSLayoutConstraint constraintWithItem:self.containerView
                                                                                  attribute:NSLayoutAttributeTop
                                                                                  relatedBy:NSLayoutRelationEqual
                                                                                     toItem:self.photosButton
                                                                                  attribute:NSLayoutAttributeTop multiplier:1.0 constant:0],
                                                     [NSLayoutConstraint constraintWithItem:self.containerView
                                                                                  attribute:NSLayoutAttributeCenterX
                                                                                  relatedBy:NSLayoutRelationEqual
                                                                                     toItem:self.photosButton
                                                                                  attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0]];
    NSArray *liveButtonPortraitConstraints = @[[NSLayoutConstraint constraintWithItem:self.containerView
                                                                             attribute:NSLayoutAttributeBottom
                                                                             relatedBy:NSLayoutRelationEqual
                                                                                toItem:self.liveButton
                                                                             attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0],
                                                [NSLayoutConstraint constraintWithItem:self.containerView
                                                                             attribute:NSLayoutAttributeCenterX
                                                                             relatedBy:NSLayoutRelationEqual
                                                                                toItem:self.liveButton
                                                                             attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0]];
    self.portraitConstraints = @[photoButtonPortraitConstraints, liveButtonPortraitConstraints];
    
    NSArray *photoButtonLandscapeConstraints = @[[NSLayoutConstraint constraintWithItem:self.containerView
                                                                             attribute:NSLayoutAttributeLeading
                                                                             relatedBy:NSLayoutRelationEqual
                                                                                toItem:self.photosButton
                                                                             attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0],
                                                [NSLayoutConstraint constraintWithItem:self.containerView
                                                                             attribute:NSLayoutAttributeCenterY
                                                                             relatedBy:NSLayoutRelationEqual
                                                                                toItem:self.photosButton
                                                                             attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0]];
    NSArray *liveButtonLandscapeConstraints = @[[NSLayoutConstraint constraintWithItem:self.containerView
                                                                            attribute:NSLayoutAttributeTrailing
                                                                            relatedBy:NSLayoutRelationEqual
                                                                               toItem:self.liveButton
                                                                            attribute:NSLayoutAttributeTrailing multiplier:1.0 constant:0],
                                               [NSLayoutConstraint constraintWithItem:self.containerView
                                                                            attribute:NSLayoutAttributeCenterY
                                                                            relatedBy:NSLayoutRelationEqual
                                                                               toItem:self.liveButton
                                                                            attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0]];
    self.landscapeConstraints = @[photoButtonLandscapeConstraints, liveButtonLandscapeConstraints];
}

@end
