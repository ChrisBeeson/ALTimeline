//
//  ALTimecodeRibbonView.m
//  ActionLog
//
//  Created by Chris Beeson on 18/04/2014.
//  Copyright (c) 2014 Chris Beeson. All rights reserved.
//

#import "ALTimecodeRibbonView.h"
#import "AVTimecode.h"

#define MIN_TICK_GAP 150.0

@interface ALTimecodeRibbonView () {
    
    CGFloat _pointsPerFrame;
    int _indx;
    AVTimecode *_absoluteStart;
    BOOL _highDetail;
}

@end


@implementation ALTimecodeRibbonView

- (instancetype)initWithFrame:(CGRect)frame startTimecode:(AVTimecode *)startTimecode
                                            end:(AVTimecode*)endTimecode
                          absoluteStartTimecode:(AVTimecode*)absoluteStartTimecode
                                highDetailLevel:(BOOL)detailLevel {
    
    self = [super initWithFrame:frame];
    
    if (self) {
        
        _startTimecode = startTimecode;
        _endTimecode = endTimecode;
        _absoluteStart = absoluteStartTimecode;
        _highDetail = detailLevel;
        _autoUpdate = NO;
        
        self.backgroundColor = [UIColor clearColor];
    }
    return self;
}

/*
-(void) setAutoUpdate:(BOOL)autoUpdate  {
   
    if (autoUpdate) {
    
        // we need to watch changes in the frame, and then redraw if the timecode labels overlap.
        
        [self observeProperty:@keypath(self.frame) withBlock:^(__weak id self, id old, id new) {
            
        }];
    }
}
*/

-(UIView *)ribbonView {
    /*
    UIView *view = [[UIView alloc] initWithFrame:self.frame];
    view.backgroundColor = [UIColor clearColor];
    view.clipsToBounds = NO;
    */
    return [self plotRibbonOnView:self detail:_highDetail];
    
}



- (UIView*)plotRibbonOnView:(UIView *)view detail:(BOOL)detail {
    
    ddLogLevel = LOG_LEVEL_WARN;
    
    // Views
    
    UIView *greyseperatorline = [[UIView alloc] initWithFrame:CGRectMake(0, 0, view.frame.size.width, 1)];
    greyseperatorline.backgroundColor = [UIColor lightGrayColor];
    greyseperatorline.tag = 90;
    [view addSubview:greyseperatorline];
    
    // calc scale
    
    ALFrame pageStartFrame =[_startTimecode framesFromZero];
    ALFrame pageEndFrame = [_endTimecode framesFromZero];
    ALFrame range = pageEndFrame - pageStartFrame;
    _pointsPerFrame = view.frame.size.width/range;
    
    // Calc how many major ticks & gap between them
    
    NSInteger majorTickCount = view.frame.size.width/MIN_TICK_GAP;
    
    CGFloat pointsBetweenTicks = view.frame.size.width / majorTickCount;
    ALFrame framesBetweenMajorTicks = [self frameFromPoint:pointsBetweenTicks];
    
    framesBetweenMajorTicks += [[AVTimecode timecodeWithFramesFromZero:framesBetweenMajorTicks] framesToNextRoundThirtySeconds];
    framesBetweenMajorTicks -= (30*kframeRate);

    if (framesBetweenMajorTicks <10)
        framesBetweenMajorTicks = (30*kframeRate);
    
    // Using absoluteStart as a base, lets work out the first tick for this page.
    
    ALFrame absoluteStartTimeRounded = [_absoluteStart framesFromZero]+[_absoluteStart framesToNextRoundThirtySeconds]-(30*kframeRate);
    
    // Whats the index of this view
    
    ALFrame framesFromAbsStart = pageStartFrame - [_absoluteStart framesFromZero];
    ALFrame index = (range>0) ? round(framesFromAbsStart/range) : 0;
    
    // Handle pages that come before absolute start
    /*
    if (framesFromAbsStart<0) {
        framesFromAbsStart = absoluteStartTimeRounded - range;
        index =0;
    }
    */
    // First tick for this page
    
    ALFrame spawnFrame = absoluteStartTimeRounded+roundf(((index)*(majorTickCount*framesBetweenMajorTicks)));
    
    // Adjust spawn frame if required.
    
    if (spawnFrame<(pageStartFrame-(framesBetweenMajorTicks))) {
        
        ALFrame diff = pageStartFrame-spawnFrame;
        
        if (framesBetweenMajorTicks>0) {
            
        NSUInteger count = diff/framesBetweenMajorTicks;
        
        if (count>1)
            spawnFrame += ((count)*framesBetweenMajorTicks);
        }
    }
    
     // Start page view marker
    
#ifdef GFX_DEBUG
    UIView *startview =[[UIView alloc] initWithFrame:CGRectMake(0, 25, 1, ktimecodeRibbonHeight)];
    startview.backgroundColor = [UIColor redColor];
    startview.tag = 104;
    [view addSubview:startview];
    
    UILabel *pageNumLeft = [[UILabel alloc] initWithFrame:CGRectMake(40, 20, 300, 30)];
    pageNumLeft.clipsToBounds = NO;
    pageNumLeft.textColor =[UIColor darkGrayColor];
    pageNumLeft.font =[UIFont boldSystemFontOfSize:8];
    pageNumLeft.text = [NSString stringWithFormat:@"start Fr:%i  spawn Fr:%i",pageStartFrame,spawnFrame];
    pageNumLeft.tag = 104;
    [view addSubview:pageNumLeft];
    
    UILabel *pageNumRight = [[UILabel alloc] initWithFrame:CGRectMake(200, 20, 80, 30)];
    pageNumRight.clipsToBounds = NO;
    pageNumRight.textColor =[UIColor darkGrayColor];
    pageNumRight.font =[UIFont boldSystemFontOfSize:12];
    pageNumRight.text = [NSString stringWithFormat:@"%i",index];
    pageNumRight.tag = 104;
    [view addSubview:pageNumRight];
#endif
    
    if (spawnFrame > pageEndFrame || spawnFrame >pageStartFrame) {
        
        while (spawnFrame >pageStartFrame) {
            
            spawnFrame -=30*kframeRate;
        }
    }
    
    if (framesBetweenMajorTicks <10*kframeRate) {
      
        NSLog(@"Frames betweenMajorTicks  %li",(long)framesBetweenMajorTicks);
        framesBetweenMajorTicks +=30*kframeRate;
    }
    
    // Draw Loop
    
    while (spawnFrame <= pageEndFrame) {
        
        if (spawnFrame >= pageStartFrame) {
            
            ALFrame framesFromLeft = spawnFrame - pageStartFrame;
            CGFloat Xpostion = [self pointFromFrame:framesFromLeft];
            
            // Timecode label
            
            UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(Xpostion-35, 2, 70, 30)];
            label.clipsToBounds = NO;
            label.textAlignment = NSTextAlignmentCenter;
            label.textColor =[UIColor darkGrayColor];
            label.font =[UIFont boldSystemFontOfSize:10];
            label.tag = 101;
            
            NSString *timecodeString = [AVTimecode stringFromFrames:spawnFrame];      // <- slowest part of this loop
            NSInteger length = 11;  // If we don't want to show frames set length=8
            label.text = [timecodeString substringWithRange:(NSRange){0,length}];
            [view addSubview:label];
            
            // Add tick
            
            UIView *tickview =[[UIView alloc] initWithFrame:CGRectMake(Xpostion, 0, 2, 8)];
            tickview.backgroundColor = [UIColor lightGrayColor];
            tickview.tag = 101;
            [view addSubview:tickview];
        }
      
        if (detail) {
            
            // Midway tick
            
            // Draw ticks that go off the right hand side..
            
            NSInteger midtick = spawnFrame+(framesBetweenMajorTicks/2);
            
            if (midtick>=pageStartFrame && midtick <=pageEndFrame ) {
                
                UIView *midTickView =[[UIView alloc] initWithFrame:CGRectMake([self pointFromFrame:midtick-pageStartFrame], 0, 2, 6)];
                midTickView.backgroundColor = [UIColor lightGrayColor];
                midTickView.tag = 101;
                [view addSubview:midTickView];
            }
            
            // Quater Ticks
            
            ALFrame qtrTick = roundf(framesBetweenMajorTicks/4);
            
            if (spawnFrame+qtrTick >= pageStartFrame && spawnFrame+qtrTick <=pageEndFrame ) {
                
                UIView *q1TickView =[[UIView alloc] initWithFrame:CGRectMake([self pointFromFrame:spawnFrame-pageStartFrame+qtrTick], 0, 1, 4)];
                q1TickView.backgroundColor = [UIColor lightGrayColor];
                q1TickView.tag = 101;
                [view addSubview:q1TickView];
            }
            
            if (spawnFrame+(qtrTick*3) >=pageStartFrame && spawnFrame+(qtrTick*3) <=pageEndFrame ) {
                
                UIView *q3TickView =[[UIView alloc] initWithFrame:CGRectMake([self pointFromFrame:spawnFrame-pageStartFrame+(qtrTick*3)], 0, 1, 4)];
                q3TickView.backgroundColor = [UIColor lightGrayColor];
                q3TickView.tag = 101;
                [view addSubview:q3TickView];
            }
        }
        
        spawnFrame += framesBetweenMajorTicks;
    }
    
    return view;
}


- (CGFloat)pointFromFrame:(NSInteger)frame
{
    return roundf(frame * _pointsPerFrame);
}


- (NSInteger)frameFromPoint:(CGFloat)point
{
    return roundf(point / _pointsPerFrame);
}




// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.

- (void)drawRect:(CGRect)rect
{
    [[self subviews] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [obj removeFromSuperview];
    }];
    
    [self plotRibbonOnView:self detail:YES];
}

@end
