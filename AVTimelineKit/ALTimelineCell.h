//
//  ALTimelineCell.h
//  ActionLog
//
//  Created by Chris Beeson on 12/02/2014.
//  Copyright (c) 2014 Chris Beeson. All rights reserved.
//

#import "ALTimelineView.h"


typedef NS_ENUM(NSUInteger, ALTimelineCellSpawnPostion) {
    ALTimelineCellSpawnPostionLeft,
    ALTimelineCellSpawnPostionRight,
    ALTimelineCellSpawnPostionCentre,
};


@interface ALTimelineCell : NSObject <ALTimelineContentCell>

@property (nonatomic,strong) UIView *view;
@property (nonatomic,strong) UITapGestureRecognizer *tapGestureRecogniser;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSArray *gestureRecognisers;   // Return array of gesture recognisers


// Animation

@property (nonatomic) UIDynamicAnimator *dynamicAnimator;
- (void)addDynamicsWithAnimator:(UIDynamicAnimator *)animator;

@property (nonatomic) BOOL canAnimate;



// Protocol Requirements

@property (nonatomic,retain) AVTimecode *timecode;

- (void)setTimecode:(AVTimecode *)timecode;

- (AVTimecode *)timecode;
@property (NS_NONATOMIC_IOSONLY, readonly, strong) UIView *cellView;
- (void)updateCellView;




// Tree Handling

@property (nonatomic) ALTimelineCell *parent;
@property (nonatomic) ALTimelineCell *child;
@property (nonatomic) ALTimelineCellSpawnPostion childSpawnPostion;
@property (nonatomic) UIOffset childSpawnPositionOffset;

- (id)root;
- (void)setRoot:(ALTimelineCell*)root;


@property (nonatomic) NSInteger level;
@property (nonatomic) NSInteger highestOpenChild;

@property (nonatomic) BOOL childOpen;

- (void)setParent:(ALTimelineCell*)parent;
- (void)setChild:(ALTimelineCell*)child;

- (void)openChildAnimated:(BOOL)animated;
- (void)closeChild;

- (void)openChildrenToLevel:(NSUInteger)level;

- (void)destroyChild;

@property (nonatomic) BOOL cascadeChildren;    // opens the child of the child


// notifications

- (void)cellWillOpen;
- (void)cellDidOpen;

- (void)cellWillClose;
- (void)cellDidClose;

- (void)cellWillBeginMoving;


- (void)singleTap:(UIGestureRecognizer *)gesture;


// Options Button

@property (nonatomic,strong) UIButton *optionButton;

- (void)notificationRequestsUpdate:(NSNotification *)notification;


@end
