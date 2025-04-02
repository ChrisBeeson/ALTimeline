//
//  ALTimelineClipEventCell.h
//  ActionLog
//
//  Created by Chris Beeson on 27/03/2014.
//  Copyright (c) 2014 Chris Beeson. All rights reserved.
//

#import "ALTimelineEventCell.h"

@class ALTake;

#define  HEIGHT_PERCENTAGE 0.85

@interface ALTimelineClipEventCell : ALTimelineEventCell

@property(nonatomic) ALTimelineView *timeline;
@property (nonatomic) NSInteger forceWidth;  // force width in frames
@property (nonatomic) NSInteger cropFrontFrames;  // crop these frames off the front

@property (nonatomic) BOOL cannotAnimate;
@property (nonatomic) ALTake * take;

@property (nonatomic) UIColor *colour;


@end
