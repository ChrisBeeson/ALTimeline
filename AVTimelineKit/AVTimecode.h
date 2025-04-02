//
//  AVTimecode.h
//  TimelineScrollView
//
//  Created by Chris Beeson on 9/01/2014.
//  Copyright (c) 2014 Chris Beeson. All rights reserved.
//

#import <Foundation/Foundation.h>

#define ALFrame NSInteger

/*! Default Framerate is set to 25 frames per second. */

const static double kdefaultFramerate = 25.0;

/*!
    The AVTimecode is the fundemental class for storing and handling timecode, it includes simple maths functions for adding
    and subtracting.  
    Timecode is made from Hours, Minutes, Seconds, Frames.
    Timecodes have a framerate which specify how many frames there are in one second.
*/

@interface AVTimecode : NSObject  <NSCoding, NSCopying>

NS_ASSUME_NONNULL_BEGIN

/*!
     Initializes an \c AVTimecode instance from a string
     @param string An NSString object formatted as a timecode eg. 01:00:00:00
*/
- (instancetype)initWithString:(NSString *)string;

/*!
    Initializes an \c AVTimecode instance from a date. Directly converts Hours, Mins and Seconds and Nanoseconds to timecode
    @param date NSDate to use
 */
- (instancetype)initWithDate:(NSDate *)date;

/*!
 Initializes an \c AVTimecode instance from a string
 @param string An NSString object formatted as a timecode eg. 01:00:00:00
 */
- (instancetype)initWithFramesFromZero:(ALFrame)frames;

- (BOOL)setWithString:(NSString *)string;
- (void)setWithDate:(NSDate *)date;
- (void)setWithFramesFromZero:(ALFrame)frames;

+ (instancetype)timecodeWithString:(NSString *)string;
+ (instancetype)timecodeWithFramesFromZero:(ALFrame)frames;
+ (instancetype)timecodeWithDate:(NSDate *)date;


//!  \return Basic Timecode formatted string representation

- (NSString *)string;

+ (NSString *)stringFromFrames:(ALFrame)frames;

@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSDate *date;



- (NSDate *)dateWithBaseDate:(NSDate *)date;

- (NSComparisonResult)compare:(AVTimecode *)otherTimecode;


// Math functions

- (void)subtractTimecode:(AVTimecode*)timecode;
//- (void)addTimecode:(AVTimecode*)timecode;

- (void)addHours:(NSInteger)hours
         minutes:(NSInteger)minutes
         seconds:(NSInteger)seconds
          frames:(NSInteger)frames;

- (void)subtractHours:(NSInteger)hours
              minutes:(NSInteger)minutes
              seconds:(NSInteger)seconds
               frames:(NSInteger)frames;

//! \return The number of frames, at the current framerate, between 00:00:00:00 and the receiver.

- (ALFrame)framesFromZero;
- (ALFrame)framesToNextRoundMinute;
- (ALFrame)framesToNextRoundThirtySeconds;

NS_ASSUME_NONNULL_END
@end
