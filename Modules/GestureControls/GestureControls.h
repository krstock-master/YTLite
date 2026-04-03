/**
 * GestureControls Module
 * Adds ReVanced-style swipe gestures to the YouTube player:
 * - Right side vertical swipe: Volume control
 * - Left side vertical swipe: Brightness control
 * - Horizontal swipe: Fine-grained seek
 * - Double-tap left/right edges: configurable seek interval
 *
 * Build flag: ENABLE_GESTURES=1
 */

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>
#import "../../YTLite.h"

@interface YTLGestureOverlayView : UIView

@property (nonatomic, strong) UILabel *indicatorLabel;
@property (nonatomic, strong) UIProgressView *indicatorBar;
@property (nonatomic, assign) CGPoint panStartPoint;
@property (nonatomic, assign) CGFloat initialVolume;
@property (nonatomic, assign) CGFloat initialBrightness;
@property (nonatomic, assign) BOOL isVolumeGesture;  // YES = volume, NO = brightness
@property (nonatomic, weak) YTMainAppVideoPlayerOverlayViewController *overlayDelegate;

- (void)showIndicatorWithText:(NSString *)text progress:(CGFloat)progress isVolume:(BOOL)isVolume;
- (void)hideIndicator;

@end
