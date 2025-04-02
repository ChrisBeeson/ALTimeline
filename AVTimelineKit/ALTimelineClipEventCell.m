//
//  ALTimelineClipEventCell.m
//  ActionLog
//
//  Created by Chris Beeson on 27/03/2014.
//  Copyright (c) 2014 Chris Beeson. All rights reserved.
//

#import "ALTimelineClipEventCell.h"
#import "ALClipEvent.h"
#import "ALPalette.h"
#import "ALShapeView.h"
#import "ALTimelineDeviceInfoCell.h"
#import "ALTake.h"
#import "ALClipEventDetailFormViewController.h"


@interface ALTimelineClipEventCell () {
    
    UIView *_durationView;
    UIView *_cropContainerView;
    UIView *_clipView;
    ALShapeView *_starIcon;
    
    UILabel *_sceneLabel;
    UILabel *_takeLabel;
    UILabel *_shotLabel;
    UILabel *_activeLoggingLabel;
    
    UILongPressGestureRecognizer *_longPressGesture;
    
    BOOL _allowLongPressGesture;
}
@end


@implementation ALTimelineClipEventCell

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        _timeline = [[ALManager manager] timeline];
        _forceWidth = NSNotFound;
        _cropFrontFrames = NSNotFound;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateCellView)
                                                     name:@"ALUpdateClipEventCell" object:nil];
        
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(timelineDidLayoutSubviews)
                                                     name:@"ALTimelineViewDidLayoutSubviews" object:nil];
        
       
        // [self addObserver:self forKeyPath:@"view.frame" options:NSKeyValueObservingOptionOld context:NULL];
        
        _longPressGesture = [[UILongPressGestureRecognizer alloc] init];
        [_longPressGesture addTarget:self action:@selector(longPressGesture:)];
        _allowLongPressGesture = YES;
        
        _colour = [ALPalette systemLightBlue];
        _cannotAnimate = NO;
        

    }
    
    return self;
}


-(void) setEvent:(ALEvent *)event{
    
    if (event) {
        
        [self removeAllObservationsOfObject:self.event];
        
        [super setEvent:event];

        [self observeObject:self.event property:@"take" withBlock:^(__weak id self, __weak id object, id old, id new){
            [self updateTakeLabels];
            
        }];
        
         [self observeObject:[(ALClipEvent*)[self event] take] property:@"starred" withBlock:^(__weak id self, __weak id object, id old, id new){
            [self updateStarredIcon];
        }];
    }
}

- (UIView *)cellView
{
    if (!_clipView) {
        
        // Need to calc height of view
        CGSize size = [_timeline maxCellSize];
        CGFloat maxHeight = size.height * HEIGHT_PERCENTAGE;
        _clipView = [[UIView alloc] initWithFrame:(CGRect){0,0,1,maxHeight}];
        [_clipView addGestureRecognizer:_longPressGesture];
        
        _clipView.backgroundColor = _colour;
        
#ifdef GFX_DEBUG
        _clipView.alpha = 0.5;
#endif
        _clipView.clipsToBounds = YES;
        
        
        UIView * header = [[UIView alloc] initWithFrame:(CGRect){0,0,0.5,800}];
        header.backgroundColor = [ALPalette systemBlue];
        header.alpha = 1.0;
        //[_clipView addSubview:header];
        
        CGFloat vSpace = 12;
        
        // Labels
        
        _sceneLabel = [[UILabel alloc] initWithFrame:CGRectMake(2, 17, 35, 15)];
        _sceneLabel.clipsToBounds = NO;
        _sceneLabel.textAlignment = NSTextAlignmentLeft;
        _sceneLabel.textColor =[UIColor whiteColor];
        _sceneLabel.font =[UIFont systemFontOfSize:12];
        _sceneLabel.tag = 1;
        [_clipView addSubview:_sceneLabel];
        
        _shotLabel = [[UILabel alloc] initWithFrame:CGRectMake(2, 17+vSpace, 35, 15)];
        _shotLabel.clipsToBounds = NO;
        _shotLabel.textAlignment = NSTextAlignmentLeft;
        _shotLabel.textColor =[UIColor whiteColor];
        _shotLabel.font =[UIFont systemFontOfSize:12];
        _shotLabel.tag = 1;
        [_clipView addSubview:_shotLabel];
        
        _takeLabel = [[UILabel alloc] initWithFrame:CGRectMake(2, 17+vSpace*2, 35, 15)];
        _takeLabel.clipsToBounds = NO;
        _takeLabel.textAlignment = NSTextAlignmentLeft;
        _takeLabel.textColor =[UIColor whiteColor];
        _takeLabel.font =[UIFont systemFontOfSize:12];
        _takeLabel.tag = 1;
        [_clipView addSubview:_takeLabel];
        
        [self updateTakeLabels];
        
        
        // Add present TC button
        
        ALShapeView * view = [[ALShapeView alloc] initWithFrame:(CGRect){1,1,15,15}];
        view.shape = ALShapeTypeClipStart;
        view.colour = [ALPalette systemBlue];
        [view addGestureRecognizer:self.tapGestureRecogniser];
        
        [_clipView addSubview:view];
        
        // Put in all in a container so it can be cropped
        
        _cropContainerView = [[UIView alloc] initWithFrame:_clipView.frame];
        _cropContainerView.clipsToBounds = YES;
        [_cropContainerView addSubview:_clipView];
        
        [self setupChildCells];
        
        self.view = _cropContainerView;
    }
    
    self.view.tag = 1;
    
    return self.view;
}


-(void) handleScrollViewWillRecentre {
    
    if([(ALClipEvent*)self.event isLoggingValue] == YES) {
        
        // cancel all animations
        
        [_cropContainerView.layer removeAllAnimations];
        [_clipView.layer removeAllAnimations];
    }
}


- (void)timelineDidLayoutSubviews {
    
    if([(ALClipEvent*)self.event isLoggingValue] == YES) {
        
        [self updateCellView];
    }
}

- (void)updateCellView {
    
    [super updateCellView];
    
    ddLogLevel = LOG_LEVEL_WARN;
    
    BOOL logging = [(ALClipEvent*)self.event isLoggingValue];
    
     _clipView.backgroundColor = _colour;
    
    [_cropContainerView.layer removeAllAnimations];
    [_clipView.layer removeAllAnimations];

    // Height
    CGSize size = [_timeline maxCellSize];
    CGFloat maxHeight = size.height *HEIGHT_PERCENTAGE;
    
    
    // Width
   ALFrame startframe = [[AVTimecode timecodeWithDate:self.event.timestamp] framesFromZero];
   ALFrame endframe;
    
    if (logging) {
        
        // If logging use the current date for the end frame
        
        endframe =  [[AVTimecode timecodeWithDate:[[ALManager manager] currentDate]] framesFromZero];
    }
    
    else {
        
        endframe = [[AVTimecode timecodeWithDate:[(ALClipEvent*)self.event endTimestamp]] framesFromZero];
    }
    
    ALFrame duration = endframe-startframe;
    CGFloat widthNow = [_timeline pointFromFrame:duration];
    
    // If we are cropping then we need to offset the clipView by that amount (move to left)
    
    CGFloat cropContentOffset = 0.0;
    CGFloat cropWidth = widthNow;
    
    if (_cropFrontFrames != NSNotFound) {
        
        CGFloat amount = [[[ALManager manager] timeline] pointFromFrame:_cropFrontFrames];
        cropContentOffset = 0.0 - amount;
        cropWidth = widthNow - amount;
    }
    
    
    // New rect for the clipView
    
    _clipView.frame = (CGRect){cropContentOffset,0,widthNow,maxHeight};
    
    
    // is the width being forced?  If so just change width on container
    
    if (_forceWidth != NSNotFound)
        cropWidth  = [_timeline pointFromFrame:_forceWidth];
    
    _cropContainerView.frame = (CGRect){self.view.frame.origin.x,self.view.frame.origin.y,cropWidth,maxHeight};
    
    // Animation
    
    if (logging == YES && _cannotAnimate == NO) {
        
        // When logging display a timer outside of the cropContainer
        
        if (!_activeLoggingLabel) {
            
            _activeLoggingLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, self.view.frame.origin.y+maxHeight/2, 65, 15)];
            _activeLoggingLabel.textAlignment = NSTextAlignmentLeft;
            _activeLoggingLabel.textColor =[UIColor darkGrayColor];
            _activeLoggingLabel.font =[UIFont boldSystemFontOfSize:12];
            _activeLoggingLabel.hidden = NO;
            _activeLoggingLabel.tag = 100;
            
            [[_timeline.timeCurserView viewWithTag:100] removeFromSuperview];  // there could be a label already added to the timecurser
            [_timeline.timeCurserView  addSubview:_activeLoggingLabel];
            
            [self updateLabels];
        }
        
        CGFloat newWidth = _clipView.frame.size.width+[_timeline pointFromFrame:ANIM_LOOP_DURATION*25];
        CGRect clipNewRect = (CGRect){cropContentOffset,0,newWidth,maxHeight};
        CGRect cropNewRect = (CGRect){self.view.frame.origin.x,self.view.frame.origin.y,newWidth,maxHeight};
        
        __weak id weakSelf = self;
        
        [UIView animateWithDuration:ANIM_LOOP_DURATION  delay:0.0
                            options:UIViewAnimationOptionCurveLinear|UIViewAnimationOptionAllowUserInteraction
                         animations:^{
                             
                             _cropContainerView.frame = cropNewRect;
                             _clipView.frame = clipNewRect;
                         }
         
                         completion:^(BOOL completed){
                             
                             if  (completed)
                                  [weakSelf updateCellView];
                             
                         }];
    } else {
        
        // we're not logging - hide label
        
        if (_activeLoggingLabel && !_activeLoggingLabel.hidden)
            [_activeLoggingLabel removeFromSuperview];
        
        // As we're not logging we can add the starred view - if it's required
        
        [self updateStarredIcon];
        
    }
}

-(void) updateStarredIcon {
    
    ALClipEvent *event = (ALClipEvent*)self.event;
    
    ALTake *take = [event take];
    
    if (take.starredValue) {
    
    if (_clipView && !_starIcon) {
    
        _starIcon = [[ALShapeView alloc] initWithFrame:(CGRect){0,0,20,20}];
        _starIcon.shape = ALShapeTypeStar;
        //_starIcon.colour = [ALPalette colourForIndex:[self.event colourValue]];
        _starIcon.colour = [ALPalette systemBlue];
        self.view.clipsToBounds = NO;
        [self.view addSubview:_starIcon];
    }
        _starIcon.frame = (CGRect) {(_cropContainerView.frame.size.width/2)-10,-25 ,20,20};
        
    } else {
        
        // We're not starred
        
        if (_starIcon) {
            
            [_starIcon removeFromSuperview];
            _starIcon = nil;
        }
    }
}


- (void)updateTakeLabels {
    
    ALTakePath path = [[(ALClipEvent*)[self event] take] takePath];
    
    _sceneLabel.text = [@(path.scene) stringValue];
    _shotLabel.text = [@(path.shot) stringValue];
    _takeLabel.text = [@(path.take) stringValue];
}

- (void)updateLabels {
    
    _activeLoggingLabel.text = [(ALClipEvent*)self.event formattedDuration];
    
    if ([self isKindOfClass:[ALTimelineClipEventCell class]] && [(ALClipEvent*)self.event isLoggingValue]) {
        
        __weak id weakSelf = self;
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf updateLabels]; });
    }
}

-(void) setupChildCells {
    
    ALTimelineDeviceInfoCell *deviceInfoCell = [[ALTimelineDeviceInfoCell alloc] init];
    deviceInfoCell.childSpawnPostion = ALTimelineCellSpawnPostionLeft;
    [deviceInfoCell setEvent:self.event];
    deviceInfoCell.childSpawnPositionOffset = UIOffsetMake(-80, 30);
    
    self.childSpawnPostion = ALTimelineCellSpawnPostionLeft;
    self.childSpawnPositionOffset = UIOffsetMake(15, 0);
    [self setChild:deviceInfoCell];
    
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {

    if([keyPath isEqualToString:@"view.frame"]) {
        
        CGRect oldFrame = CGRectNull;
        CGRect newFrame = CGRectNull;
        
        if(change[@"old"] != [NSNull null]) {
            oldFrame = [change[@"old"] CGRectValue];
        }
        
        if([object valueForKeyPath:keyPath] != [NSNull null]) {
            newFrame = [[object valueForKeyPath:keyPath] CGRectValue];
        }
        
        //      NSLog(@"frame changed width:%2f",newFrame.size.width);
        
        CGFloat diff = fabs(newFrame.origin.x-oldFrame.origin.x);
        
        if (diff>300) {
            
             NSLog(@"clip view difference %2f",diff);
        }
    }
}


- (BOOL)centredOnTimecode {
    
    return NO;
}


-(void) longPressGesture:(UILongPressGestureRecognizer *)gesture
{
    if (_allowLongPressGesture) {

        [ALClipEventDetailFormViewController presentFormSheetWithTake:[(ALClipEvent*)self.event take]];
        
        _allowLongPressGesture = NO;
    }
    
    // this is a bit of a fudge, but seems to be ok
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        _allowLongPressGesture = YES;
    });
}


- (NSArray*)gestureRecognisers {
    
    return @[_longPressGesture];
}


-(void) dealloc {
    
     [[NSNotificationCenter defaultCenter] removeAllObservations];
     [self removeAllObservations];
    [_clipView removeGestureRecognizer:_longPressGesture];
}

@end
