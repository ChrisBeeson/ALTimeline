//
//  UIView+TagZOrder.m
//  ActionLog
//
//  Created by Chris Beeson on 23/06/2014.
//  Copyright (c) 2014 Chris Beeson. All rights reserved.
//

#import "UIView+TagZOrder.h"

@implementation UIView (TagZOrder)

- (void)orderSubviewsWithTagNumber {
    
    NSArray * sortedArray = [self.subviews sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        
        return [@([(UIView*)obj1 tag]) compare:@([(UIView*)obj2 tag])];
    }];
    
    // now just re-add the views to the container
    
    [sortedArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        
        [self addSubview:obj];
    }];
}

@end
