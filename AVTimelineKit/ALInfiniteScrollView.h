//
//  NBInfiniteScrollView.h
//
//  Created by Chris Beeson.
//  Copyright (c) 2014. All rights reserved.
//

// #define GFX_DEBUG

 #import <UIKit/UIKit.h>

@protocol NBInfiniteScrollDataSource <NSObject>

- (UIView *)infiniteScrollView:(id)scrollView viewForIndex:(NSUInteger)index;
- (NSUInteger)numberOfPagesForScrollView:(id)scrollView;
- (CGFloat)infiniteScrollView:(id)scrollView expectedWidthForPage:(NSUInteger)index;

// These are delegate calls

@optional
- (void)infiniteScrollView:(id)scrollView didFinishAddingViewsToPage:(NSUInteger)index;
- (void)infiniteScrollView:(id)scrollView willRemoveIndex:(NSUInteger)index;
- (void)infiniteScrollViewdidFinishLayingOutSubviews:(id)scrollView;
@end




// Interface

@interface ALInfiniteScrollView : UIScrollView <UIScrollViewDelegate> {
    
}

@property (nonatomic,readonly) NSMutableArray *visibleViews;        // This really shouldn't be public...
@property (nonatomic,readonly) UIDynamicAnimator *dynamicAnimator;

@property (nonatomic) id <NBInfiniteScrollDataSource> datasource;
@property (nonatomic,copy) UIView *(^viewForIndex)(NSUInteger index);

@property (nonatomic) BOOL enableDynamics;
@property (nonatomic) BOOL infinite;  // Default NO = max and min are end pages.
@property (nonatomic) BOOL active;
@property (nonatomic) BOOL allowRecentering;


- (void)setPage:(NSInteger)index;
@property (NS_NONATOMIC_IOSONLY, readonly) NSInteger currentVisiblePage;

- (void)addSubview:(UIView*)view toIndexPage:(NSUInteger)index;

- (UIView *)viewForIndexPage:(NSUInteger)index;
- (void)contentDidChangeOnIndexPage:(NSUInteger)index;

- (void)reloadPages;
- (void)hardReset;   // deletes all views, resets current page to 0



// Rotation

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
								duration:(NSTimeInterval)duration;


- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
                                         duration:(NSTimeInterval)duration;

@end

