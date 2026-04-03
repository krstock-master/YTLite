/**
 * SleepTimer Module
 * Adds a configurable sleep timer to YouTube playback.
 * User can set 15/30/45/60/90/120 min or end-of-video timers.
 * Integrates into the player overlay as a moon icon button.
 *
 * Build flag: ENABLE_SLEEP_TIMER=1
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "../../YTLite.h"

@interface YTLSleepTimerManager : NSObject

@property (nonatomic, strong) NSTimer *sleepTimer;
@property (nonatomic, assign) NSTimeInterval remainingSeconds;
@property (nonatomic, assign) BOOL pauseAtEndOfVideo;
@property (nonatomic, weak) UILabel *countdownLabel;

+ (instancetype)sharedInstance;

- (void)startTimerWithMinutes:(NSInteger)minutes;
- (void)startEndOfVideoTimer;
- (void)cancelTimer;
- (BOOL)isTimerActive;
- (NSString *)formattedRemainingTime;

@end
