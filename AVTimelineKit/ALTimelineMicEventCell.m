//
//  ALTimelineMicCell.m
//  ActionLog
//
//  Created by Chris Beeson on 28/05/2014.
//  Copyright (c) 2014 Chris Beeson. All rights reserved.
//

#import "ALTimelineMicEventCell.h"
#import "FontAwesomeKit/FAKFontAwesome.h"

@implementation ALTimelineMicEventCell

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setupChildCells];
    }
    return self;
}

- (UIView *)cellView {
    
    if (!self.view) {
        
        FAKFontAwesome *icon = [FAKFontAwesome microphoneIconWithSize:35];
        [icon addAttribute:NSForegroundColorAttributeName value:[UIColor grayColor]];
        UIImage *img = [icon imageWithSize:CGSizeMake(35, 35)];
        UIImageView *imgView = [[UIImageView alloc] initWithImage:img];
        imgView.userInteractionEnabled =YES;
        [imgView addGestureRecognizer:self.tapGestureRecogniser];
        self.view = imgView;
        
        [self setupChildCells];
    }
    
    self.view.tag = 3;
    return self.view;
}


-(void)updateCellView {
    
}

-(void) setupChildCells {
    
    [self setRoot:self];
    
    // Taping displays a thumbnail cell
    
    self.childSpawnPostion = ALTimelineCellSpawnPostionCentre;
    self.childSpawnPositionOffset = (UIOffset){0,10};
    
    // thumbnailCell.childSpawnPostion = ALTimelineCellSpawnPostionLeft;
    
    //Tapping on the thumbnail cell, displays a photo browser
    
    //  [self setChild:thumbnailCell];
}

- (CGFloat)bottomVerticalPadding {
    return 3.0;
}

@end
