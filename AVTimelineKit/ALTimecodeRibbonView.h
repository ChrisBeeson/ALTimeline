//
//  ALTimecodeRibbonView.h
//  ActionLog
//
//  Created by Chris Beeson on 18/04/2014.
//  Copyright (c) 2014 Chris Beeson. All rights reserved.
//


@interface ALTimecodeRibbonView : UIView

@property (nonatomic)  AVTimecode * startTimecode;
@property (nonatomic)  AVTimecode * endTimecode;

@property (nonatomic) BOOL autoUpdate;

- (instancetype)initWithFrame:(CGRect)frame startTimecode:(AVTimecode *)startTimecode end:(AVTimecode*)endTimecode absoluteStartTimecode:(AVTimecode*)absoluteStartTimecode highDetailLevel:(BOOL)detailLevel;

@property (NS_NONATOMIC_IOSONLY, readonly, strong) UIView *ribbonView;

@end
