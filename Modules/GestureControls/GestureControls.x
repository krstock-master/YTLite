/**
 * GestureControls.x
 *
 * Adds ReVanced-style swipe gestures to YouTube's player:
 *
 * ┌──────────────┬──────────────┐
 * │  BRIGHTNESS  │    VOLUME    │
 * │   (swipe ↕)  │   (swipe ↕)  │
 * │              │              │
 * │  Left half   │  Right half  │
 * └──────────────┴──────────────┘
 *
 * - Vertical swipe right half: Volume (uses MPVolumeView system slider)
 * - Vertical swipe left half:  Screen brightness
 * - Both show a floating HUD indicator
 *
 * Build: make package ENABLE_GESTURES=1
 */

#import "GestureControls.h"

// ──────────────────────────────────────────────
// MARK: - Gesture Overlay View
// ──────────────────────────────────────────────

@implementation YTLGestureOverlayView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        
        // Indicator container (centered pill)
        UIView *pill = [[UIView alloc] init];
        pill.tag = 7770;
        pill.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
        pill.layer.cornerRadius = 12;
        pill.clipsToBounds = YES;
        pill.translatesAutoresizingMaskIntoConstraints = NO;
        pill.alpha = 0;
        [self addSubview:pill];
        
        // Icon + text label
        self.indicatorLabel = [[UILabel alloc] init];
        self.indicatorLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        self.indicatorLabel.textColor = [UIColor whiteColor];
        self.indicatorLabel.textAlignment = NSTextAlignmentCenter;
        self.indicatorLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [pill addSubview:self.indicatorLabel];
        
        // Progress bar
        self.indicatorBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        self.indicatorBar.trackTintColor = [[UIColor whiteColor] colorWithAlphaComponent:0.3];
        self.indicatorBar.progressTintColor = [UIColor whiteColor];
        self.indicatorBar.translatesAutoresizingMaskIntoConstraints = NO;
        [pill addSubview:self.indicatorBar];
        
        [NSLayoutConstraint activateConstraints:@[
            [pill.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
            [pill.centerYAnchor constraintEqualToAnchor:self.centerYAnchor constant:-40],
            [pill.widthAnchor constraintEqualToConstant:160],
            [pill.heightAnchor constraintEqualToConstant:56],
            
            [self.indicatorLabel.topAnchor constraintEqualToAnchor:pill.topAnchor constant:8],
            [self.indicatorLabel.leadingAnchor constraintEqualToAnchor:pill.leadingAnchor constant:12],
            [self.indicatorLabel.trailingAnchor constraintEqualToAnchor:pill.trailingAnchor constant:-12],
            
            [self.indicatorBar.topAnchor constraintEqualToAnchor:self.indicatorLabel.bottomAnchor constant:6],
            [self.indicatorBar.leadingAnchor constraintEqualToAnchor:pill.leadingAnchor constant:16],
            [self.indicatorBar.trailingAnchor constraintEqualToAnchor:pill.trailingAnchor constant:-16],
            [self.indicatorBar.heightAnchor constraintEqualToConstant:4]
        ]];
    }
    return self;
}

- (void)showIndicatorWithText:(NSString *)text progress:(CGFloat)progress isVolume:(BOOL)isVolume {
    self.indicatorLabel.text = text;
    [self.indicatorBar setProgress:progress animated:YES];
    
    UIView *pill = [self viewWithTag:7770];
    [UIView animateWithDuration:0.15 animations:^{
        pill.alpha = 1.0;
    }];
}

- (void)hideIndicator {
    UIView *pill = [self viewWithTag:7770];
    [UIView animateWithDuration:0.3 animations:^{
        pill.alpha = 0.0;
    }];
}

@end

// ──────────────────────────────────────────────
// MARK: - System Volume Helper
// ──────────────────────────────────────────────

static MPVolumeView *_ytlVolumeView = nil;
static UISlider *_ytlVolumeSlider = nil;

static UISlider *getSystemVolumeSlider(void) {
    if (!_ytlVolumeSlider) {
        _ytlVolumeView = [[MPVolumeView alloc] initWithFrame:CGRectMake(-100, -100, 40, 40)];
        _ytlVolumeView.hidden = YES;
        
        // We need it in the window to work
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        [keyWindow addSubview:_ytlVolumeView];
        
        for (UIView *subview in _ytlVolumeView.subviews) {
            if ([subview isKindOfClass:[UISlider class]]) {
                _ytlVolumeSlider = (UISlider *)subview;
                break;
            }
        }
    }
    return _ytlVolumeSlider;
}

// ──────────────────────────────────────────────
// MARK: - Player View Hook: Gesture Recognition
// ──────────────────────────────────────────────

static YTLGestureOverlayView *gestureOverlay = nil;

%hook YTPlayerView

- (void)didMoveToWindow {
    %orig;
    
    if (!ytlBool(@"swipeGestures")) return;
    if (!self.window) return;
    
    // Only add gesture recognizer once
    BOOL alreadyAdded = NO;
    for (UIGestureRecognizer *gr in self.gestureRecognizers) {
        if (gr.view == self && [NSStringFromClass([gr class]) isEqualToString:@"UIPanGestureRecognizer"]) {
            if (gr.delegate == (id<UIGestureRecognizerDelegate>)self) {
                alreadyAdded = YES;
                break;
            }
        }
    }
    
    if (!alreadyAdded) {
        UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
                                       initWithTarget:self
                                               action:@selector(ytl_handleGesturePan:)];
        pan.maximumNumberOfTouches = 1;
        pan.delegate = (id<UIGestureRecognizerDelegate>)self;
        [self addGestureRecognizer:pan];
    }
    
    // Add overlay view if not present
    if (![self viewWithTag:7771]) {
        gestureOverlay = [[YTLGestureOverlayView alloc] initWithFrame:self.bounds];
        gestureOverlay.tag = 7771;
        gestureOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:gestureOverlay];
    }
}

%new
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
    return NO;
}

%new
- (void)ytl_handleGesturePan:(UIPanGestureRecognizer *)pan {
    CGPoint location = [pan locationInView:self];
    CGPoint translation = [pan translationInView:self];
    
    CGFloat midX = self.bounds.size.width / 2.0;
    BOOL isRightSide = location.x > midX;
    
    // Sensitivity: require at least 10pt vertical movement to activate
    CGFloat verticalThreshold = 10.0;
    
    switch (pan.state) {
        case UIGestureRecognizerStateBegan: {
            gestureOverlay.panStartPoint = location;
            gestureOverlay.isVolumeGesture = isRightSide;
            
            if (isRightSide) {
                UISlider *slider = getSystemVolumeSlider();
                gestureOverlay.initialVolume = slider ? slider.value : 0.5;
            } else {
                gestureOverlay.initialBrightness = [UIScreen mainScreen].brightness;
            }
            break;
        }
            
        case UIGestureRecognizerStateChanged: {
            if (fabs(translation.y) < verticalThreshold) return;
            
            // Normalize: full swipe across player height = full range
            CGFloat playerHeight = self.bounds.size.height;
            CGFloat delta = -translation.y / playerHeight; // negative because swipe up = increase
            
            if (gestureOverlay.isVolumeGesture) {
                // Volume control
                CGFloat newVolume = gestureOverlay.initialVolume + delta;
                newVolume = fmaxf(0.0, fminf(1.0, newVolume));
                
                UISlider *slider = getSystemVolumeSlider();
                if (slider) {
                    [slider setValue:newVolume animated:NO];
                    [slider sendActionsForControlEvents:UIControlEventValueChanged];
                }
                
                NSString *icon = newVolume > 0.5 ? @"🔊" : (newVolume > 0 ? @"🔉" : @"🔇");
                NSString *text = [NSString stringWithFormat:@"%@ %d%%", icon, (int)(newVolume * 100)];
                [gestureOverlay showIndicatorWithText:text progress:newVolume isVolume:YES];
                
            } else {
                // Brightness control
                CGFloat newBrightness = gestureOverlay.initialBrightness + delta;
                newBrightness = fmaxf(0.0, fminf(1.0, newBrightness));
                
                [UIScreen mainScreen].brightness = newBrightness;
                
                NSString *icon = newBrightness > 0.5 ? @"☀️" : @"🔅";
                NSString *text = [NSString stringWithFormat:@"%@ %d%%", icon, (int)(newBrightness * 100)];
                [gestureOverlay showIndicatorWithText:text progress:newBrightness isVolume:NO];
            }
            break;
        }
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            [gestureOverlay hideIndicator];
            break;
        }
            
        default:
            break;
    }
}

%end
