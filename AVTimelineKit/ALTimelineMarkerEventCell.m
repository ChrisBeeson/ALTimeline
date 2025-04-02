//
//  ALMarkerEventCell.m
//  ActionLog
//
//  Created by Chris Beeson on 23/01/2014.
//  Copyright (c) 2014 Chris Beeson. All rights reserved.
//

#import "ALTimelineMarkerEventCell.h"
#import "ALShapeView.h"
#import "ALMarkerEvent.h"
#import "ALMarkerCommandViewController.h"
#import "ALTimelineLabelCell.h"
#import "ALTimelineDeviceInfoCell.h"
#import "ALAwesomeButton.h"
#import "MTKObservingMacros.h"

@interface ALTimelineMarkerEventCell () {
    
    BOOL starredPreviousValue;
    
    UILongPressGestureRecognizer *_longPressGesture;
    
    BOOL _allowLongPressGesture;
}
@end

@implementation ALTimelineMarkerEventCell

- (instancetype)init
{
    self = [super init];
    if (self) {
        // Watch for changes to the event Title
        
        [self observeProperty:@keypath(self.event.title) withBlock:^(__weak id self, id old, id new) {
           
            if ([self event]) {
                [[self root] closeChild];
                [self destroyChild];
                [self setupChildCells];
            }
        }];
    }
    return self;
}

- (UIView *)cellView {
    
    if (!self.view) {
        
        starredPreviousValue = NO;
        
        self.view = [[ALShapeView alloc] initWithFrame:CGRectMake(0, 0, 50, 50)];
        self.view.backgroundColor = [UIColor clearColor];
        self.view.clipsToBounds = NO;
        self.view.userInteractionEnabled = YES;
        self.view.tag = 2; // FG
        [self.view addGestureRecognizer:self.tapGestureRecogniser];
        
        _longPressGesture = [[UILongPressGestureRecognizer alloc] init];
        [_longPressGesture addTarget:self action:@selector(longPressGesture:)];
        _allowLongPressGesture = YES;
        [self.view addGestureRecognizer:_longPressGesture];
        
        // Child Views
        [self setupChildCells];
        
        [self updateCellView];
    }
    
    return self.view;
}

-(void)updateCellView {
    
    [super updateCellView];
    
    // set the colour
    
    self.view.colour = [ALPalette colourForIndex:[(ALMarkerEvent *)self.event colourValue]];
    
    // set the shape
    
    if ([(ALMarkerEvent*)[self event] starredValue] ) {
        
        self.view.shape = ALShapeTypeStar;
        
        // Do little animation if this is a state change to ON
        
        if (starredPreviousValue == NO && self.canAnimate) {
            
            ALShapeView *starAnimView = [[ALShapeView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height) shape:ALShapeTypeStar colour:self.view.colour];
            starAnimView.alpha = 0.8;
            
            [self.view addSubview:starAnimView];
            
            [UIView animateWithDuration:0.5  delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
                
                starAnimView.frame = CGRectMake(0-starAnimView.frame.size.width,0-starAnimView.frame.size.height, starAnimView.frame.size.width*3, starAnimView.frame.size.height*3);
                
                starAnimView.alpha = 0.0;
                
            } completion:^(BOOL done){
                
                [starAnimView removeFromSuperview];
            }];
        }
        
        starredPreviousValue = YES;
        
    } else {
        
        self.view.shape = ALShapeTypeOval;
        starredPreviousValue = NO;
    }
    
    [self.view setNeedsDisplay];
}


-(void) setupChildCells {
    
    [self setRoot:self];
    
    // Prepare to re-open children later
    //  NSInteger level = [self.root highestOpenChild];
    
    // device Timecode cell
    
    self.childSpawnPositionOffset =  UIOffsetMake(-5, 0);
    
    ALTimelineDeviceInfoCell *deviceInfoCell = [[ALTimelineDeviceInfoCell alloc] init];
    deviceInfoCell.childSpawnPositionOffset = UIOffsetMake(5, 0);
    [deviceInfoCell setEvent:self.event];
    
    if ([self.event.title length]>0) {
        
        deviceInfoCell.childSpawnPositionOffset = UIOffsetMake(0, 0);
        
        // Add textLabelCell
        
        ALTimelineLabelCell *labelCell = [[ALTimelineLabelCell alloc] init];
        labelCell.childSpawnPositionOffset = UIOffsetMake(-5, -5);
        [labelCell setEvent:self.event];
        
        [labelCell setChild:deviceInfoCell];
        [self setChild:labelCell];
        
    } else {
        
        [self setChild:deviceInfoCell];
    }
    
    //  [[self root] openChildrenToLevel:level];
}


-(void) eventTitleDidChangeProperty {
    
    if (self.event.title) {
        [[self root] closeChild];
        [self destroyChild];
        [self setupChildCells];
    }
}



/*
 
 -(UIButton *) optionButton {
 
 ALAwesomeButton *button = [[ALAwesomeButton alloc] initWithFrame:(CGRect){0,0,25,25}];
 
 [button setTouchBlock:^(ALAwesomeButton *awesomeButton){
 
 [ALMarkerCommandViewController presentFormSheetWithEvent:(ALMarkerEvent *)self.event];
 
 }];
 
 return button;
 
 }
 */

-(void) longPressGesture:(UILongPressGestureRecognizer *)gesture
{
    if (_allowLongPressGesture) {
        
        [ALMarkerCommandViewController presentFormSheetWithEvent:(ALMarkerEvent *)self.event];
        
        _allowLongPressGesture = NO;
        
    }
    
    // this is a bit of a fudge, but seems to be ok
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        _allowLongPressGesture = YES;
    });
}

- (CGFloat)bottomVerticalPadding {
    return 3.0;
}

-(void) dealloc {
    
    [self removeAllObservations];
    
}

@end
