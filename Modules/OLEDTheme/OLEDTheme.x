/**
 * OLEDTheme.x — Pure Black Dark Mode
 *
 * Targeted approach: hooks only YouTube-specific view classes
 * (not UIView globally) to avoid performance issues and system UI glitches.
 *
 * When dark mode is active AND "oledMode" is enabled:
 *   - All YouTube dark gray backgrounds (#212121, #181818, etc.) → #000000
 *   - Keyboard appearance → dark
 *   - Tab bar, nav bar, settings, feed, player, engagement panels → black
 *
 * Build: make package ENABLE_OLED=1
 */

#import "OLEDTheme.h"

// ═══════════════════════════════════════════════
// MARK: - Color Replacement Helper
// ═══════════════════════════════════════════════

static UIColor *ytl_oledColor(UIColor *original) {
    if (!IS_OLED_ENABLED || !original) return original;
    
    CGFloat r, g, b, a;
    if (![original getRed:&r green:&g blue:&b alpha:&a]) return original;
    
    // Replace dark grays (< 25% luminance, near-equal RGB = gray) with pure black
    if (r < 0.25 && g < 0.25 && b < 0.25 && a > 0.9 &&
        fabs(r - g) < 0.03 && fabs(g - b) < 0.03) {
        return OLED_BLACK;
    }
    return original;
}

// ═══════════════════════════════════════════════
// MARK: - AsyncDisplayKit Views (Texture framework)
// YouTube uses Texture for most of its feed/list UI
// ═══════════════════════════════════════════════

%hook _ASDisplayView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(ytl_oledColor(color));
}
%end

%hook YTELMView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(ytl_oledColor(color));
}
%end

// ═══════════════════════════════════════════════
// MARK: - Tab Bar
// ═══════════════════════════════════════════════

%hook YTPivotBarView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(ytl_oledColor(color));
}
%end

// ═══════════════════════════════════════════════
// MARK: - Navigation / Header
// ═══════════════════════════════════════════════

%hook YTNavigationBarTitleView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(ytl_oledColor(color));
}
%end

// ═══════════════════════════════════════════════
// MARK: - Feed / Collection Views
// ═══════════════════════════════════════════════

%hook YTAsyncCollectionView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(ytl_oledColor(color));
}
%end

// ═══════════════════════════════════════════════
// MARK: - Watch / Player Page
// ═══════════════════════════════════════════════

%hook YTWatchViewController
- (void)viewDidLayoutSubviews {
    %orig;
    if (IS_OLED_ENABLED) self.view.backgroundColor = OLED_BLACK;
}
%end

// ═══════════════════════════════════════════════
// MARK: - Miniplayer
// ═══════════════════════════════════════════════

%hook YTWatchMiniBarView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(ytl_oledColor(color));
}
%end

// ═══════════════════════════════════════════════
// MARK: - Shorts
// ═══════════════════════════════════════════════

%hook YTReelWatchRootViewController
- (void)viewDidLayoutSubviews {
    %orig;
    if (IS_OLED_ENABLED) self.view.backgroundColor = OLED_BLACK;
}
%end

// ═══════════════════════════════════════════════
// MARK: - Engagement Panels (Comments, Description)
// NOTE: YTEngagementPanelView.layoutSubviews is hooked in core YTLite.x
// so we use setBackgroundColor: instead to avoid conflict
// ═══════════════════════════════════════════════

%hook YTEngagementPanelView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(ytl_oledColor(color));
}
%end

%hook YTEngagementPanelHeaderView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(ytl_oledColor(color));
}
%end

// ═══════════════════════════════════════════════
// MARK: - Action Sheets / Bottom Sheets
// ═══════════════════════════════════════════════

%hook YTActionSheetHeaderView
- (void)setBackgroundColor:(UIColor *)color {
    %orig(ytl_oledColor(color));
}
%end

// ═══════════════════════════════════════════════
// MARK: - Settings
// ═══════════════════════════════════════════════

%hook YTSettingsViewController
- (void)viewDidLayoutSubviews {
    %orig;
    if (IS_OLED_ENABLED) {
        self.view.backgroundColor = OLED_BLACK;
    }
}
%end

%hook YTSettingsCell
- (void)setBackgroundColor:(UIColor *)color {
    %orig(ytl_oledColor(color));
}
%end

// ═══════════════════════════════════════════════
// MARK: - Chip / Filter Bars
// ═══════════════════════════════════════════════

%hook YTChipCloudCell
- (void)setBackgroundColor:(UIColor *)color {
    %orig(ytl_oledColor(color));
}
%end

// ═══════════════════════════════════════════════
// MARK: - Search
// ═══════════════════════════════════════════════

%hook YTSearchViewController
- (void)viewDidLayoutSubviews {
    %orig;
    if (IS_OLED_ENABLED) self.view.backgroundColor = OLED_BLACK;
}
%end

// ═══════════════════════════════════════════════
// MARK: - Keyboard Appearance
// ═══════════════════════════════════════════════

%hook YTSearchTextField
- (void)didMoveToWindow {
    %orig;
    if (IS_OLED_ENABLED) self.keyboardAppearance = UIKeyboardAppearanceDark;
}
%end

// ═══════════════════════════════════════════════
// MARK: - Scrollable Navigation
// ═══════════════════════════════════════════════

%hook YTScrollableNavigationController
- (void)viewDidLayoutSubviews {
    %orig;
    if (IS_OLED_ENABLED) self.view.backgroundColor = OLED_BLACK;
}
%end

%hook YTTabsViewController
- (void)viewDidLayoutSubviews {
    %orig;
    if (IS_OLED_ENABLED) self.view.backgroundColor = OLED_BLACK;
}
%end
