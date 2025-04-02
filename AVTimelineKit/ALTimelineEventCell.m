//
//  ALEventCell.m
//  ActionLog
//
//  Created by Chris Beeson on 23/01/2014.
//  Copyright (c) 2014 Chris Beeson. All rights reserved.
//

#import "ALTimelineEventCell.h"
#import "ALTimelineClipEventCell.h"


@interface ALTimelineEventCell () {
    
    
}
@end


@implementation ALTimelineEventCell


- (UIView *)cellView
{
    if (!self.view) {
        
    self.view =[[UIView alloc] initWithFrame:CGRectMake(0, 0, 15, 25)];
    self.view.backgroundColor = [UIColor redColor];
    }
    
    return self.view;
}

- (void)setEvent:(id)event {
    
    _event = event;
    self.timecode = [AVTimecode timecodeWithDate:[(ALEvent*)event timestamp]];
}



- (void)addDynamicsWithAnimator:(UIDynamicAnimator *)dynamicAnimator {
    
    [super addDynamicsWithAnimator:dynamicAnimator];
    
    // Snap or Delete Gesture - Not applicable to ClipEventCells
    
    if (![self isKindOfClass:[ALTimelineClipEventCell class]]) {
        
    UIGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(snapOrDeleteGestureHandlePan:)];
    [self.view addGestureRecognizer:pan];
    
    }
}


- (void)snapOrDeleteGestureHandlePan:(UIPanGestureRecognizer *)gesture
{
    static UIAttachmentBehavior *attachment;
    static UISnapBehavior *snap;
    //static UIGravityBehavior *gravity;
    static UIDynamicItemBehavior *dynamic;
    
    static CGPoint               startCenter;
    
    // variables for calculating angular velocity
    
    static CFAbsoluteTime        lastTime;
    static CGFloat               lastAngle;
    static CGFloat               angularVelocity;
    
    if (gesture.state == UIGestureRecognizerStateBegan)
    {
        [self.dynamicAnimator removeBehavior:attachment];
        [self.dynamicAnimator removeBehavior:dynamic];
        [self.dynamicAnimator removeBehavior:snap];
        
        startCenter = gesture.view.center;
        
        // calculate the center offset and anchor point
        
        CGPoint pointWithinAnimatedView = [gesture locationInView:gesture.view];
        
        UIOffset offset = UIOffsetMake(pointWithinAnimatedView.x - gesture.view.bounds.size.width / 2.0,
                                       pointWithinAnimatedView.y - gesture.view.bounds.size.height / 2.0);
        
        CGPoint anchor = [gesture locationInView:gesture.view.superview];
        
        // create attachment behavior
        
        attachment = [[UIAttachmentBehavior alloc] initWithItem:gesture.view
                                               offsetFromCenter:offset
                                               attachedToAnchor:anchor];
        
        // code to calculate angular velocity (seems curious that I have to calculate this myself, but I can if I have to)
        
        lastTime = CFAbsoluteTimeGetCurrent();
        lastAngle = [self angleOfView:gesture.view];
        
          attachment.action = ^{
            CFAbsoluteTime time = CFAbsoluteTimeGetCurrent();
            CGFloat angle = [self angleOfView:gesture.view];
            if (time > lastTime) {
                angularVelocity = (angle - lastAngle) / (time - lastTime);
                lastTime = time;
                lastAngle = angle;
            }
        };
        
        [self.dynamicAnimator addBehavior:attachment];
        
        [self cellWillBeginMoving];
    }
    else if (gesture.state == UIGestureRecognizerStateChanged)
    {
        // as user makes gesture, update attachment behavior's anchor point, achieving drag 'n' rotate
        
        CGPoint anchor = [gesture locationInView:gesture.view.superview];
        attachment.anchorPoint = anchor;
    }
    else if (gesture.state == UIGestureRecognizerStateEnded)
    {
        // [self.dynamicAnimator removeAllBehaviors];
        
        [self.dynamicAnimator removeBehavior:attachment];
        [self.dynamicAnimator removeBehavior:dynamic];
        [self.dynamicAnimator removeBehavior:snap];
        
        CGPoint velocity = [gesture velocityInView:gesture.view.superview];
        
        // if we aren't dragging it down, just snap it back and quit
        
        // What distance have we moved
        
        CGFloat xDist = (startCenter.x - gesture.view.frame.origin.x);
        CGFloat yDist = (startCenter.y - gesture.view.frame.origin.y);
        CGFloat distance = sqrt((xDist * xDist) + (yDist * yDist));
        
        //  if (fabs(atan2(velocity.y, velocity.x) - M_PI_2) > M_PI_2) {
        
        if(fabs(distance)<180) {
            snap = [[UISnapBehavior alloc] initWithItem:gesture.view snapToPoint:startCenter];
            [self.dynamicAnimator addBehavior:snap];
            return;
        }
        
        self.view.userInteractionEnabled = NO;
        // otherwise, create UIDynamicItemBehavior that carries on animation from where the gesture left off (notably linear and angular velocity)
        
        if (fabs(velocity.x)<20) {
            velocity.x =velocity.x *5;
            velocity.y = velocity.y *5;
        }
        
        dynamic = [[UIDynamicItemBehavior alloc] initWithItems:@[gesture.view]];
        [dynamic addLinearVelocity:velocity forItem:gesture.view];
        [dynamic addAngularVelocity:angularVelocity forItem:gesture.view];
        [dynamic setAngularResistance:2];
        
        // when the view no longer intersects with its superview, go ahead and remove it
        
        dynamic.action = ^{
            
            if (!CGRectIntersectsRect(gesture.view.superview.bounds, gesture.view.frame)) {
                // [self.dynamicAnimator removeAllBehaviors];
                [gesture.view removeFromSuperview];
                 [self.dynamicAnimator removeBehavior:dynamic];

                [[NSNotificationCenter defaultCenter] postNotificationName:@"ALTimelineCellRemove" object:self.event];
            }
        };
        
        [self.dynamicAnimator addBehavior:dynamic];
        
        // add a little gravity so it accelerates off the screen (in case user gesture was slow)
        
        /*
        _gravity = [[UIGravityBehavior alloc] initWithItems:@[gesture.view]];
        _gravity.magnitude = 0.7;
        [self.dynamicAnimator addBehavior:_gravity];
        */
        
        //TODO: is the gavity behavior auto released when the view is removed from superview?
        
    }
}

- (CGFloat)angleOfView:(UIView *)view
{
    // http://stackoverflow.com/a/2051861/1271826
    
    return atan2(view.transform.b, view.transform.a);
}



- (void)notificationRequestsUpdate:(NSNotification *)notification
{
    [super notificationRequestsUpdate:notification];
    
    if([self event] == notification.object) {
        
        [self updateCellView];
    }
}


@end
