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

@end

@implementation SPHMainViewController

#pragma mark - LifeCycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.title = @"Menu";
    [self loadData];
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

@end
