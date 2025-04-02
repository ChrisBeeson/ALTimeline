//
//  ALTimelineDeviceInfoCell.m
//  ActionLog
//
//  Created by Christopher Beeson on 20/03/2014.
//  Copyright (c) 2014 Chris Beeson. All rights reserved.
//

#import "ALTimelineDeviceInfoCell.h"
#import "ALRecordingDeviceClip.h"
#import "NGAParallaxMotion.h"
#import "ALTimelineDeviceAudioChannelsCell.h"

@interface ALTimelineDeviceInfoCell () {

    NSArray * _deviceClips;
    NSMutableArray * _deviceClipViews;
    NSInteger _selectedDevice;
    
}

@end


@implementation ALTimelineDeviceInfoCell

- (UIView *)cellView
{
    if (!self.view) {
        
        CGFloat rowHeight = 19.0;
        CGFloat maxDevicenameLength = 150.0;
        CGFloat timecodeLength = 60.0;
        CGFloat padding = 3.0;
        
        // Sort devicesClips as per the index
        
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"index" ascending:YES];
        _deviceClips = [[self.event deviceClips] sortedArrayUsingDescriptors:@[sortDescriptor]];
        
        if (_deviceClips.count == 0) {
            
            NSLog(@"%s No Device Info to display in Cell",__PRETTY_FUNCTION__);
            return nil;
        }

        
        
        if (_deviceClips.count > 0) {
            
            //TODO: Make scrollview if over a MAX height
            
            UIView *mainView = [[UIView alloc] initWithFrame:(CGRect){0,0,150,30}]; // Placeholder frame size
            mainView.clipsToBounds = NO;
            mainView.userInteractionEnabled = YES;
            mainView.tag =3;
            
            mainView.parallaxIntensity = 15;
            
            
            // Find max length of Device name
            
            CGFloat deviceNameLength = 0;
            
            for (ALRecordingDeviceClip* device in _deviceClips) {
                
                CGSize maximumLabelSize = CGSizeMake(maxDevicenameLength, rowHeight);
                CGRect textRect = [device.name boundingRectWithSize:maximumLabelSize
                                                            options:(NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading)
                                                         attributes:@{NSFontAttributeName:[UIFont boldSystemFontOfSize:13]}
                                                            context:nil];
                
                if (textRect.size.width > deviceNameLength) {
                    
                    deviceNameLength = textRect.size.width;
                }
            }
            
            mainView.frame = (CGRect){0,0,deviceNameLength+timecodeLength,([_deviceClips count]*(rowHeight+padding))};
            
            _deviceClipViews = [[NSMutableArray alloc] initWithCapacity:[_deviceClips count]];
            
            
            // Create the views
            
            NSUInteger idx =0;
            
            for (ALRecordingDeviceClip* device in _deviceClips) {
                
                UIView *containterView = [[UIView alloc] initWithFrame:(CGRect){0,(rowHeight+padding)*idx,deviceNameLength+timecodeLength,rowHeight}];
                
                containterView.layer.cornerRadius = 5.0;
                containterView.layer.borderWidth = 0.2;
                containterView.layer.borderColor = [[UIColor darkGrayColor] CGColor];
                containterView.backgroundColor = [UIColor whiteColor];
                containterView.clipsToBounds = NO;
                containterView.userInteractionEnabled = YES;
                
                // Device Name
                
                UILabel *deviceLabel = [[UILabel alloc] initWithFrame:(CGRect){padding,0,deviceNameLength,rowHeight}];
                
                deviceLabel.clipsToBounds = NO;
                deviceLabel.textAlignment = NSTextAlignmentLeft;
                deviceLabel.textColor =[UIColor darkGrayColor];
                deviceLabel.font =[UIFont boldSystemFontOfSize:10];
                deviceLabel.text = [device name];
                
                [containterView addSubview:deviceLabel];
                
                // Timecode label
                
                UILabel *timecodeLabel = [[UILabel alloc] initWithFrame:(CGRect){deviceNameLength,0,timecodeLength,rowHeight}];
                
                timecodeLabel.clipsToBounds = NO;
                timecodeLabel.textAlignment = NSTextAlignmentLeft;
                timecodeLabel.textColor =[UIColor darkGrayColor];
                timecodeLabel.font =[UIFont systemFontOfSize:10];
                timecodeLabel.text= [device startTimecode];
                [containterView addSubview:timecodeLabel];
                
                UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(deviceClipTapped:)];
                [containterView addGestureRecognizer:tap];
                
                [_deviceClipViews addObject:containterView];
                
                [mainView addSubview:containterView];
                
                idx +=1;
            };

            self.view = mainView;
            self.view.tag = 3;
        }
    }
    
    return self.view;
}

-(void) deviceClipTapped:(UITapGestureRecognizer *)gesture {
    
    if (gesture.state == UIGestureRecognizerStateRecognized) {
     
        NSInteger selectedDevice = [_deviceClipViews indexOfObject:gesture.view];
        
        if (selectedDevice != NSNotFound && selectedDevice != _selectedDevice) {
            
            _selectedDevice = selectedDevice;
            
            [self updateDeviceClipViews];
            
            BOOL animateOpen = YES;   // only animate if a child hasn't been presented
            
            if (self.childOpen) {
                [self closeChild];
                animateOpen = NO;
            }
            
            ALTimelineDeviceAudioChannelsCell *audioChild = [[ALTimelineDeviceAudioChannelsCell alloc] init];
            audioChild.childSpawnPostion = ALTimelineCellSpawnPostionRight;
            audioChild.device = _deviceClips[selectedDevice];
            
            [self setChild:audioChild];
            [self openChildAnimated:animateOpen];
            
        } else if (selectedDevice != NSNotFound && selectedDevice == _selectedDevice ) {
            
            // If the selected device is tapped on again, close it
            
            _selectedDevice = NSNotFound;
            [self closeChild];
        }
    }
}

-(void) updateDeviceClipViews {
    
    [_deviceClipViews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        
        __block NSUInteger num = idx;
        
        if (num ==_selectedDevice) {
         
            [obj setBackgroundColor:[UIColor grayColor]];
             [obj layer].borderColor = [[UIColor blackColor] CGColor];
            
            [[obj subviews] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                
            if ([obj isKindOfClass:[UILabel class]]) {
                [obj setTextColor:[UIColor whiteColor]];
            }
            }];
            
        } else {
            
              [obj setBackgroundColor:[UIColor whiteColor]];
              [obj layer].borderColor = [[UIColor darkGrayColor] CGColor];
            
           [[obj subviews] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            if ([obj isKindOfClass:[UILabel class]]) {
                [obj setTextColor:[UIColor darkGrayColor]];
            }
           }];
        }
    }];
}

-(void)cellWillOpen {
    
    _selectedDevice = NSNotFound;
    [self updateDeviceClipViews];
}

@end
