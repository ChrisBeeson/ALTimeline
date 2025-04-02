//
//  NBInfiniteScrollView.m
//
//  Created by Chris Beeson on 01/04/14.
//  Copyright (c) 2012. All rights reserved.
//

#import "ALInfiniteScrollView.h"
#import "UIView+TagZOrder.h"

@interface ALInfiniteScrollView () {
    
    NSInteger  _min, _max;
    NSUInteger _count;
    
    UIView *_containerView;
    UIEdgeInsets _padding;
    
    UIDynamicItemBehavior *_dynamicBehavior;
    UIGravityBehavior *_gravity;
}

@end



@implementation ALInfiniteScrollView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self internalInit];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
    if ((self = [super initWithCoder:aDecoder])) {
        [self internalInit];
    }
    return self;
}

- (void)internalInit
{
    ddLogLevel = LOG_LEVEL_WARN;
    
    self.showsHorizontalScrollIndicator = NO;
    self.showsVerticalScrollIndicator = NO;
    self.pagingEnabled = NO;
    
    _infinite = NO;
    _count = 20000;
    _min = _max = 0;
    _padding = UIEdgeInsetsZero;
    _active = YES;
    _allowRecentering = YES;
    
    _visibleViews = [[NSMutableArray alloc] init];
    
    _containerView = [[UIView alloc] init];
    [self addSubview:_containerView];
    
    self.contentSize = CGSizeMake(kcontentWidth *2, self.bounds.size.height-ktimecodeRibbonHeight);
    _containerView.frame = CGRectMake(0, 0, self.contentSize.width, self.bounds.size.height-ktimecodeRibbonHeight);

    // Dynamics
    
    _enableDynamics = YES;
    _dynamicAnimator = [[UIDynamicAnimator alloc] initWithReferenceView:_containerView];

#ifdef GFX_DEBUG
    
    UIView *containerMarker = [[UIView alloc] init];
    containerMarker.frame = CGRectMake(0, 0, self.contentSize.width, 2);
    containerMarker.frame = CGRectMake(0, self.contentSize.height-2, self.contentSize.width, 2);
    containerMarker.backgroundColor = [UIColor greenColor];
    [_containerView addSubview:containerMarker];
    
#endif
}



/*************************************************************************************************************
 *
 *   Layout
 *
 **************************************************************************************************************/

#pragma mark - Layout -



- (void)recenterIfNecessary {

    if (_allowRecentering == NO) return;

    // Do not re-centre if there are any animations (bounds) active
    
    if ([self.layer.animationKeys count]>0 || _dynamicAnimator.running) {
        // NSLog(@"Tried to recentre but cancelled:%@",self.layer.animationKeys);
          return;
    }
    
    CGPoint currentOffset = [self contentOffset];
    CGFloat contentWidth = [self contentSize].width;
    CGFloat centerOffsetX = (contentWidth - [self bounds].size.width) / 2.0;
    CGFloat distanceFromCenter = fabs(currentOffset.x - centerOffsetX);
    
    if (distanceFromCenter > (contentWidth / 4.0)) {
        
        self.contentOffset = CGPointMake(centerOffsetX, currentOffset.y);
        
        // move content by the same amount so it appears to stay still
        
        for (UIView *view in [_containerView subviews]) {
            
            CGPoint center = [_containerView convertPoint:view.center toView:self];
            center.x += (centerOffsetX - currentOffset.x);
            view.center = [self convertPoint:center toView:_containerView];
        }
    }
}



- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (!_active) return;
    
    CGFloat extendBounds = 0.0;
    
    CGRect visibleBounds = [self convertRect:[self bounds] toView:_containerView];
    CGFloat minimumVisible = CGRectGetMinX(visibleBounds)-extendBounds;
    CGFloat maximumVisible = CGRectGetMaxX(visibleBounds)+extendBounds;
    
    [self tileViewsFromMin:minimumVisible toMax:maximumVisible];
    
    BOOL recentre = YES;
    
    if ([[_visibleViews firstObject] tag] == 0) recentre = NO;
    
    
    // Left bounce if first page is 0
    // if the first page is 0 then be need to move it so it fits at 0,0 of the containerView.
    
    if ([[_visibleViews firstObject] tag] == 1) {
        
        CGRect pageZeroFrame = [(UIView*)[_visibleViews firstObject] frame];
        CGFloat xMoveLeftOffset = pageZeroFrame.origin.x;
        
        //  move everything to the left
        
        for (UIView *view in [_containerView subviews]) {
            
            CGPoint newOrgin = view.frame.origin;
            
            newOrgin.x = newOrgin.x - xMoveLeftOffset ;
            
            CGRect rect = view.frame;
            rect.origin = newOrgin;
            view.frame = rect;
        }
        
        self.contentOffset = CGPointMake(self.contentOffset.x - xMoveLeftOffset, self.contentOffset.y);
        
        recentre = NO;
    }
    
    
    // do we have the last page?
    // if so wrap the end of containerview around it
    
    NSUInteger maxPage = [_datasource numberOfPagesForScrollView:self];
    
    DDLogVerbose(@"Visible views last tag:%li max page:%lu",(long)[[_visibleViews lastObject] tag],(unsigned long)maxPage);
    
    if ([[_visibleViews lastObject] tag] == maxPage) {
        
        CGRect lastViewFrame = [(UIView*)[_visibleViews lastObject] frame];
        CGRect frame = _containerView.frame;
        
        frame.size = (CGSize) {lastViewFrame.origin.x+lastViewFrame.size.width,lastViewFrame.size.height};
        
        _containerView.frame = frame;
        self.contentSize = _containerView.frame.size;
        
        recentre = NO;
        
    } else {
        
        self.contentSize = CGSizeMake(kcontentWidth *2, self.bounds.size.height-50);
        _containerView.frame = CGRectMake(0, 0, self.contentSize.width, self.bounds.size.height-50);
    }
    
    if ([[_visibleViews lastObject] tag] > maxPage) recentre = NO;
    
    if (recentre) [self recenterIfNecessary];
    
    [self.datasource infiniteScrollViewdidFinishLayingOutSubviews:self];
}




/*************************************************************************************************************
 *
 *   View Tiling
 *
 **************************************************************************************************************/

#pragma mark - View Tiling -


- (void)tileViewsFromMin:(CGFloat)minimumVisible toMax:(CGFloat)maximumVisible
{
    // the upcoming tiling logic depends on there already being at least one view in the visibleViews array, so
    // to kick off the tiling we need to make sure there's at least one view
    
    if ([_visibleViews count] == 0) {
        
        [self placeNewViewOnRight:minimumVisible withIndex:(++_max > _count-1 ? (_max=0) : _max)];
    }
    
    // add views that are missing on right side
    
    UIView *lastView = [_visibleViews lastObject];
    CGFloat rightEdge = (CGRectGetMaxX([lastView frame]) + _padding.right);
    
    while (rightEdge < maximumVisible) {
        
        NSUInteger newIndex = (++_max > _count-1 ? (_max=0) : _max);
        
        DDLogVerbose(@"Placing new View on Right with index:%lu",(unsigned long)newIndex);
        
        rightEdge = [self placeNewViewOnRight:rightEdge withIndex:newIndex];
    }
    
    // add views that are missing on left side
    
    UIView *firstView = _visibleViews[0];
    
    CGFloat leftEdge = (CGRectGetMinX([firstView frame]) - _padding.left);
    
    while (leftEdge > minimumVisible) {
        
        NSUInteger newIndex = (_min < 0 ? (_min=_count-1) : _min--);
        leftEdge = [self placeNewViewOnLeft:leftEdge withIndex:newIndex];
        
        DDLogVerbose(@"Placing new View on Left with index:%lu",(unsigned long)newIndex);
    }
    
    // remove views that have fallen off right edge
    
    lastView = [_visibleViews lastObject];
    
    while ([lastView frame].origin.x > maximumVisible) {
        
        if (--_max < 0) _max = _count-1;
        
        [_datasource infiniteScrollView:self willRemoveIndex:[[_visibleViews lastObject] tag]];
        
        // remove views within the view rect
        
        [self removeViewsInRect:lastView.frame];
        
        [lastView removeFromSuperview];
        [_visibleViews removeLastObject];
        lastView = [_visibleViews lastObject];
    }
    
    // remove views that have fallen off left edge
    
    firstView = _visibleViews[0];
    
    while (CGRectGetMaxX([firstView frame]) < minimumVisible-100) {
        
        if (++_min > _count-1) _min=0;
        
        [_datasource infiniteScrollView:self willRemoveIndex:[_visibleViews[0] tag]];
        
        [self removeViewsInRect:firstView.frame];
        
        [firstView removeFromSuperview];
        [_visibleViews removeObjectAtIndex:0];
        firstView = _visibleViews[0];
    }
}



- (UIView *)insertView:(NSUInteger)index origin:(CGPoint)origin {
    
    UIView *v;
    
    if (_viewForIndex) {
        
        // Is there a block call?
        v = _viewForIndex(index);
        
    } else if (_datasource && [_datasource respondsToSelector:@selector(infiniteScrollView:viewForIndex:)]) {
        
        v = [_datasource infiniteScrollView:self viewForIndex:index];
    }
    
    
    if (!v) {      // The view is null so make a place holder
        
        
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 180, 80)];
        [label setNumberOfLines:1];
        [label setText:[NSString stringWithFormat:@"%lu", (unsigned long)index]];
        v = label;
    }
    
    // Set the frame of the view
    
    CGRect frame = [v frame];
    frame.origin = origin;
    [v setFrame:frame];
    v.tag = index;
    v.userInteractionEnabled = NO;
    
    [_containerView addSubview:v];
    
    // Now move all subviews of
    
    [self copyAllSubviews:[v subviews] recursive:NO];
    
    if(_datasource && [_datasource respondsToSelector:@selector(infiniteScrollView:didFinishAddingViewsToPage:)])
        [_datasource infiniteScrollView:self didFinishAddingViewsToPage:index];
    
    return v;
}



-(void) copyAllSubviews:(NSArray*)subviews recursive:(BOOL)recursive {
    
    // copy views to the container view
    
    [subviews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        
        UIView *viewObj = obj;
        CGRect frame = [viewObj frame];

        frame.origin = [viewObj.superview convertPoint:frame.origin toView:_containerView];
        [viewObj setFrame:frame];
        
        [_containerView addSubview:viewObj];
    }];

    [_containerView orderSubviewsWithTagNumber];
}


- (CGFloat)placeNewViewOnRight:(CGFloat)rightEdge withIndex:(NSUInteger)index{
    
    CGPoint origin;
    
    origin.x = rightEdge + _padding.left;
    // frame.origin.y = (([_containerView bounds].size.height - frame.size.height - _padding.top - _padding.bottom)/2.0) + _padding.top;
    
    origin.y =0;
    
    UIView *view = [self insertView:index origin:origin];
    
    // add rightmost view at the end of the array
    
    [_visibleViews addObject:view]; // We just add the one main view
    
    return  (CGRectGetMaxX([view frame]) + _padding.right);
}



- (CGFloat)placeNewViewOnLeft:(CGFloat)leftEdge withIndex:(NSUInteger)index {
    
    CGPoint origin;
    
    CGFloat contentWidth = [self viewWidthForIndex:index];
    
    origin.x = leftEdge - contentWidth - _padding.right;
    origin.y =0;
    
    UIView *view = [self insertView:index origin:origin];
    
    // add leftmost view at the beginning of the array
    
    [_visibleViews insertObject:view atIndex:0];
    
    return (CGRectGetMinX([view frame]) - _padding.left);
}


- (CGFloat)viewWidthForIndex:(NSUInteger)indx {
    
    if (_datasource && [_datasource respondsToSelector:@selector(infiniteScrollView:expectedWidthForPage:)]) {
        
        return [_datasource infiniteScrollView:self expectedWidthForPage:indx];
        
    } else {
        NSLog(@"%s Datasource not available",__PRETTY_FUNCTION__);
        return kcontentWidth;
    }
}


- (void)removeViewsInRect:(CGRect)rect {
    
    for (UIView *aView in [_containerView subviews]) {
        
        if(CGRectContainsRect(rect,aView.frame) && (aView.tag !=1000)) {
            
            {
                [aView removeFromSuperview];
            }
        }
    }
}



/*************************************************************************************************************
 *
 *   Functions
 *
 **************************************************************************************************************/

#pragma mark - Functions -


-(void) reloadPages {
    
    for (int i=0; i<[_visibleViews count]; i++) {
        
        // Get view for index
        
        UIView *view = [self insertView:[_visibleViews[i]tag] origin:[(UIView*)_visibleViews[i] frame].origin];
        view.frame = [(UIView*)_visibleViews[i] frame];
        [_visibleViews[i] removeFromSuperview];
        _visibleViews[i] = view;
    }
}


-(void) setPage:(NSInteger)index {
    
    if (index<0) index = 0;
    
    // TODO: Protect against larger pagenumber than absolute endtimecode
    
    [self hardReset];
    
    _min = _max = index;
    
    //[self setNeedsLayout];
}


-(NSInteger) currentVisiblePage {
    
    if ([_visibleViews count]>2) {
        return [_visibleViews[1] tag];
        
    }
    
    if (_visibleViews && [_visibleViews count]>0) {
        
        return [_visibleViews[0] tag];
        
    } else {
        return NSNotFound;
    }
}


- (void)hardReset {
    
    if (_visibleViews) [_visibleViews removeAllObjects];
    
    [[_containerView subviews] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        
        [obj removeFromSuperview];
    }];
    
    _min = _max = 0;
    
    self.contentOffset = (CGPoint){0,0};
    
    [self setNeedsLayout];
}


- (void)addSubview:(UIView*)view toIndexPage:(NSUInteger)index {
    
    // Is the index page in _visible views
    
    __block UIView *v = view;
    
    [_visibleViews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {

        if (([obj tag]) == index) {
            
            if (v) {
               [obj addSubview:v];
            }
        
            [self copyAllSubviews:[obj subviews] recursive:NO];
        
            *stop = YES;
        }
    }];
    
    [_containerView orderSubviewsWithTagNumber];
    
    if ([_datasource respondsToSelector:@selector(infiniteScrollView:didFinishAddingViewsToPage:)])
        [_datasource infiniteScrollView:self didFinishAddingViewsToPage:index];
}


-(UIView *) viewForIndexPage:(NSUInteger)index {
    
    __block UIView *v;
    
    [_visibleViews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        
        if (([obj tag]) == index) {
            
            v = obj;
            *stop = YES;
        }
    }];
 
    return v;
}

- (void)contentDidChangeOnIndexPage:(NSUInteger)index {
    
    [self addSubview:nil toIndexPage:index];
    
}


/*************************************************************************************************************
 *
 *   Debug Helpers
 *
 **************************************************************************************************************/

#pragma mark - Debug helpers -


-(void) visibleViewsDump {
    
    if ([_visibleViews count] ==0) {
        return;
    }
    
    NSMutableString *string =[[NSMutableString alloc] initWithFormat:@"Array Count:%lu - ",(unsigned long)[_visibleViews count]];
    
    for (int i=0; i<=[_visibleViews count]-1; i++) {
        
        [string appendFormat:@"%li ",(long)[_visibleViews[i] tag]];
    }
}



-(BOOL) viewOrderValid {
    
    if ([_visibleViews count] <2) return YES;
    
    for (int i=0; i<=[_visibleViews count]-1; i++) {
        
        if ([_visibleViews[i+1] tag] != [_visibleViews[i] tag]+1) {
            NSLog(@"Pages Wrong: visibleViews: %lu  index %i tag:%li  +1Tag:%li",(unsigned long)[_visibleViews count],i,(long)[_visibleViews[i+1] tag],(long)[_visibleViews[i] tag]);
            
            NSAssert(nil,@"Invalid Page order");
        }
        
        return NO;
    }
    return YES;
}



- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
								duration:(NSTimeInterval)duration {
	//currentPage = scrollView.contentOffset.x / scrollView.bounds.size.width;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
										 duration:(NSTimeInterval)duration {
	//[self alignSubviews];
	//scrollView.contentOffset = CGPointMake(currentPage * scrollView.bounds.size.width, 0);
    
}

@end
