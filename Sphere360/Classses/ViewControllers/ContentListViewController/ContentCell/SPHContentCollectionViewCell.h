//
//  SPHContentCollectionViewCell.h
//  Sphere360
//
//  Created by Stas Volskyi on 08.12.14.
//  Copyright (c) 2014 Kirill Gorbushko. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SPHContentCollectionViewCell : UICollectionViewCell

@property (weak, nonatomic) IBOutlet UIImageView *thumbnailImageView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;

@end
