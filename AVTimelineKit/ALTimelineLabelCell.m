//
//  ALTimelineLabelCell.m
//  ActionLog
//
//  Created by Chris Beeson on 19/03/2014.
//  Copyright (c) 2014 Chris Beeson. All rights reserved.
//

#import "ALTimelineLabelCell.h"
#import "NGAParallaxMotion.h"

@interface ALTimelineLabelCell () {
    
    UILabel *_label;
}
@end


@implementation ALTimelineLabelCell

CGFloat maxWidth = 200.0;
CGFloat maxHeight = 200.0;

- (instancetype)init
{
    self = [super init];
    if (self) {
        /*
              [self observeProperty:@keypath(self.view.frame) withBlock:^(__weak id self, id old, id new) {
                  
                  //  NSLog(@"Label Frame: %@",new);
              }];
         
         */
        
        // [self observeProperty:@keypath(self.event.title) withSelector:@selector(eventTitleDidChangeProperty)];
    }
    return self;
}

- (UIView *)cellView
{
    // Return nil if there isn't any text
    
    if (!self.event || [self.event.title length]==0) {
        
        NSAssert(nil, @"Shouldn't be null");
        return nil;
    }
    
    if (!self.view) {
    
    if (!_label) {
        
        _label = [[UILabel alloc] initWithFrame:(CGRect){0,0,200,30}];
        _label.clipsToBounds = NO;
        _label.textAlignment = NSTextAlignmentLeft;
        _label.textColor =[UIColor darkGrayColor];
        _label.font =[UIFont boldSystemFontOfSize:13];
        _label.userInteractionEnabled = YES;
        _label.numberOfLines = 0;
        _label.tag = 3;
        
        [_label addGestureRecognizer:self.tapGestureRecogniser];
        
        _label.parallaxIntensity = 12;
    }
        
        self.view = [UIView new];
        [self.view addSubview:_label];
    }
    
    [self updateCellView];
    
    self.view.bounds = _label.bounds;
    self.view.tag =5;
        
    return self.view;
    
        // self.view = _label;
        // return _label;
}

- (void)updateCellView {
    
    CGSize maximumLabelSize = CGSizeMake(maxWidth, maxHeight);
    CGRect textRect = [self.event.title boundingRectWithSize:maximumLabelSize
                                                     options:(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading)
                                                  attributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:13]}
                                                     context:nil];
    
    _label.frame = textRect;
    _label.text = self.event.title;
}


-(void)eventTitleDidChangeProperty {
    
    // [self updateCellView];
}


-(void) dealloc {
    
    //[self removeAllObservations];
    
}

@end
