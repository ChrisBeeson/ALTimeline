//
//  ALTimelineTouchView.m
//  ActionLog
//
//  Created by Chris Beeson on 10/03/2014.
//  Copyright (c) 2014 Chris Beeson. All rights reserved.
//

#import "ALTimelineTouchView.h"

@implementation ALTimelineTouchView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        
        // self.backgroundColor = [UIColor greenColor];
    }
    return self;
}
/*
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    
    [super touchesBegan:touches withEvent:event];
    
    // intercept any touch which would put up into userHasControl.
    
    //NSLog(@"TOUCH!");
}
*/


- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    BOOL pointInside = YES;
    
    //   if (CGRectContainsPoint(imageView.frame, point) || expanded) pointInside = YES;
    
    return pointInside;
}




/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

@end
