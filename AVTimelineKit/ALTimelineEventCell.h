//
//  ALEventCell.h
//  ActionLog
//
//  Created by Chris Beeson on 23/01/2014.
//  Copyright (c) 2014 Chris Beeson. All rights reserved.
//


#import "ALTimelineCell.h"
#import "ALEvent.h"

@interface ALTimelineEventCell : ALTimelineCell


@property (nonatomic,strong) ALEvent *event;
- (void)setEvent:(ALEvent *)event;

// optional for protocol


@end
