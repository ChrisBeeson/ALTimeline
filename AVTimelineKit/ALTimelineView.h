//
//  ALTimelineView.h
//  ALTimeline
//
//  Created by Chris Beeson on 10/01/2014.
//  Copyright (c) 2014 Chris Beeson. All rights reserved.
//

#import "AVTimecode.h"
#import "ALInfiniteScrollView.h"
#import <UIKit/UIKit.h>

@class ALTimelineView;

//#define DYNAMICS
//#define GFX_DEBUG

//#if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
     static const CGFloat kdefaultPointsPerFrameRatio = 0.2;

//#elseif

//   static const CGFloat kdefaultPointsPerFrameRatio = 0.1;
//#endif




static const double kframeRate = 25.0;
static const float ktimecodeRibbonHeight = 44.0;
static const float kContentBottomPadding = 0.0;
static const CGFloat kcontentWidth = 1000.0;


typedef NS_ENUM(NSInteger, ALTimelineAlignment) {
    ALTimelineAlignmentCentre = 1,
    ALTimelineAlignmentLeft,
     ALTimelineAlignmentOffLeft,
    ALTimelineAlignmentRight,
    ALTimelineAlignmentTop,
    ALTimelineAlignmentBottom,
    ALTimelineAlignmentMiddle
};


/*************************************************************************************************************
*
*   Timeline Cells Protocol
*
**************************************************************************************************************/

#pragma mark - Timeline Cells Protocol -


@protocol ALTimelineContentCell <NSObject>

@property (nonatomic,retain) AVTimecode *timecode;

- (UIView *)cellView;

@optional
- (void)updateCellView;
- (void)addDynamicsWithAnimator:(UIDynamicAnimator *)animator;
- (void)setTimeline:(ALTimelineView*)timeline;
- (BOOL)centredOnTimecode;
- (CGFloat)bottomVerticalPadding;
@end




/*************************************************************************************************************
*
*   Timeline Data source Protocol
*
**************************************************************************************************************/

#pragma mark -  Timeline Data source Protocol -

@protocol ALTimelineDataSource <NSObject>

- (NSSet *)contentCellsForStart:(AVTimecode*)startTimecode end:(AVTimecode*)endTimecode;
- (AVTimecode *)timeCurserPosition;
- (AVTimecode *)zoomStartTimecode;
- (AVTimecode *)zoomEndTimecode;

@end


@protocol ALTimelineDelegate <NSObject>

@optional
-(void)timelineDidRecogniseDoubleTap:(id)timeline;
-(void)animatingCellsShouldRefresh;

@end




/*************************************************************************************************************
*
*   Timeline View Interface
*
**************************************************************************************************************/

#pragma mark - Timeline View Interface -


@interface ALTimelineView : UIView <NBInfiniteScrollDataSource, UIScrollViewDelegate, UIGestureRecognizerDelegate>

@property (nonatomic,retain) AVTimecode *absoluteStartTimecode;
@property (nonatomic,retain) AVTimecode *absoluteEndTimecode;

@property (nonatomic, strong) id <ALTimelineDataSource> dataSource;
@property (nonatomic, strong) id <ALTimelineDelegate> delegate;

@property (nonatomic)  CGFloat currentScale;
@property (nonatomic) UILabel *currentScaleDebugLabel;

@property (nonatomic)  BOOL userInControl;


@property (NS_NONATOMIC_IOSONLY, readonly, strong) UIDynamicAnimator *dynamicAnimator;


// Animating and Navigating the Timeline

- (void)animate;
- (void)stop;
- (void)scrollToTimecode:(AVTimecode *)timecode
           alignment:(ALTimelineAlignment)alignment
            animated:(BOOL)animated;

-(void) updateTimeCurser;

- (void)reset;


- (AVTimecode *)timecodeAtPoint:(CGPoint)point;


@property (nonatomic) UIView *timeCurserView;


//  Cell Handling

@property (NS_NONATOMIC_IOSONLY, readonly) CGSize maxCellSize;

/** 
 Add cell to the timeline. Must conform to ALTimelineContentCell protocol
 @param cell
 */

- (void)addCellToTimeline:(id <ALTimelineContentCell>)cell;



// Rotation

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
								duration:(NSTimeInterval)duration;


- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                                         duration:(NSTimeInterval)duration;



// Drawing Methods

- (CGFloat)pointFromFrame:(ALFrame)frame;
- (ALFrame)frameFromPoint:(CGFloat)point;

@end