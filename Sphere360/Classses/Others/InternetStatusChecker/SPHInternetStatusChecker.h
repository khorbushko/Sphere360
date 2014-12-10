//
//  PEInternetStatusChecker.h
//  ScrubUp
//
//  Created by Kirill on 11/20/14.
//  Copyright (c) 2014 Thinkmobiles. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Reachability.h"

@interface SPHInternetStatusChecker : NSObject

+ (BOOL)isInternetAvaliable;
+ (BOOL)is3GInternetAvaliable;
+ (BOOL)isWIFIInternetAvaliable;

+ (void)notificationNoInternetAvaliable;

@end
