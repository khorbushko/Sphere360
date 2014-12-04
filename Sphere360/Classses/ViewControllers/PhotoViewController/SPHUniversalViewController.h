//
//  SPHUniversalViewController
//  Sphere360
//
//  Created by Kirill on 12/1/14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

typedef enum {
    PhotoViewController,
    VideoViewController,
    LiveViewController,
} MediaType;

@interface SPHUniversalViewController : GLKViewController

@property (strong, nonatomic) NSString *sourceURL;
@property (assign, nonatomic) MediaType selectedController;

@end
