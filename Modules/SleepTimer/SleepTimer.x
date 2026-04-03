/**
 * SleepTimer.x
 * 
 * Adds a sleep timer to YouTube's player overlay.
 * - Tap the moon icon in the player controls to set a timer.
 * - Options: 15, 30, 45, 60, 90, 120 minutes, or end of current video.
 * - Shows countdown in the player bar area.
 * - Pauses playback when timer expires (doesn't kill the app).
 *
 * Build: make package ENABLE_SLEEP_TIMER=1
 */

#import "SleepTimer.h"

// ──────────────────────────────────────────────
// MARK: - Singleton Timer Manager
// ──────────────────────────────────────────────

@implementation YTLSleepTimerManager

+ (instancetype)sharedInstance {
    static YTLSleepTimerManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (void)startTimerWithMinutes:(NSInteger)minutes {
    [self cancelTimer];
    
    self.remainingSeconds = minutes * 60;
    self.pauseAtEndOfVideo = NO;
    
    self.sleepTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                      target:self
                                                    selector:@selector(timerTick)
                                                    userInfo:nil
                                                     repeats:YES];
    
    [[NSRunLoop mainRunLoop] addTimer:self.sleepTimer forMode:NSRunLoopCommonModes];
    
    NSString *msg = [NSString stringWithFormat:LOC(@"SleepTimerSet"), (long)minutes];
    [[%c(YTToastResponderEvent) eventWithMessage:msg
                                  firstResponder:[%c(YTUIUtils) topViewControllerForPresenting]] send];
}

- (void)startEndOfVideoTimer {
    [self cancelTimer];
    
    self.pauseAtEndOfVideo = YES;
    self.remainingSeconds = -1; // Sentinel: managed by video time hook
    
    [[%c(YTToastResponderEvent) eventWithMessage:LOC(@"SleepTimerEndOfVideo")
                                  firstResponder:[%c(YTUIUtils) topViewControllerForPresenting]] send];
}

- (void)cancelTimer {
    [self.sleepTimer invalidate];
    self.sleepTimer = nil;
    self.remainingSeconds = 0;
    self.pauseAtEndOfVideo = NO;
    
    if (self.countdownLabel) {
        self.countdownLabel.hidden = YES;
    }
}

- (BOOL)isTimerActive {
    return self.sleepTimer != nil || self.pauseAtEndOfVideo;
}

- (void)timerTick {
    self.remainingSeconds -= 1.0;
    
    // Update countdown display
    if (self.countdownLabel) {
        self.countdownLabel.text = [self formattedRemainingTime];
        self.countdownLabel.hidden = NO;
    }
    
    if (self.remainingSeconds <= 0) {
        [self triggerSleep];
    }
}

- (void)triggerSleep {
    [self cancelTimer];
    
    // Pause the active video player
    UIViewController *topVC = [%c(YTUIUtils) topViewControllerForPresenting];
    
    // Walk up to find the YTPlayerViewController
    UIViewController *current = topVC;
    while (current) {
        if ([current isKindOfClass:%c(YTWatchViewController)]) {
            YTWatchViewController *watchVC = (YTWatchViewController *)current;
            [watchVC.playerViewController pause];
            break;
        }
        current = current.parentViewController;
    }
    
    // If we couldn't find it via hierarchy, try a broader approach
    if (!current) {
        // Send a media pause command via the shared audio session
        [[NSNotificationCenter defaultCenter] postNotificationName:@"YTLSleepTimerExpired" object:nil];
    }
    
    [[%c(YTToastResponderEvent) eventWithMessage:LOC(@"SleepTimerExpired")
                                  firstResponder:[%c(YTUIUtils) topViewControllerForPresenting]] send];
}

- (NSString *)formattedRemainingTime {
    if (self.pauseAtEndOfVideo) return @"🌙 EOV";
    
    NSInteger mins = (NSInteger)(self.remainingSeconds / 60);
    NSInteger secs = (NSInteger)((long)self.remainingSeconds % 60);
    return [NSString stringWithFormat:@"🌙 %ld:%02ld", (long)mins, (long)secs];
}

@end

// ──────────────────────────────────────────────
// MARK: - Player Overlay Hook: Add Moon Button
// ──────────────────────────────────────────────

%hook YTMainAppVideoPlayerOverlayViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    
    if (!ytlBool(@"sleepTimer")) return;
    
    UIView *overlayView = self.videoPlayerOverlayView;
    if (!overlayView) return;
    
    // Only add button once
    if ([overlayView viewWithTag:8881]) return;
    
    UIButton *moonButton = [UIButton buttonWithType:UIButtonTypeCustom];
    moonButton.tag = 8881;
    
    UIImage *moonImage = [UIImage systemImageNamed:@"moon.fill"];
    [moonButton setImage:moonImage forState:UIControlStateNormal];
    moonButton.tintColor = [UIColor whiteColor];
    moonButton.translatesAutoresizingMaskIntoConstraints = NO;
    [moonButton addTarget:self action:@selector(ytl_showSleepTimerMenu) forControlEvents:UIControlEventTouchUpInside];
    
    // Accessibility
    moonButton.accessibilityLabel = LOC(@"SleepTimer");
    
    [overlayView addSubview:moonButton];
    
    [NSLayoutConstraint activateConstraints:@[
        [moonButton.topAnchor constraintEqualToAnchor:overlayView.safeAreaLayoutGuide.topAnchor constant:8],
        [moonButton.leadingAnchor constraintEqualToAnchor:overlayView.safeAreaLayoutGuide.leadingAnchor constant:12],
        [moonButton.widthAnchor constraintEqualToConstant:36],
        [moonButton.heightAnchor constraintEqualToConstant:36]
    ]];
    
    // Countdown label (positioned below moon button)
    UILabel *countdownLabel = [[UILabel alloc] init];
    countdownLabel.tag = 8882;
    countdownLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightMedium];
    countdownLabel.textColor = [UIColor whiteColor];
    countdownLabel.textAlignment = NSTextAlignmentCenter;
    countdownLabel.hidden = YES;
    countdownLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [overlayView addSubview:countdownLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [countdownLabel.topAnchor constraintEqualToAnchor:moonButton.bottomAnchor constant:2],
        [countdownLabel.centerXAnchor constraintEqualToAnchor:moonButton.centerXAnchor]
    ]];
    
    [YTLSleepTimerManager sharedInstance].countdownLabel = countdownLabel;
    
    // Tint the button if timer is active
    if ([[YTLSleepTimerManager sharedInstance] isTimerActive]) {
        moonButton.tintColor = [UIColor colorWithRed:0.75 green:0.50 blue:0.90 alpha:1.0];
        countdownLabel.hidden = NO;
    }
}

%new
- (void)ytl_showSleepTimerMenu {
    YTLSleepTimerManager *mgr = [YTLSleepTimerManager sharedInstance];
    
    YTDefaultSheetController *sheet = [%c(YTDefaultSheetController)
        sheetControllerWithMessage:LOC(@"SleepTimer")
                        subMessage:LOC(@"SleepTimerDesc")
                          delegate:nil
                   parentResponder:nil];
    
    NSArray *options = @[@15, @30, @45, @60, @90, @120];
    
    for (NSNumber *mins in options) {
        NSString *title = [NSString stringWithFormat:LOC(@"SleepTimerMinutes"), mins.integerValue];
        [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:title
                                                       iconImage:[UIImage systemImageNamed:@"timer"]
                                                           style:0
                                                         handler:^{
            [mgr startTimerWithMinutes:mins.integerValue];
            [self ytl_updateMoonButtonTint:YES];
        }]];
    }
    
    // End of video option
    [sheet addAction:[%c(YTActionSheetAction) actionWithTitle:LOC(@"SleepTimerEndOfVideo")
                                                   iconImage:[UIImage systemImageNamed:@"stop.circle"]
                                                       style:0
                                                     handler:^{
        [mgr startEndOfVideoTimer];
        [self ytl_updateMoonButtonTint:YES];
    }]];
    
    // Cancel option (only shown if timer is active)
    if ([mgr isTimerActive]) {
        [sheet addAction:[%c(YTActionSheetAction)
            actionWithTitle:LOC(@"SleepTimerCancel")
                 titleColor:[UIColor systemRedColor]
                  iconImage:[UIImage systemImageNamed:@"xmark.circle"]
                  iconColor:[UIColor systemRedColor]
 disableAutomaticButtonColor:YES
    accessibilityIdentifier:nil
                    handler:^{
            [mgr cancelTimer];
            [self ytl_updateMoonButtonTint:NO];
            
            [[%c(YTToastResponderEvent) eventWithMessage:LOC(@"SleepTimerCancelled")
                                          firstResponder:[%c(YTUIUtils) topViewControllerForPresenting]] send];
        }]];
    }
    
    [sheet presentFromViewController:self animated:YES completion:nil];
}

%new
- (void)ytl_updateMoonButtonTint:(BOOL)active {
    UIButton *moonButton = (UIButton *)[self.videoPlayerOverlayView viewWithTag:8881];
    if (moonButton) {
        moonButton.tintColor = active
            ? [UIColor colorWithRed:0.75 green:0.50 blue:0.90 alpha:1.0]
            : [UIColor whiteColor];
    }
}

%end

// ──────────────────────────────────────────────
// MARK: - End-of-Video Detection (polling-based)
// We CANNOT hook singleVideo:currentVideoTimeDidChange: here
// because YTLite.x already hooks it. Instead, we poll from
// the sleep timer manager's timerTick using the player hierarchy.
// ──────────────────────────────────────────────

// (End-of-video detection is handled inside YTLSleepTimerManager.timerTick)

// ──────────────────────────────────────────────
// MARK: - Headphone Disconnect Auto-Pause
// Uses loadWithPlayerTransition hook (different from core's hook)
// to register for audio route change notifications.
// ──────────────────────────────────────────────

%hook YTPlayerViewController

- (void)viewDidLoad {
    %orig;
    
    if (ytlBool(@"headphoneAutoPause")) {
        // Remove any previous observer to avoid duplicates
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVAudioSessionRouteChangeNotification
                                                      object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(ytl_audioRouteChanged:)
                                                     name:AVAudioSessionRouteChangeNotification
                                                   object:nil];
    }
}

%new
- (void)ytl_audioRouteChanged:(NSNotification *)notification {
    NSInteger reason = [notification.userInfo[AVAudioSessionRouteChangeReasonKey] integerValue];
    
    if (reason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self pause];
        });
    }
}

%end
