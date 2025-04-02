//
//  ALTimelineDeviceAudioChannelsCell.m
//  ActionLog
//
//  Created by Chris Beeson on 20/04/2014.
//  Copyright (c) 2014 Chris Beeson. All rights reserved.
//

#import "NGAParallaxMotion.h"
#import "ALTimelineDeviceAudioChannelsCell.h"
#import "ALAudioChannel.h"

@implementation ALTimelineDeviceAudioChannelsCell


- (UIView *)cellView
{
    CGFloat rowHeight = 15.0;
    CGFloat maxDevicenameLength = 150.0;
    CGFloat timecodeLength = 60.0;
    CGFloat padding = 3.0;
    
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"channelNumber" ascending:YES];
    
    NSArray *channels = [[self.device audioChannel] sortedArrayUsingDescriptors:@[sortDescriptor]];
    
    if ([channels count] > 0) {
        
        UIView *mainView = [[UIView alloc] initWithFrame:(CGRect){0,0,150,30}]; // Placeholder frame size
        mainView.clipsToBounds = NO;
        // mainView.backgroundColor = [UIColor darkGrayColor];
        
        mainView.parallaxIntensity = 30;
        
        
        
        // Find max length of Channel name
        
        CGFloat nameLength = 0;
        
        for (ALAudioChannel* channel in channels) {
            
            CGSize maximumLabelSize = CGSizeMake(maxDevicenameLength, rowHeight);
            CGRect textRect = [channel.channelName boundingRectWithSize:maximumLabelSize
                                                        options:(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading)
                                                     attributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:13]}
                                                        context:nil];
            
            if (textRect.size.width > nameLength) {
                
                nameLength = textRect.size.width;
            }
        }
        
        mainView.frame = (CGRect){0,0,nameLength+timecodeLength,([channels count]*(rowHeight+padding))};
        
        
        
        // Create the views
        
        NSUInteger idx =0;
        
        for (ALAudioChannel * channel in channels) {
            
            
            UIView *containterView = [[UIView alloc] initWithFrame:(CGRect){0,(rowHeight+padding)*idx,nameLength+timecodeLength,rowHeight}];
            
            //containterView.layer.cornerRadius = 5.0;
            //containterView.layer.borderWidth = 0.2;
            //containterView.layer.borderColor = [[UIColor darkGrayColor] CGColor];
            //containterView.backgroundColor = [UIColor whiteColor];
            // containterView.clipsToBounds = NO;
            
            
            // Audio Number
            
            UILabel *audioChannelNumberLabel = [[UILabel alloc] initWithFrame:(CGRect){padding,0,10,rowHeight}];
            
            audioChannelNumberLabel.clipsToBounds = NO;
            audioChannelNumberLabel.textAlignment = NSTextAlignmentLeft;
            audioChannelNumberLabel.textColor =[UIColor darkGrayColor];
            audioChannelNumberLabel.font =[UIFont systemFontOfSize:10];
            audioChannelNumberLabel.text= [[channel channelNumber] stringValue];
            [containterView addSubview:audioChannelNumberLabel];
            
            // channel name
            
            UILabel *audioChannelNameLabel = [[UILabel alloc] initWithFrame:(CGRect){13,0,nameLength,rowHeight}];
            
            audioChannelNameLabel.clipsToBounds = NO;
            audioChannelNameLabel.textAlignment = NSTextAlignmentLeft;
            audioChannelNameLabel.textColor =[UIColor blackColor];
            audioChannelNameLabel.font =[UIFont systemFontOfSize:10];
            audioChannelNameLabel.text= [channel channelName];
            [containterView addSubview:audioChannelNameLabel];
            
            [mainView addSubview:containterView];
            
            idx +=1;
        };
        
        self.view = mainView;
        self.view.tag = 3;
        
        // [mainView addGestureRecognizer:self.tapGestureRecogniser];
        
        return mainView;
        
    } else {
        
        NSLog(@"%s No Device Info to display in Cell",__PRETTY_FUNCTION__);
        return nil;
    }
}

@end
