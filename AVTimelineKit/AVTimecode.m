//
//  AVTimecode.m
//
//  Created by Chris Beeson on 9/01/2014.
//  Copyright (c) 2014 Chris Beeson. All rights reserved.
//

#import "AVTimecode.h"

@interface  AVTimecode()
    
    @property NSInteger hour;
    @property NSInteger minute;
    @property NSInteger second;
    @property ALFrame frame;
    @property double framerate;
    @property NSDate *baseDate;

@end

@implementation AVTimecode

- (NSString *)description {
    
    return [self string];
}


- (instancetype)init
{
    self = [super init];
    
    if (self) {
        _framerate = kdefaultFramerate;
        _hour = _minute = _second = _frame = 0;
    }
    return self;
}


- (instancetype)initWithString:(NSString *)string {
    
    self = [super init];
    if (self) {
        _framerate = kdefaultFramerate;
        _hour = _minute = _second = _frame = 0;
        
        [self setWithString:string];
    }
    return self;
}

- (instancetype)initWithDate:(NSDate *)date {
    
    self = [super init];
    if (self) {
        
        _framerate = kdefaultFramerate;
        [self setWithDate:date];
    }
    return self;
}


- (instancetype)initWithFramesFromZero:(ALFrame)frames {
    
    self = [super init];
    
    if (self) {
        
        _framerate = kdefaultFramerate;
        [self setWithFramesFromZero:frames];
    }
    return self;
}


- (BOOL)setWithString:(NSString *)string {
    
    NSArray *tcComponents = [string componentsSeparatedByString:@":"];
	
    if (tcComponents.count == 4) {
        _hour = [tcComponents[0] intValue];
        _minute = [tcComponents[1] intValue];
        _second = [tcComponents[2] intValue];
        _frame = [tcComponents[3] intValue];
        [self validateTimecode];
        
        return YES;
    }
    return NO;
}


- (void)setWithDate:(NSDate *)date {
    
    if (!date) {
        
        NSLog(@"Date was null so setting it to now");
        date = [NSDate date];
    }
    
    static const NSCalendar *calendar;
    
    if (!calendar)
        calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
    
    _baseDate = date;
    
	NSCalendarUnit unitFlags = NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
	NSDateComponents *dateComponents = [calendar components:unitFlags fromDate:date];
	
	_hour = [dateComponents hour];
	_minute = [dateComponents minute];
	_second = [dateComponents second];
    
    // Calculate frames from milliseconds
    
    double timeInterval  = [date timeIntervalSince1970];
    NSInteger intpart = timeInterval;
    double decpart = timeInterval-intpart;
    
    _frame = floor((decpart*1000)/(1000/_framerate));
    
    if (_frame >_framerate) _frame = 0;
    
    [self validateTimecode];
}


- (void)setWithFramesFromZero:(ALFrame)frames {
    
    _hour = frames/60/60/_framerate;
    _minute = (frames-_hour*60*60*_framerate) / 60 / _framerate;
    _second = (frames-_hour*60*60*_framerate - _minute*60*_framerate) /_framerate;
    _frame = (frames-_hour*60*60*_framerate - _minute*60*_framerate - _second*_framerate);
    
    [self validateTimecode];
}


- (void)validateTimecode {
    
    while (_frame < 0) { _frame += _framerate; _second--; }    while (_frame >= _framerate) { _frame -= _framerate; _second++;}
    while (_second < 0) { _second += 60; _minute--; }          while (_second >= 60) { _second -= 60; _minute++; }
    while (_minute < 0) { _minute += 60; _hour--; }            while (_minute >= 60) { _minute -= 60; _hour++; }
    
    // if ((_framerate.dropFrame) && (_framerate.fps == 30) && (_ff < 2) && (_ss == 0) && (_mm%10 > 0)) _ff+=2;
}


#pragma mark - Init helpers

+ (instancetype)timecodeWithString:(NSString *)string {
    
    return [[self alloc] initWithString:string];
}


+ (instancetype)timecodeWithFramesFromZero:(ALFrame)frames {
    
    return [[self alloc] initWithFramesFromZero:frames];
}


+ (instancetype)timecodeWithDate:(NSDate *)date {
    
    return [[AVTimecode alloc] initWithDate:date];
}

#pragma mark - Methods

- (ALFrame)framesFromZero {
    
    return  (_hour *60 *60 *_framerate) + (_minute *60 * _framerate) +(_second * _framerate) + _frame;
}

- (NSString *)string {
    
    [self validateTimecode];
    
    return [NSString stringWithFormat:@"%02ld:%02ld:%02ld:%02ld",
            (long)_hour,
            (long)_minute,
            (long)_second,
            (long)_frame];
}


+ (NSString *)stringFromFrames:(ALFrame)frames {
    
    AVTimecode *timecode = [[AVTimecode alloc] initWithFramesFromZero:frames];
    return [timecode string];
}


- (ALFrame)framesToNextRoundMinute {
    
    if (_second !=0 || _frame !=0) {
        
        AVTimecode *newTimecode = [[AVTimecode alloc] init];
        newTimecode.hour = _hour;
        [newTimecode addHours:0 minutes:1 seconds:0 frames:0];
        
        ALFrame frameDifference = [newTimecode framesFromZero] - [self framesFromZero];
    
        return frameDifference;
        
    } else return 0;
}


- (ALFrame)framesToNextRoundThirtySeconds {
    
    AVTimecode *newTimecode = [[AVTimecode alloc] initWithFramesFromZero:[self framesFromZero]];
    
    if (_second <30 ) {
        
        newTimecode.second = 30;
        newTimecode.frame =0;
        
    } else if (_second >30) {
        
        [newTimecode addHours:0 minutes:1 seconds:0 frames:0];
        newTimecode.second =0;
        newTimecode.frame =0;
    }
    
    ALFrame frameDifference = [newTimecode framesFromZero] - [self framesFromZero];
    
    //  NSLog(@"old:%@  new:%@   diff:%i",self.string,newTimecode.string,frameDifference);
    
    return frameDifference;
}


- (NSDate *)date {
    
    if (!_baseDate) _baseDate = [NSDate date];
    return [self dateWithBaseDate:_baseDate];
}


- (NSDate *)dateWithBaseDate:(NSDate *)bDate {
    
    if (!bDate) bDate= [NSDate date];
    
    NSCalendar *calendar= [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
	NSCalendarUnit unitFlags = NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay| NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond;
    
	NSDateComponents *dateComponents = [calendar components:unitFlags fromDate:bDate];
    
    dateComponents.hour = _hour;
    dateComponents.minute = _minute;
    dateComponents.second = _second;
    
    //TODO: Millisecond support
    
    [dateComponents setCalendar:calendar];
    
    NSDate *d = [calendar dateFromComponents:dateComponents];
    
    NSAssert([d isKindOfClass:[NSDate class]],@"Expected NSDate");
    
    return d;
}

#pragma mark - Ivar Setters

- (void)setHour:(NSInteger)hours {
    
    NSAssert(hours<25,@"Minutes cannot be over 24, but there are %li",(long)hours);
    
    @synchronized(self)
    {
        _hour = hours;
        [self setWithFramesFromZero:[self framesFromZero]];
    }
}


- (void)setMinute:(NSInteger)minutes {
    
    NSAssert(minutes<60,@"Minutes cannot be over 59, but there are %li",(long)minutes);
    
    @synchronized(self) {
        
        _minute = minutes;
        [self setWithFramesFromZero:[self framesFromZero]];
    }
    
}


- (void)setSecond:(NSInteger)seconds {
    
    NSAssert(seconds<60,@"Seconds cannot be over 59, but there are %li",(long)seconds);
    
    @synchronized(self) {
        
        _second = seconds;
        [self setWithFramesFromZero:[self framesFromZero]];
    }
}


- (void)setFrame:(ALFrame)frames {
    
    NSAssert(frames<_framerate+1,@"frames cannot be over %2f, but there are %li",_framerate,(long)frames);
    
    @synchronized(self) {
        
        _frame =frames;
        [self setWithFramesFromZero:[self framesFromZero]];
    }
}


- (void)setFramerate:(double)framerate {
    
    @synchronized(self) {
        
        _framerate = framerate;
        [self setWithFramesFromZero:[self framesFromZero]];
    }
}



- (void)subtractTimecode:(AVTimecode*)timecode {
    
    ALFrame framesToSubtrack = timecode.framesFromZero;
    ALFrame frames = [self framesFromZero];
    
    NSAssert((frames-framesToSubtrack >0), @"Trying to subtract more frames than are possible");
    
    [self setWithFramesFromZero:frames-framesToSubtrack];
}


- (void)addHours:(NSInteger)hours
         minutes:(NSInteger)minutes
         seconds:(NSInteger)seconds
          frames:(ALFrame)frames {
    
    ALFrame framesToAdd =  (hours *60 *60 *_framerate) + (minutes *60 * _framerate) +(seconds * _framerate) + frames;
    ALFrame currentFrames = self.framesFromZero;
    
    [self setWithFramesFromZero:currentFrames+framesToAdd];
}

- (void)subtractHours:(NSInteger)hours
              minutes:(NSInteger)minutes
              seconds:(NSInteger)seconds
               frames:(ALFrame)frames {
    
    ALFrame framesToSubtract =  (hours *60 *60 *_framerate) + (minutes *60 * _framerate) +(seconds * _framerate) + frames;
    ALFrame currentFrames = self.framesFromZero;
    
    if (currentFrames-framesToSubtract <0)
        NSLog(@"%s subtracting more frames then there currently are",__PRETTY_FUNCTION__);
    
    [self setWithFramesFromZero:currentFrames-framesToSubtract];
}


- (instancetype) copyWithZone:(NSZone *)zone {
    
    AVTimecode *timecode = [AVTimecode new];
    [timecode setFramerate:_framerate];
    [timecode setHour:_hour];
    [timecode setMinute:_minute];
    [timecode setSecond:_second];
    [timecode setFrame:_frame];
    return timecode;
}


- (NSUInteger)hash {
    
    return (_frame + 30 * (_second + 60 * (_minute + 60 * (_hour + 24 * (_framerate + 30)))));
}


- (BOOL)isEqual:(id)otherObject {
    
    if (![otherObject isKindOfClass:[AVTimecode class]])
        return NO;
    
    if ([otherObject hash] != [self hash])
        return NO;
    
    return YES;
}


- (NSComparisonResult)compare:(AVTimecode *)otherTimecode {
    
    ALFrame selfFramesFromZero = [self framesFromZero];
    ALFrame otherFramesFromZero = [otherTimecode framesFromZero];
   
    if (selfFramesFromZero > otherFramesFromZero)
        return NSOrderedDescending;
    
    if (selfFramesFromZero < otherFramesFromZero)
        return NSOrderedAscending;
    
    return NSOrderedSame;
}

#pragma mark - NSCoding -

- (void)encodeWithCoder:(NSCoder *)coder {
    
    [coder encodeInt64:_hour  forKey:@"ALTimecodeHour"];
    [coder encodeInt:(int)_minute forKey:@"ALTimecodeMinute"];
    [coder encodeInt:(int)_second forKey:@"ALTimecodeSecond"];
    [coder encodeInt:(int)_frame forKey:@"ALTimecodeFrame"];
    [coder encodeInt:_framerate forKey:@"ALTimecodeFramerate"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    
    self = [super init];
    _hour = [coder decodeIntForKey:@"ALTimecodeHour"];
    _minute = [coder decodeIntForKey:@"ALTimecodeMinute"];
    _second = [coder decodeIntForKey:@"ALTimecodeSecond"];
    _frame = [coder decodeIntForKey:@"ALTimecodeFrame"];
    _framerate = [coder decodeIntForKey:@"ALTimecodeFramerate"];
    return self;
}

@end
