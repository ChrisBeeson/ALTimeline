//
//  ALTimelineView.m
//  ALTimeline
//
//  Created by Chris Beeson on 10/01/2014.
//  Copyright (c) 2014 Chris Beeson. All rights reserved.
//

#import "ALTimelineView.h"
#import "ALTimelineEventCell.h"
#import "ALTimelineTouchView.h"
#import "ALTimelineClipEventCell.h"
#import "ALTimecodeRibbonView.h"
#import "UIView+TagZOrder.h"


@interface ALTimelineView () {
    
    ALInfiniteScrollView *_timelineScrollView;
    
    NSMutableDictionary *_contentCells;
    
    UITapGestureRecognizer * _doubletapGestureRecogniser;
    UITapGestureRecognizer * _singletapGestureRecogniser;
    UIPinchGestureRecognizer * _pinchGestureRecogniser;
    
    // Zoom
    BOOL _isZooming;
    UIView *_zoomView;
    ALTimecodeRibbonView *_zoomRibbonView;
    NSSet * _zoomContentCells;
    
    // Animation
    BOOL _animating;
    BOOL _scrollViewStartingAnimation;
    BOOL _userBecomingInControl;
    
}
@end


@implementation ALTimelineView

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self internalInit];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self internalInit];
    }
    return self;
}

- (instancetype) awakeAfterUsingCoder:(NSCoder*)aDecoder
{
    
    self = [super awakeAfterUsingCoder:aDecoder];
    if (self) {
        [self internalInit];
    }
    return self;
}


- (void)internalInit {
    
    _contentCells = [[NSMutableDictionary alloc] init];
    
    self.backgroundColor = [UIColor groupTableViewBackgroundColor];
    
    // Add scrollView to view
    
    _timelineScrollView = [[ALInfiniteScrollView alloc] initWithFrame:CGRectZero];
    _timelineScrollView.delegate = self;
    _timelineScrollView.datasource = self;
    _timelineScrollView.backgroundColor = [UIColor groupTableViewBackgroundColor];
    _timelineScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth| UIViewAutoresizingFlexibleHeight;
    [self addSubview:_timelineScrollView];
    
    
    // init the timeCurser
    
    _timeCurserView = [[UIView alloc] initWithFrame:(CGRect){50,0,1,self.frame.size.height-ktimecodeRibbonHeight}];
    _timeCurserView = [[UIView alloc] initWithFrame:CGRectZero];
    _timeCurserView.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0];
    _timeCurserView.clipsToBounds = NO;
    _timeCurserView.tag = 900;
    
    [self addObserver:self forKeyPath:@"_timeCurserView.frame" options:NSKeyValueObservingOptionOld context:NULL];
    
    
    // Default Settings
    
    _absoluteStartTimecode = [AVTimecode timecodeWithFramesFromZero:0];
    _absoluteEndTimecode = [AVTimecode timecodeWithString:@"23:59:59:24"];
    _isZooming = NO;
    _currentScale = kdefaultPointsPerFrameRatio;
    _animating = NO;
    _userInControl = YES;
    _userBecomingInControl = NO;
    _scrollViewStartingAnimation = NO;
    
    
    // Gesture Recognisers
    
    // _userInControl = YES - Requires a double tap recogniser to switch to _userInControl = NO;
    // _userInControl = NO - Requires a pan to recognised.
    
    
    // Single Tap
    
    _singletapGestureRecogniser = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(singleTapRecognised:)];
    _singletapGestureRecogniser.numberOfTapsRequired = 1;
    _singletapGestureRecogniser.enabled = YES;
    _singletapGestureRecogniser.cancelsTouchesInView = NO;
    [_timelineScrollView addGestureRecognizer:_singletapGestureRecogniser];
    
    
    // Double Tap
    
    _doubletapGestureRecogniser = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                          action:@selector(doubleTapRecognised:)];
    _doubletapGestureRecogniser.numberOfTapsRequired = 2;
    _doubletapGestureRecogniser.enabled=YES;
    _doubletapGestureRecogniser.cancelsTouchesInView = NO;
    [_timelineScrollView addGestureRecognizer:_doubletapGestureRecogniser];
    
    
    // Pinch Gesture - Zoom
    
    _pinchGestureRecogniser = [[UIPinchGestureRecognizer alloc] initWithTarget:self
                                                                        action:@selector(handlePinchGesture:)];
    _pinchGestureRecogniser.cancelsTouchesInView = NO;
    [_timelineScrollView addGestureRecognizer:_pinchGestureRecogniser];
    
    
    // Observers
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(notificationRequestsCellRemove:)
                                                 name:@"ALTimelineCellRemove"
                                               object:nil];
    
#ifdef GFX_DEBUG
    _currentScaleDebugLabel = [[UILabel alloc] initWithFrame:CGRectMake(4, 4, 100, 30)];
    _currentScaleDebugLabel.clipsToBounds = NO;
    _currentScaleDebugLabel.textColor =[UIColor darkGrayColor];
    _currentScaleDebugLabel.font =[UIFont boldSystemFontOfSize:10];
    _currentScaleDebugLabel.text = [NSString stringWithFormat:@"%f",_currentScale];
    [self addSubview:_currentScaleDebugLabel];
    
    [self observeProperty:@"_currentScale" withBlock:^(__weak id self, id old, id new) {
        
        [[self currentScaleDebugLabel] setText:[NSString stringWithFormat:@"%@",new]];
    }];
#endif
    
}



-(void) layoutSubviews {
    
    _timelineScrollView.frame = (CGRect){0,0,self.frame.size.width,self.frame.size.height};
}


- (void)update{
    
    [self animationLoop];
}



- (void)dealloc {
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    NSLog(@"Timeline dealloc");
}



/*************************************************************************************************************
 *
 *   Timeline Methods
 *
 **************************************************************************************************************/

#pragma mark - Timeline Methods -


/**
 Setting the absoluteStartTimecode resets the scrollview completely, and reloads all datasources
 */

- (void)setAbsoluteStartTimecode:(AVTimecode *)absoluteStartTimecode {
    
    _absoluteStartTimecode = absoluteStartTimecode;
    //  [_timelineScrollView hardRefresh];
}

- (void)setAbsoluteEndTimecode:(AVTimecode *)absoluteEndTimecode {
    
    _absoluteEndTimecode = absoluteEndTimecode;
    //[_timelineScrollView hardRefresh];
}


- (void)reset {
    
    [_contentCells removeAllObjects];
    [_timelineScrollView hardReset];
}


- (void)scrollToTimecode:(AVTimecode *)timecode alignment:(ALTimelineAlignment)alignment animated:(BOOL)animated {
    
    NSInteger currentPageNumber;
    ALFrame destinationFrame;
    NSInteger destPageNumber;
    CGFloat alignmentOffset = 0.0;
    
    // Calculate alignment offset
    
    switch (alignment) {
            
        case ALTimelineAlignmentCentre:
            alignmentOffset = _timelineScrollView.frame.size.width/2;
            break;
            
        case ALTimelineAlignmentRight:
            alignmentOffset = _timelineScrollView.frame.size.width;
            break;
            
        case ALTimelineAlignmentOffLeft:
            alignmentOffset = 50;
            break;
            
        default:
            break;
    }
    
    
    // Validate Dest timecode
    
    NSAssert(timecode, @"Timecode cannot be NULL");
    
    destinationFrame = [timecode framesFromZero];
    // destinationFrame-= frameOffset;               // normalise destframe to be first frame on left
    
    if (destinationFrame < [_absoluteStartTimecode framesFromZero]) {
        // NSAssert(nil,@"Scroll time %@ before absolute start time %@",timecode.string,_absoluteStartTimecode.string);
        destinationFrame = [_absoluteStartTimecode framesFromZero];
    }
    
    destPageNumber = [self pageIndexForFrame:destinationFrame];
    destPageNumber--;
    
    if (destPageNumber <0) {
        NSLog(@"%s Page Number lower than 0",__PRETTY_FUNCTION__);
        destPageNumber = 0;
    }
    
    if ([[_timelineScrollView visibleViews] count] ==0) {
        [_timelineScrollView setPage:destPageNumber];
        [_timelineScrollView layoutSubviews];
        currentPageNumber = destPageNumber;
    } else {
        
        currentPageNumber = [self pageIndexForFrame:[self firstFrameVisible]];
        currentPageNumber --;
        
        if(currentPageNumber<0) currentPageNumber =0;
    }
    
    
    // If we're greater than a page away then we need to reset and redraw the pages.
    
    ALFrame dist = destinationFrame - [self firstFrameVisible];
    ALFrame currentWidth = [self frameFromPoint:kcontentWidth];
    NSInteger pageToResetTo = destPageNumber;
    
    [_timelineScrollView setAllowRecentering:NO];
    
    if (abs((int)dist) > currentWidth) {
        
        // we're greater than a page, so if animated we need to go +1 on either side.
        
        if (animated) {
            
            NSInteger forwardOrBack = (currentPageNumber > destPageNumber) ? -1 : 1;
            pageToResetTo  =  destPageNumber-forwardOrBack;
            if (pageToResetTo <0) pageToResetTo = 0;
        }
        
        [_timelineScrollView setPage:pageToResetTo];
        [_timelineScrollView layoutSubviews];
        [_timelineScrollView setContentOffset:(CGPoint){0,0} animated:NO];
    }
    
    // So we're in the right region, what ofset do we need to apply?
    
    ALFrame framesToTravel = destinationFrame - [self firstFrameVisible];
    CGFloat pointsToTravel = [self pointFromFrame:framesToTravel]-alignmentOffset;
    
    [_timelineScrollView setContentOffset:(CGPoint){_timelineScrollView.contentOffset.x+pointsToTravel,0} animated:animated];
    
    [_timelineScrollView setAllowRecentering:YES];
}




-(void) setUserInControl:(BOOL)userInControl {
    
    _userInControl = userInControl;
    [self animationLoop];
}




/*************************************************************************************************************
 *
 *   InfiniteScrollView Datasource Calls
 *
 **************************************************************************************************************/

#pragma mark - InfiniteScrollView Datasource Calls -


- (UIView *)infiniteScrollView:(id)scrollView viewForIndex:(NSUInteger)index{
    
    ddLogLevel = LOG_LEVEL_WARN;
    
    DDLogVerbose(@"Infinite ScrollView Request page for index:%lu", (unsigned long)index);
    
    // Init the view
    
    CGFloat scrollViewHeight = _timelineScrollView.frame.size.height;
    
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kcontentWidth, scrollViewHeight)];
    view.clipsToBounds = NO;
    view.userInteractionEnabled = YES;
    
    
    // Return if this if we want a solid a start or end page
    
    /*
     if (index == 0 || index ==([self numberOfPagesForScrollView:nil]+1) ) {
     
     UIView *endBar =[[UIView alloc] initWithFrame:CGRectMake(0, 0, _timelineScrollView.frame.size.width, _timelineScrollView.frame.size.height)];
     [view addSubview:endBar];
     return view;
     }
     */
    
    // Calc start and End Timecode of the page
    
    NSRange range = [self framesForPageWithIndex:(index)];
    AVTimecode *startTC = [AVTimecode timecodeWithFramesFromZero:range.location];
    AVTimecode *endTC =[AVTimecode timecodeWithFramesFromZero:range.location+range.length];
    
    DDLogVerbose(@"Page Start TC:%@  End:%@",startTC.string,endTC.string);
    
    ALTimecodeRibbonView *timecodeRibbon = [[ALTimecodeRibbonView alloc] initWithFrame:CGRectMake(0, (scrollViewHeight-ktimecodeRibbonHeight), kcontentWidth, ktimecodeRibbonHeight)
                                                                         startTimecode:startTC
                                                                                   end:endTC
                                                                 absoluteStartTimecode:_absoluteStartTimecode
                                                                       highDetailLevel:YES];
    
    timecodeRibbon.tag =1;
    
    
    // Get Cells from datasource
    
    NSAssert(_dataSource,@"Datasource is NULL");
    NSSet * contentCells =  [_dataSource contentCellsForStart:startTC end:endTC];
    
    // Build the view of cells
    
    UIView *contentView = [self contentPageWithCells:contentCells forIndex:index];
    contentView.clipsToBounds = NO;
    contentView.userInteractionEnabled = YES;
    
    // Add the timecode ribbon
    // 1st add the white at zindex 0
    
    UIView *ribbonBg = [[UIView alloc] initWithFrame:CGRectMake(0, (scrollViewHeight-ktimecodeRibbonHeight), kcontentWidth, ktimecodeRibbonHeight)];
    ribbonBg.backgroundColor = [UIColor whiteColor];
    ribbonBg.tag = 0;
    
    [contentView addSubview:ribbonBg];
    [contentView addSubview:timecodeRibbon];
    
#ifdef GFX_DEBUG
    UILabel *pageNumLeft = [[UILabel alloc] initWithFrame:CGRectMake(4, scrollViewHeight-30, 30, 30)];
    pageNumLeft.clipsToBounds = NO;
    pageNumLeft.textColor =[UIColor darkGrayColor];
    pageNumLeft.font =[UIFont boldSystemFontOfSize:15];
    pageNumLeft.text = [NSString stringWithFormat:@"%i",index];
    pageNumLeft.tag = 4;
    [contentView addSubview:pageNumLeft];
#endif
    
    return contentView;
}



- (UIView *)contentPageWithCells:(NSSet *)cells forIndex:(NSUInteger)index
{
    DDLogVerbose(@"Building content page:%lu",(unsigned long)index);
    
    CGFloat width = [self infiniteScrollView:nil expectedWidthForPage:index];
    
    UIView *page = [[UIView alloc] initWithFrame:(CGRect){0, 0, width, (_timelineScrollView.frame.size.height)}];
    page.userInteractionEnabled = NO;
    
    // Draw grey line across the top
    
    UIView *greyseperatorline = [[UIView alloc] initWithFrame:CGRectMake(0, 0, kcontentWidth, 1)];
    greyseperatorline.backgroundColor = [UIColor lightGrayColor];
    [page addSubview:greyseperatorline];
    
    NSRange frameRange = [self framesForPageWithIndex:index];
    
    for (id <ALTimelineContentCell> cell in cells) {
        
        // Is the cell within the range of the page?
        
        AVTimecode *startFrameTimecode = [cell timecode];
        
        if (NSLocationInRange([startFrameTimecode framesFromZero], frameRange)) {
            
            [self storeCell:cell index:index];
            [self addCell:cell toView:page viewFrameRange:frameRange];
            
        } else {
            
            ALFrame v = [startFrameTimecode framesFromZero]-[self framesForPageWithIndex:index].location;
            
            NSLog(@"Datasource supplied Content Cell that is outside of range by %li",(long)v);
        }
    }
    
    return page;
}


- (void)infiniteScrollView:(id)scrollView didFinishAddingViewsToPage:(NSUInteger)index {
    
    if (_contentCells[@(index)]) {
        
        [_contentCells[@(index)] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            
            // Pinch Gesture overrides any other gesture
            
            if ([obj respondsToSelector:@selector(gestureRecognisers)])  {
                
                for (UIGestureRecognizer *recogniser in [obj gestureRecognisers]) {
                    [recogniser requireGestureRecognizerToFail:_pinchGestureRecogniser];
                }
            }
            
            // Add dynamics to added Cells
            
            if ([obj respondsToSelector:@selector(addDynamicsWithAnimator:)]) {
                
                [obj addDynamicsWithAnimator:[_timelineScrollView dynamicAnimator]];
            }
        }];
    }
}


- (void)infiniteScrollViewdidFinishLayingOutSubviews:(id)scrollView {
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ALTimelineViewDidLayoutSubviews"  object:nil];
    
    [self updateTimeCurser];
}


- (void)infiniteScrollView:(id)scrollView willRemoveIndex:(NSUInteger)index {
    
    if (scrollView == _timelineScrollView) {
        
        if (_contentCells[@(index)]) {
            
            // Tell all cells to close (remove from superview)
            
            [(NSArray*)_contentCells[@(index)] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                
                // By closing the rootChild all other children will cascade.
                
                [(ALTimelineCell*)obj closeChild];
            }];
            
            [_contentCells removeObjectForKey:@(index)];
        }
    }
}


- (NSUInteger)numberOfPagesForScrollView:(id)scrollView  {
    
    NSUInteger totalFrames = [_absoluteEndTimecode framesFromZero] - [_absoluteStartTimecode framesFromZero];
    
    double pages = (double)totalFrames/(double)[self frameFromPoint:kcontentWidth];
    
    if (--pages <1) {
        
        //TODO: Support 1 page
        // Ideally this should support only one page.
        pages = 2;
    }
    
    return (NSUInteger)ceilf(pages);
}


- (CGFloat)infiniteScrollView:(id)scrollView expectedWidthForPage:(NSUInteger)index {
    /*
    CGFloat width;
    
    if (index != [self numberOfPagesForScrollView:nil]) {
        
        width = kcontentWidth;
        
    } else {
        
        // it's very probable that the last page will be shorter than kContentWidth
        
        ALFrame totalFrames = [_absoluteEndTimecode framesFromZero] - [_absoluteStartTimecode framesFromZero];
        ALFrame framesInWidth = [self frameFromPoint:kcontentWidth];
        CGFloat pages = (float)totalFrames/(float)framesInWidth;
        CGFloat remainer = pages - floorf(pages);
        
        width = kcontentWidth * remainer;
    }
    */
    // DDLogInfo(@"Page index %i, Expected width:%2f",index, width);
    // return width;
    // TODO: support pages of a shorter length
    
    return  kcontentWidth;
}


- (UIDynamicAnimator*) dynamicAnimator {
    
    return [_timelineScrollView dynamicAnimator];
}


/*************************************************************************************************************
 *
 *   Drawing Helpers
 *
 **************************************************************************************************************/


#pragma mark - Drawing Helpers -


- (ALFrame)frameFromPoint:(CGFloat)point
{
    return roundf((point / _currentScale));
}

- (CGFloat)pointFromFrame:(ALFrame)frame
{
    return (frame *  _currentScale);
}


- (NSRange)framesForPageWithIndex:(NSInteger)index {
    
    ALFrame length  = [self frameFromPoint:(kcontentWidth)];
    ALFrame startOfpage = roundf(index * [self frameFromPoint:kcontentWidth]);
    ALFrame pageStartFrame = [_absoluteStartTimecode framesFromZero]+startOfpage+roundf(((index * 1)));
    
    // We need index 1 = absoluteStartTimecode.  NOT page 0.
    
    return  NSMakeRange(pageStartFrame-length, length);
}


- (NSInteger) pageIndexForFrame:(ALFrame)frame {
    
    ALFrame contentWidth = [self frameFromPoint:kcontentWidth];
    frame -= [_absoluteStartTimecode framesFromZero];
    
    NSInteger index = floorf(frame/contentWidth);
    
    index++;
    
    return index;
}


- (ALFrame)firstFrameVisible {
    
    // TODO: Depreciate this, use frame from point instead.
    
    ALFrame fr = 0;
    
    for (UIView *view in [_timelineScrollView visibleViews]) {
        
        CGRect rect = [_timelineScrollView convertRect:_timelineScrollView.bounds toView:view];
        
        if (rect.origin.x >= 0) {
            
            ALFrame pageStartFrame = _absoluteStartTimecode.framesFromZero + ((view.tag-1) * [self frameFromPoint:kcontentWidth]) + view.tag-1;
            
            fr = pageStartFrame + [self frameFromPoint:rect.origin.x];
            break;
        }
    }
    
#ifdef GFX_DEBUG
    _currentScaleDebugLabel.text = [[AVTimecode timecodeWithFramesFromZero:fr] string];
#endif
    
    return fr;
}



- (ALFrame)frameAtPoint:(CGPoint)point {
    
    ALFrame frame = [self firstFrameVisible]+[self frameFromPoint:point.x];
    
    if (frame <0) frame =0;
    
    return frame;
}


- (AVTimecode *)timecodeAtPoint:(CGPoint)point {
    
    return [AVTimecode timecodeWithFramesFromZero:[self frameAtPoint:point]];
}



- (BOOL)isFrameVisible:(ALFrame)frame padding:(CGFloat)padding {
    
    if (frame<[self firstFrameVisible]-padding || frame>[self firstFrameVisible]+[self frameFromPoint:_timelineScrollView.bounds.size.width]+padding) {
        return NO;
    }
    return YES;
}


/*************************************************************************************************************
 *
 *   Working With Cells
 *
 **************************************************************************************************************/

#pragma mark - Cell Handling -


- (CGSize)maxCellSize {
    
    return CGSizeMake(CGFLOAT_MAX, _timelineScrollView.frame.size.height-ktimecodeRibbonHeight);
}



-(void)storeCell:(id)cell index:(NSUInteger)index {
    
    ddLogLevel = LOG_LEVEL_WARN;
    
    // Store the cell
    
    NSMutableArray *array;
    
    if (_contentCells[@(index)]) {
        
        array = _contentCells[@(index)];
        [array addObject:cell];
        
    } else {
        
        array = [[NSMutableArray alloc] init];
        [array addObject:cell];
    }
    
    DDLogVerbose(@"%s Added %@ to dictionary index:%lu",__FUNCTION__,array,(unsigned long)index);
    
    _contentCells[@(index)] = array;
}



- (void)addCellToTimeline:(id <ALTimelineContentCell>)cell
{
    // What page is it on ?
    
    NSInteger index =  [self pageIndexForFrame:[[cell timecode] framesFromZero]];
    NSAssert(index>0,@"Index page can't be lower than 0");
    
    // get the view from the scrollview
    
    UIView *pageView = [_timelineScrollView viewForIndexPage:index];
    
    if (pageView) {
        
        // Theres a view (so it's visible
        // save it to _contentCells
        
        [self storeCell:cell index:index];
        
        // add it to the view
        
        [self addCell:cell toView:pageView viewFrameRange:[self framesForPageWithIndex:index]];
        
        // now need to get the scrollview to copy...
        
        [_timelineScrollView contentDidChangeOnIndexPage:index];
        
        [cell updateCellView];
    }
}



- (void)addCell:(id <ALTimelineContentCell>)cell toView:(UIView *)view viewFrameRange:(NSRange)range {
    
    ALFrame frame = [[cell timecode] framesFromZero];
    
    // Is the cell timecode within range of the index?
    
    if (!NSLocationInRange(frame, range)){
        
        NSLog(@"%s cell is visible but the frame %li was not in range of the page %@",__PRETTY_FUNCTION__,(long)frame,NSStringFromRange(range));
        return;
    }
    
    // Get the view
    
    [(ALTimelineCell*)cell setCanAnimate:NO];
    UIView *cellView = [cell cellView];
    [(ALTimelineCell*)cell setCanAnimate:YES];
    
    if ([cell respondsToSelector:@selector(setTimeline:)]) [cell setTimeline:self];
    
    // Calc Horz postion
    // whats the points per frame for the view and range
    
    CGFloat pointsPerFrame = view.frame.size.width / range.length;
    
    CGFloat x = (frame - range.location) *pointsPerFrame;
    
    BOOL centreCell = YES;
    if ([cell respondsToSelector:@selector(centredOnTimecode)]) centreCell = [cell centredOnTimecode];
    
    x -= centreCell ? (cellView.frame.size.width/2) : 0;
    
    
    // Calc Vertical position
    
    CGFloat vertPadding = 0.0;
    if ([cell respondsToSelector:@selector(bottomVerticalPadding)]) vertPadding = [cell bottomVerticalPadding];
    
    CGFloat y = view.frame.size.height - ktimecodeRibbonHeight - cellView.frame.size.height - kContentBottomPadding - vertPadding;
    
    cellView.frame = CGRectMake(x , y, cellView.frame.size.width, cellView.frame.size.height);
    cellView.userInteractionEnabled = YES;
    
    [view addSubview:cellView];
    
    [cell updateCellView];
}


/**
 Notification call handler to remove timeline cell
 
 - the cell should probably be asked to be removed...
 */

- (void)notificationRequestsCellRemove:(NSNotification *)notification {
    
    __block  NSMutableArray *array;
    __block id cell;
    
    [_contentCells enumerateKeysAndObjectsWithOptions:NSEnumerationConcurrent
                                           usingBlock:^(id key, id obj, BOOL *stop) {
                                               
                                               for (id evt in (NSMutableArray*)obj){
                                                   
                                                   if([evt event] == notification.object) {
                                                       array = obj;
                                                       cell = evt;
                                                       *stop = YES;
                                                   }
                                               }
                                           }];
    
    [[cell event] MR_deleteEntity]; // Pretty hardcore deleting it!
    [array removeObject:cell];
}



/*************************************************************************************************************
 *
 *    Animation
 *
 **************************************************************************************************************/

#pragma mark - Animation -


-(void)animate
{
    [self reset];
    _animating = YES;
    [self animationLoop];
}

-(void)stop
{
    _animating = NO;
    [_timeCurserView.layer removeAllAnimations];
    [_timelineScrollView.layer removeAllAnimations];
}


-(void)animationLoop
{
    if (!_animating) return;
    
    [self updateTimeCurser];
    
    if (!_userInControl) {
        
        if (_timeCurserView.hidden) _timeCurserView.hidden = NO;
        
        // if the user isn't in control then the curser sits in the middle and the scrollView animates.
        // is the timecurser already in the middle?
        
        AVTimecode *timecode = [_dataSource timeCurserPosition];
        
        // This can cause an infinite loop.
        // So we only scroll if we need to.
        
        // what frame is currently in the centre and what is the difference to timecode?
        
        ALFrame currentCentreFrame = [self frameAtPoint:(CGPoint){_timelineScrollView.bounds.size.width/2,0}];
        ALFrame timeCurserPosition = timecode.framesFromZero;
        ALFrame framesdiff = abs((int)(currentCentreFrame-timeCurserPosition));
        
        if(framesdiff>50) {    // For some reason we've missed the mark...
            
            DDLogInfo(@"%s Not Centred - Frame Diff %li",__PRETTY_FUNCTION__,(long)framesdiff);
            
            [_timelineScrollView.layer removeAllAnimations];
            
            [_timelineScrollView setNeedsLayout];
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                
                [self scrollToTimecode:timecode
                             alignment:ALTimelineAlignmentCentre
                              animated:NO];
                
                //TODO: Don't force user to be in control
                
                //  _userInControl = YES;
                
                [self animationLoop];
            });
            
            return;
        }
        
        
        // Animate
        
        [UIView animateWithDuration:ANIM_LOOP_DURATION
                              delay:0.0
                            options:UIViewAnimationOptionCurveLinear|UIViewAnimationOptionAllowUserInteraction
                         animations:^{
                             
                             CGFloat newOffset = _timelineScrollView.contentOffset.x+[self pointFromFrame:ANIM_LOOP_DURATION*kframeRate];
                             CGRect rect = (CGRect){newOffset,0,_timelineScrollView.bounds.size.width,_timelineScrollView.bounds.size.height};
                             _timelineScrollView.bounds = rect;
                             
                         }
                         completion:^(BOOL completed){
                             
                             
                             
                             
                             if  (completed) {
                                 
                                 
                                 [_timelineScrollView layoutSubviews];
                                 
                                 dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                     [self animationLoop];
                                 });
                             }
                         }];
    }
}



-(void) updateTimeCurser {
    
    NSAssert(_dataSource, @"Datasource must be connected");
    NSAssert([_dataSource respondsToSelector:@selector(timeCurserPosition)], @"Datasource must respond to timeCurserPosition");
    
    if (!_animating) return;
    
    // if the datasource returns nil the curser needs to be hidden
    
    if (![_dataSource timeCurserPosition]) {
        _timeCurserView.hidden = YES;
        return;
    }
    
    // Is the timecurser visible?
    
    ALFrame curserFrame = [[_dataSource timeCurserPosition] framesFromZero];
    
    if (_userInControl && ![self isFrameVisible:curserFrame padding:100.0]) {
        _timeCurserView.hidden = YES;
        return;
    }
    
    _timeCurserView.hidden = NO;
    [_timeCurserView.layer removeAllAnimations];
    
    // What page is the timecurser on?
    
    NSInteger index = [self pageIndexForFrame:curserFrame];
    
    // Work out it's x postion in this page
    
    NSRange pageRange = [self framesForPageWithIndex:index];
    ALFrame framesFromStartOfPage = curserFrame - pageRange.location;
    CGFloat x = [self pointFromFrame:framesFromStartOfPage];
    
    // Move the curser to correct position.
    
    CGSize cursz = CGSizeMake(1, _timelineScrollView.frame.size.height-ktimecodeRibbonHeight);
    _timeCurserView.frame = CGRectMake(x, 0, cursz.width, cursz.height);
    
    // Add it to the view
    
    [_timelineScrollView addSubview:_timeCurserView toIndexPage:index];
    
    // Animate
    
    [UIView animateWithDuration:ANIM_LOOP_DURATION
                          delay:0.0
                        options:UIViewAnimationOptionCurveLinear
                     animations:^{
                         
                         CGFloat x = _timeCurserView.frame.origin.x;
                         CGFloat point = x+[self pointFromFrame:(ANIM_LOOP_DURATION*25)];
                         
                         _timeCurserView.frame = CGRectMake(point, 0, cursz.width, cursz.height);
                     }
                     completion:^(BOOL completed){
                         
                         if  (completed) [self updateTimeCurser];
                     }];
    
    // if the project is not logging make sure there is no subviews.
    // TODO: This is a cheat
    
    ALProject *proj = [[ALManager manager] currentProject];
    
    if (!proj.isLoggingValue && _timeCurserView.subviews.count>0 ) {
        [_timeCurserView.subviews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [obj removeFromSuperview];
        }];
    }
    
    return;
}



/*************************************************************************************************************
 *
 *   Zoom
 *
 **************************************************************************************************************/

#pragma mark - Zoom -

// Zoom works by recognising the beginning of a pinch gesture
// Asking the datasource the start and end timecodes of the zoom content
// Asking the datasource for all of the zoom content
// Generating a content page, using those timecodes at the current scale
// The minimal ribbon view is used.
// This large view is postioned on top of the scroll view.

// As zoom occurs the zoom view is resized accordingly.
// the objects on the page are animated out accordingly.
// Clip events need to be redrawn - so these need to be kept alive / keep everything alive.
// the position of the view is moved to give the appearance the zoom is happened at the touch point.

// The zoom view min zoom is the width of the screen.
// Max?


- (void)handlePinchGesture:(UIPinchGestureRecognizer *)gestureRecognizer {
    
    static ALFrame zoomStart;
    static ALFrame zoomEnd;
    static CGFloat scaleFactor;
    static ALFrame frameRange;
    static CGFloat delta;
    static CGFloat newPointsPerFrame;
    static CGFloat previousScale;
    static UIView *zoomViewBackground;
    
    
#define MAX_POINTS_PER_FRAME 0.4
    
    switch (gestureRecognizer.state) {
            
        case UIGestureRecognizerStateBegan: {
            
            scaleFactor = 0.0;
            delta = 0.0;
            _isZooming = YES;
            
            newPointsPerFrame = _currentScale;
            zoomStart = [[_dataSource zoomStartTimecode] framesFromZero];
            zoomEnd =[[_dataSource zoomEndTimecode] framesFromZero];
            frameRange = zoomEnd-zoomStart;
            
            // Create the content zoomView
            
            _zoomView = [self zoomViewForStart:zoomStart end:zoomEnd];
            
            // Create background view
            
            zoomViewBackground = [[UIView alloc] initWithFrame:_zoomView.bounds];
            
            UIView *ribbonBg = [[UIView alloc] initWithFrame:CGRectMake(0, (_zoomView.frame.size.height-ktimecodeRibbonHeight), _zoomView.frame.size.width, ktimecodeRibbonHeight)];
            ribbonBg.backgroundColor = [UIColor whiteColor];
            ribbonBg.autoresizingMask =  UIViewAutoresizingFlexibleWidth;
            [zoomViewBackground addSubview:ribbonBg];
            
            UIView *topGreyseperatorline = [[UIView alloc] initWithFrame:CGRectMake(0,0, _zoomView.frame.size.width, 1)];
            topGreyseperatorline.backgroundColor = [UIColor lightGrayColor];
            topGreyseperatorline.autoresizingMask =  UIViewAutoresizingFlexibleWidth;
            [zoomViewBackground addSubview:topGreyseperatorline];
            
            UIView *greyseperatorline = [[UIView alloc] initWithFrame:CGRectMake(0, (_zoomView.frame.size.height-ktimecodeRibbonHeight), _zoomView.frame.size.width, 1)];
            greyseperatorline.backgroundColor = [UIColor lightGrayColor];
            greyseperatorline.autoresizingMask =  UIViewAutoresizingFlexibleWidth;
            [zoomViewBackground addSubview:greyseperatorline];
            
            [_timelineScrollView addSubview:zoomViewBackground];
            [_timelineScrollView addSubview:_zoomView];
            
            // set the content size of the scrollview
            
            _timelineScrollView.contentSize = _zoomView.frame.size;
            
            // postion the content so it matches the current view
            
            ALFrame currentStartFrame = [self firstFrameVisible];
            ALFrame diff = currentStartFrame-zoomStart;
            CGFloat pointdiff = [self pointFromFrame:diff];
            
            [_timelineScrollView setActive:NO];     // <- Needs to be here
            [self reset];
            
            _timelineScrollView.contentOffset = (CGPoint){pointdiff,0};
            
            previousScale = [gestureRecognizer scale];
            
            break;
        }
            
            
        case UIGestureRecognizerStateChanged: {
            
            scaleFactor = 1 - ((previousScale - [gestureRecognizer scale]));
            
            CGRect zoomViewFrame = [_zoomView frame];
            CGFloat newViewWidth = zoomViewFrame.size.width*scaleFactor;
            CGFloat widthDelta;
            
            // we cant zoom out further than the size of the scrollViewWidth
            
            if (newViewWidth < _timelineScrollView.bounds.size.width) break;
            
            widthDelta = newViewWidth-zoomViewFrame.size.width;
            newPointsPerFrame = newViewWidth/(float)frameRange;
            
            // nor can we zoom in too far
            
            if (newPointsPerFrame > MAX_POINTS_PER_FRAME) break;
            
            // resize the main view
            
            zoomViewFrame.size = CGSizeMake(newViewWidth, zoomViewFrame.size.height);
            [_zoomView setFrame:zoomViewFrame];
            
            // Resize ribbonView
            
            CGRect ribbonFrame = [_zoomRibbonView frame];
            ribbonFrame.size = zoomViewFrame.size;
            [_zoomRibbonView setFrame:ribbonFrame];
            
            // Resize the contentSize
            
            _timelineScrollView.contentSize = zoomViewFrame.size;
            zoomViewBackground.frame = (CGRect){0,0,zoomViewFrame.size.width,zoomViewFrame.size.height};
            
            // Keep an oversized view centred
            
            CGPoint pinchPoint = [gestureRecognizer locationInView:_zoomView];
            CGFloat pc = pinchPoint.x/zoomViewFrame.size.width;
            CGFloat newContentOffset = _timelineScrollView.contentOffset.x + (widthDelta*pc);
            
            if (newContentOffset<0) newContentOffset = 0;
            
            _timelineScrollView.contentOffset = (CGPoint){newContentOffset,0};
            
            // ribbon
            
            delta += scaleFactor;
            
            if (fabs(delta)>10) {       // Should we redraw the ribbonView?
                
                [_zoomRibbonView setNeedsDisplay];
                delta = 0;
                
            } else {               // No move all subviews
                
                [_zoomRibbonView.subviews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    
                    if ([obj tag] != 90) {
                        
                        UIView *view = (UIView*)obj;
                        CGRect frame = view.frame;
                        CGPoint point = frame.origin;
                        CGFloat x = ((point.x + view.frame.size.width/2) * scaleFactor) - view.frame.size.width/2;
                        point.x = x;
                        frame.origin = point;
                        view.frame = frame;
                    }
                }];
            }
            
            
            // content cells
            
            [self setCurrentScale:newPointsPerFrame];
            
            [_zoomContentCells enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
                
                UIView *view = (UIView*)[(ALTimelineCell*) obj cellView];
                CGRect frame = view.frame;
                CGPoint point = frame.origin;
                
                // do we need to centre on the timecode?
                
                BOOL centred = YES;
                if([obj respondsToSelector:@selector(centredOnTimecode)]) {
                    centred = [obj centredOnTimecode];
                }
                
                CGFloat x;
                if (centred) {
                    x = ((point.x + view.frame.size.width/2) * scaleFactor) - view.frame.size.width/2;
                } else {
                    x = (point.x * scaleFactor);
                }
                
                point.x = x;
                frame.origin = point;
                view.frame = frame;
                
                [obj updateCellView];
                
            }];
            
            previousScale = [gestureRecognizer scale];
            
            break;
        }
            
        case UIGestureRecognizerStateEnded: {
            
            [self setCurrentScale:newPointsPerFrame];
            
            // Move timeline to the correct postion and reload.
            
            ALFrame startingFrame = [self frameFromPoint:fabs(_timelineScrollView.contentOffset.x)]+zoomStart;
            NSInteger page = [self pageIndexForFrame:startingFrame];
            
            [_timelineScrollView setAllowRecentering:NO];
            
            [_timelineScrollView setActive:YES];
            [_timelineScrollView setPage:(page-1)];
            [_timelineScrollView layoutSubviews];
            
            // Just move the content ourselves.
            
            ALFrame frameDiff = startingFrame - [self framesForPageWithIndex:page].location;
            [_timelineScrollView setContentOffset:(CGPoint){[self pointFromFrame:frameDiff],0} animated:NO];
            
            [_timelineScrollView setAllowRecentering:YES];
        }
            
        default:
            [zoomViewBackground removeFromSuperview];
            zoomViewBackground = nil;
            
            [_zoomView removeFromSuperview];
            _zoomView = nil;
            _zoomRibbonView = nil;
            
            _isZooming = NO;
    }
}



- (UIView *)zoomViewForStart:(ALFrame)start end:(ALFrame)end {
    
    ALFrame wif = end - start;
    CGFloat width = [self pointFromFrame:wif];    // using the current scale
    CGFloat scrollViewHeight = _timelineScrollView.frame.size.height;
    
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0,width, scrollViewHeight)];
    view.clipsToBounds = YES;
    view.userInteractionEnabled = NO;
    
    // Add the timecode ribbon
    
    _zoomRibbonView = [[ALTimecodeRibbonView alloc] initWithFrame:CGRectMake(0, (scrollViewHeight-ktimecodeRibbonHeight), width, ktimecodeRibbonHeight)
                                                    startTimecode:[AVTimecode timecodeWithFramesFromZero:start]
                                                              end:[AVTimecode timecodeWithFramesFromZero:end]
                                            absoluteStartTimecode:_absoluteStartTimecode
                                                  highDetailLevel:YES];
    
    [view addSubview:_zoomRibbonView];
    
    // Add the cells
    
    _zoomContentCells =  [_dataSource contentCellsForStart:[_dataSource zoomStartTimecode] end:[_dataSource zoomEndTimecode]];
    
    NSRange frameRange = NSMakeRange(start, end-start);
    
    for (ALTimelineCell *cell in _zoomContentCells) {
        
        [self addCell:cell toView:view viewFrameRange:frameRange];
    }
    
    [view orderSubviewsWithTagNumber];
    
    return view;
}




/*************************************************************************************************************
 *
 *    ScrollView Handling - Scrolling
 *
 **************************************************************************************************************/


#pragma mark - ScrollView delegate Calls -


- (void)scrollViewDidScroll:(UIScrollView*)scrollView {
    
    if (!_userInControl) {
        
        // did the user scroll this?
        
        if (scrollView.tracking && !_scrollViewStartingAnimation) {
            
            // Yes they did, so force the user to be in control
            _userBecomingInControl = YES;
            _userInControl = YES;
            
            [_timelineScrollView.layer removeAllAnimations];
            
            [self animationLoop];
        }
    }
}




/*************************************************************************************************************
 *
 *   Gesture Recognisers
 *
 **************************************************************************************************************/


#pragma mark - Gesture Recognisers -

- (void)singleTapRecognised:(UIGestureRecognizer *)recogniser {
    
    // close all open cells
    
    NSDictionary *dict = @{@"Action":@"closeChild"};
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"ALTimelineCellsNeedsUpdate" object:dict];
    
}


- (void)doubleTapRecognised:(UIGestureRecognizer *)recogniser
{
    if (recogniser.state != UIGestureRecognizerStateRecognized) return;
    
    if (_userInControl) {
        
        _userInControl = NO;
        _scrollViewStartingAnimation = YES;
        
        [_timelineScrollView.layer removeAllAnimations];
        _currentScale = kdefaultPointsPerFrameRatio;
        
        if (_delegate && [_delegate respondsToSelector:@selector(timelineDidRecogniseDoubleTap:)])
            [_delegate timelineDidRecogniseDoubleTap:self];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            [self animationLoop];
            
            _scrollViewStartingAnimation = NO;
            
        });
        
    }
}




/* Handling rotation */

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
								duration:(NSTimeInterval)duration
{
    
    [_timelineScrollView willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
										 duration:(NSTimeInterval)duration
{
    
    [_timelineScrollView willAnimateRotationToInterfaceOrientation:interfaceOrientation
                                                          duration:duration];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        [_timelineScrollView reloadPages];
        
        [self animationLoop];
        //[self updateTimeCurser];
    });
}



- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    if([keyPath isEqualToString:@"_timeCurserView.frame"]) {
        
        CGRect oldFrame = CGRectNull;
        CGRect newFrame = CGRectNull;
        
        if(change[@"old"] != [NSNull null]) {
            oldFrame = [change[@"old"] CGRectValue];
        }
        
        if([object valueForKeyPath:keyPath] != [NSNull null]) {
            newFrame = [[object valueForKeyPath:keyPath] CGRectValue];
        }
        
        CGFloat diff = fabs(newFrame.origin.x-oldFrame.origin.x);
        
        if (diff>300) {
            
            // NSLog(@"timecurser difference %2f",diff);
        }
    }
}

@end
