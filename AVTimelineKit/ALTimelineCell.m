//
//  ALTimelineCell.m
//  ActionLog
//
//  Created by Chris Beeson on 12/02/2014.
//  Copyright (c) 2014 Chris Beeson. All rights reserved.
//

#import "ALTimelineCell.h"
#import "ALTimelineEventCell.h"


@interface ALTimelineCell () {
    
    UIView *_childView;
    UISnapBehavior *_snapBehavior;
    UIAttachmentBehavior *_attachmentBehavior;
    CALayer *_lineLayer;
    
    ALTimelineCell *_root;
}
@end


@implementation ALTimelineCell

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        // Register to receive notifications
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(notificationRequestsUpdate:)
                                                     name:@"ALTimelineCellsNeedsUpdate" object:nil];
        
        // Gestures
        
        _tapGestureRecogniser = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTap:)];
        _tapGestureRecogniser.numberOfTapsRequired = 1;
        _tapGestureRecogniser.cancelsTouchesInView = NO;
        
        _cascadeChildren = NO;
        _childOpen = NO;
        
        _level =0;
        _highestOpenChild = 0;
        
        _childSpawnPostion = ALTimelineCellSpawnPostionRight;
        _childSpawnPositionOffset = UIOffsetMake(10.0, 0.0);
        
        _canAnimate = YES;
    }
    return self;
}

/*
- (void)setParent:(ALTimelineCell *)parent {
    
    _parent = parent;
    
    //  [parent setChild:self];
    
}
*/

- (void)setChild:(ALTimelineCell *)child {
    
    _child = child;

    [(ALTimelineCell*)_child setParent:self];
    [(ALTimelineCell*)_child setLevel:_level+1];
}


- (void)setRoot:(ALTimelineCell*)root {
    
    _root = root;
}

-(id)root {
    
    if (_root) return _root;
    
    // drill down parents until we find root
    
    if (_parent) {
        return [_parent root];
        
    } else {
        
            NSAssert(nil,@"Root cannot be NULL");
            return nil;
    }
}


- (void)singleTap:(UIGestureRecognizer *)gesture
{
    if (gesture.state != UIGestureRecognizerStateRecognized) return;
    
    /// A single tap displays a child view
    
    id<GAITracker> tracker = [[GAI sharedInstance] defaultTracker];
    [tracker send:[[GAIDictionaryBuilder createEventWithCategory:@"UI"
                                                          action:@"Single Tap"
                                                           label:[[self class] description]
                                                           value:nil] build]];
    
    if (_child && !_childOpen) {
        [self openChildAnimated:YES];
    } else {
        [self closeChild];
    }
}


-(void)openChildAnimated:(BOOL)animated
{
    if (_child)
    {
        if (!_childOpen)
        {
             [_child cellWillOpen];
            
            // Send out a notif to close any open cells (but only if we're not the root)
            
            if (self == [self root]) {
                
                NSDictionary *dict = @{@"Action":@"closeChild",
                                       @"ExcludeRoot":[self root]};
                
                [[NSNotificationCenter defaultCenter] postNotificationName:@"ALTimelineCellsNeedsUpdate" object:dict];
            }
            
            // Get the view
            
            _childView = [_child cellView];
            
            if (!_childView) return;
            
            CGRect childFrame = [(UIView*)_childView frame];
            [[[[self root] view] superview] addSubview:_childView];
            
            // Calc Final position
            
            CGPoint childPoint = self.view.frame.origin;
            
            switch (_childSpawnPostion) {
                    
                case ALTimelineCellSpawnPostionLeft:
                    
                    childPoint.x =  self.view.frame.origin.x - childFrame.size.width - _childSpawnPositionOffset.horizontal;
                    childPoint.y = self.view.frame.origin.y +_childSpawnPositionOffset.vertical;
                    break;
                    
                case ALTimelineCellSpawnPostionRight:
                    
                    childPoint.x = childPoint.x + self.view.bounds.size.width + _childSpawnPositionOffset.horizontal;
                    childPoint.y = childPoint.y - childFrame.size.height + _childSpawnPositionOffset.vertical;
                    break;
                    
                case ALTimelineCellSpawnPostionCentre:
                    childPoint.x = childPoint.x + (self.view.frame.size.width/2)-(childFrame.size.width/2);
                    childPoint.y =childPoint.y - childFrame.size.height- _childSpawnPositionOffset.vertical;
                    break;
                    
                default:
                    break;
            }
            
            childFrame.origin = childPoint;
            _childView.frame = childFrame;
            childPoint = _childView.center;
            childPoint = [_childView.superview convertPoint:childPoint fromView:[[[self root] view] superview]];
            
            if (animated) {
                
                // Set the starting position - the middle of this view
                
                CGPoint centre = [self.view.superview convertPoint:self.view.center fromView:[[[self root] view] superview]];
                CGRect startFrame;
                startFrame.origin = centre;
                startFrame.size = childFrame.size;
                [(UIView*)_childView setCenter:centre];
                
                // Add the snap
                
                if (_snapBehavior) {
                    
                    [[[[ALManager manager] timeline] dynamicAnimator] removeBehavior:_snapBehavior];
                    _snapBehavior = nil;
                }

                _snapBehavior =[[UISnapBehavior alloc] initWithItem:_childView snapToPoint:childPoint];
                
                //Add flow lines
                //   __weak id weakSelf = self;
                // _snapBehavior.action = ^{ [weakSelf drawFlowLine];};
                
                [[[[ALManager manager] timeline] dynamicAnimator] addBehavior:_snapBehavior];
            }
            
            
            // Is there an option button?
            
            if ([self optionButton]) {
                
                UIButton * optBut = [self optionButton];
                CGPoint optButPoint = (CGPoint) {-10,-10};
                CGRect optFrame = optBut.frame;
                optFrame.origin = optButPoint;
                optBut.frame= optFrame;
                [self.view addSubview:optBut];
            }
            
            _childOpen = YES;
            [self.root setHighestOpenChild:_level+1];
            [_child cellDidOpen];
            
            //   if (_cascadeChildren) { [(ALTimelineCell*)_child openChildAnimated:NO]; }
        }
    }
}


- (void)openChildrenToLevel:(NSUInteger)level {
    
    if (level>0 && _level <=level) {
        //     [self openChildAnimated:YES];
        
        // Need to wait for bounce
        // May be safer
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            [(ALTimelineCell*)[self child] openChildAnimated:YES];
        });
    }
}



- (void)closeChild {
    
    if (_childOpen) {
        
        [_child cellWillClose];
        
        // If we have a child close it... and drill down
        
        if ([(ALTimelineCell*)_child child]) {
            [(ALTimelineCell*)_child closeChild];
        }
        
        [_dynamicAnimator removeBehavior:_snapBehavior];
        [_childView removeFromSuperview];
        
        _childOpen = NO;
        if (_level >0) [self.root setHighestOpenChild:_level-1];
        
        //   [self drawFlowLine];
    
        [_child cellDidClose];
    }
}


- (void)destroyChild {
    
    if (_child) {
        [_child destroyChild];
        _child =nil;
    }
    
}


-(UIView *)cellView {
    
    return nil;
}


- (void)addDynamicsWithAnimator:(UIDynamicAnimator *)dynamicAnimator {
    
    //TODO: Only Root stores this.
    
    _dynamicAnimator = dynamicAnimator;
    
    if (!self.view) {
        
        NSLog(@"%s a dynamic Animator is trying to be added to a NULL CellView",__PRETTY_FUNCTION__);
        
        [self cellView];
    }
    
    /*
     [[dynamicAnimator behaviors] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
     
     if ([obj isKindOfClass:[UIGravityBehavior class]]) {
     
     [obj addItem:self.view];
     
     }
     }];
     */
    
    
    /*
     UIGravityBehavior *gravity = [[UIGravityBehavior alloc] initWithItems:@[self.view]];
     
     CGVector vector = CGVectorMake(0.0, 1.0);
     
     [gravity setGravityDirection:vector];
     [dynamicAnimator addBehavior:gravity];
     
     
     //Add collision
     
     UICollisionBehavior *collision = [[UICollisionBehavior alloc]
     initWithItems:@[self.view]];
     collision.translatesReferenceBoundsIntoBoundary = YES;
     
     [dynamicAnimator addBehavior:collision];
     */
    /*
     UIDynamicItemBehavior *behavior =
     [[UIDynamicItemBehavior alloc] initWithItems:@[self.view]];
     behavior.elasticity = 0.5;
     
     [dynamicAnimator addBehavior:behavior];
     */
}

- (void)updateCellView {
    
    [self.view setNeedsDisplay];
}



// Draw line to child

-(void)drawFlowLine {
  
    if (_childOpen) {
    if (!_lineLayer) {
     CALayer *layer = self.view.layer;
     _lineLayer = [CALayer layer];
     _lineLayer.opacity = 1.0;
     _lineLayer.backgroundColor = [UIColor grayColor].CGColor;
        
     [layer insertSublayer:_lineLayer atIndex:0];
    }
        
    }else {
        if (_lineLayer) {
            [_lineLayer removeFromSuperlayer];
            _lineLayer = nil;
        }
    }
    
    CGPoint p1, p2;
    CGRect frame;
    frame = [self.view frame];
    p1 = CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
    frame = [self.child.view frame];
    p2 = CGPointMake(CGRectGetMidX(frame), CGRectGetMidY(frame));
    
    p1 = [self.view convertPoint:p1 fromView:self.view.superview];
    p2 = [self.child.view convertPoint:p2 fromView:self.view.superview];

    // And now into coordinate system of target view.
    // p1 = [self.view convertPoint:p1 toView:self.view.superview];
    p2 = [self.child.view convertPoint:p2 toView:self.view];
    
    setLayerToLineFromAToB(_lineLayer, p1,p2, 1.0);
    
    [self.view setNeedsDisplay];
    
    //  CGPoint startPoint = (CGPoint){self.view.frame.size.width/2,self.view.frame.size.height/2};
}


void setLayerToLineFromAToB(CALayer *layer, CGPoint a, CGPoint b, CGFloat lineWidth)
{
    CGPoint center = { 0.5 * (a.x + b.x), 0.5 * (a.y + b.y) };
    CGFloat length = sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));
    CGFloat angle = atan2(a.y - b.y, a.x - b.x);
    
    layer.position = center;
    layer.bounds = (CGRect) { {0, 0}, { length + lineWidth, lineWidth } };
    layer.transform = CATransform3DMakeRotation(angle, 0, 0, 1);
    
    /*
     @pqnet: You can switch on anti aliasing for core animation layers by setting UIViewEdgeAntialiasing in you app's Info.plist.
     
     */
}




/**
 
 Notification Handling
 
 */


- (void)notificationRequestsUpdate:(NSNotification *)notification
{
    if (self != self.root) return;   // only check root cells
    
    if ([notification.object isKindOfClass:[NSDictionary class]]) {
        
        NSDictionary * dict = notification.object;
        
        if ([dict[@"Action"] isEqualToString:@"closeChild"]) {
            
            if (dict[@"ExcludeRoot"] != [self root]) {
                
                [self closeChild];
            }
        }
    }
}


- (void)cellWillOpen {
    
}

- (void)cellDidOpen {
    
}

- (void)cellWillClose {
    
}

- (void)cellDidClose {
    
}

-(void)cellWillBeginMoving {
    
    [(ALTimelineCell*)_child cellWillBeginMoving];
    [self closeChild];
}

- (BOOL)centredOnTimecode {
    
    return YES;
}

- (NSArray*)gestureRecognisers {
    return nil;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
