/**
 * AdBlock.x — Enhanced Ad Removal
 *
 * LAYER 1: Server Response Stripping
 *   Removes ad data from YouTube's protobuf responses before they reach
 *   the rendering pipeline. This is the most effective approach as it
 *   prevents ads from ever being decoded/rendered.
 *
 * LAYER 2: Renderer Nullification
 *   Catches any ad renderers that slip through Layer 1 by returning nil/empty
 *   data for known ad renderer types.
 *
 * LAYER 3: UI Element Removal
 *   Hides any ad-related UI views that somehow got created.
 *
 * LAYER 4: Behavioral Hooks
 *   Prevents ad tracking, ad playback controllers, and ad-related network requests.
 *
 * Build: make package ENABLE_ADBLOCK_PLUS=1
 */

#import "AdBlock.h"

#define ADS_ENABLED ytlBool(@"noAds")

// ═══════════════════════════════════════════════
// LAYER 1: Server Response Stripping
// Strip ad-related fields from player responses
// ═══════════════════════════════════════════════

// Remove playerAds array from player response (pre-roll, mid-roll, post-roll)
%hook YTIPlayerResponse
- (NSArray *)playerAdsArray { return ADS_ENABLED ? @[] : %orig; }
- (BOOL)hasPlayerAds { return ADS_ENABLED ? NO : %orig; }
- (NSArray *)adSlotsArray { return ADS_ENABLED ? @[] : %orig; }
- (NSArray *)adPlacementsArray { return ADS_ENABLED ? @[] : %orig; }
- (BOOL)hasAdPlacements { return ADS_ENABLED ? NO : %orig; }
- (BOOL)hasAdSlots { return ADS_ENABLED ? NO : %orig; }
%end

// Prevent ad playback config from being created
%hook YTIStreamingData
- (NSArray *)serverAbrStreamingUrl { return ADS_ENABLED ? @[] : %orig; }
%end

// ═══════════════════════════════════════════════
// LAYER 2: Renderer Nullification
// Null out all known ad renderer types
// ═══════════════════════════════════════════════

// In-stream video ads (the actual video ad player)
%hook YTIInstreamVideoAdRenderer
- (id)init { return ADS_ENABLED ? nil : %orig; }
%end

// Linear ad sequences (multiple ads in a row)
%hook YTILinearAdSequenceRenderer
- (id)init { return ADS_ENABLED ? nil : %orig; }
%end

// Ad slot renderers (generic container for any ad)
%hook YTIAdSlotRenderer
- (id)init { return ADS_ENABLED ? nil : %orig; }
%end

// Masthead banners (hero ads at top of home)
%hook YTIMastheadAdRenderer
- (id)init { return ADS_ENABLED ? nil : %orig; }
%end

// Statement/info banners (Premium upsells, etc.)
%hook YTIStatementBannerRenderer
- (id)init { return ADS_ENABLED ? nil : %orig; }
%end

// Promotional banners
%hook YTIBannerPromoRenderer
- (id)init { return ADS_ENABLED ? nil : %orig; }
%end

// Mealbar promos (Premium trial offers)
%hook YTIMealbarPromoRenderer
- (id)init { return ADS_ENABLED ? nil : %orig; }
%end

// Compact promoted items (inline sponsored results)
%hook YTICompactPromotedItemRenderer
- (id)init { return ADS_ENABLED ? nil : %orig; }
%end

// Shopping / Merchandise shelves
%hook YTIProductListRenderer
- (id)init { return ADS_ENABLED ? nil : %orig; }
%end

%hook YTIProductListItemRenderer
- (id)init { return ADS_ENABLED ? nil : %orig; }
%end

// Background promo renderer (full-screen promo overlay)
%hook YTIBackgroundPromoRenderer
- (id)init { return ADS_ENABLED ? nil : %orig; }
%end

// ═══════════════════════════════════════════════
// LAYER 2.5: Extended Element Renderer Filtering
// NOTE: Core YTIElementRenderer.elementData hook is in YTLite.x
// This module adds deeper hooks that the core doesn't cover.
// ═══════════════════════════════════════════════

// ═══════════════════════════════════════════════
// LAYER 3: UI Element Removal
// NOTE: YTAsyncCollectionView.cellForItemAtIndexPath hook is in core YTLite.x
// Additional ad cell patterns are handled via the enhanced YTIElementRenderer hook.
// ═══════════════════════════════════════════════

// ═══════════════════════════════════════════════
// LAYER 4: Behavioral / Tracking Hooks
// Prevent ad-related tracking and network requests
// ═══════════════════════════════════════════════

// Disable ad tracking/attribution
%hook YTIAdTrackingModule
- (void)trackEvent:(id)event { if (!ADS_ENABLED) %orig; }
%end

// Disable ad playback coordinator
%hook YTAdPlaybackCoordinator
- (id)init { return ADS_ENABLED ? nil : %orig; }
%end

// Prevent "Ads by Google" info panel
%hook YTAdInfoDialogViewController
- (void)viewDidLoad {
    if (ADS_ENABLED) {
        [self dismissViewControllerAnimated:NO completion:nil];
        return;
    }
    %orig;
}
%end

// Skip ad feedback / "Why this ad?" flows
%hook YTAdFeedbackViewController
- (void)viewDidLoad {
    if (ADS_ENABLED) {
        [self dismissViewControllerAnimated:NO completion:nil];
        return;
    }
    %orig;
}
%end

// Disable ad impression/click pings
%hook YTIAdPodInfo
- (NSInteger)adsInPod { return ADS_ENABLED ? 0 : %orig; }
- (NSInteger)podIndex { return ADS_ENABLED ? 0 : %orig; }
%end

// ═══════════════════════════════════════════════
// LAYER 5: Premium Upsell Nuke
// More aggressive Premium nag removal
// ═══════════════════════════════════════════════

// "Get Premium" pivot message in various feeds
%hook YTIPivotMessageRenderer
- (id)init { return ADS_ENABLED ? nil : %orig; }
%end

// Premium promo in player
%hook YTPlayerPremiumPromotionController
- (void)showPremiumPromotion { if (!ADS_ENABLED) %orig; }
%end

// Music upsell
%hook YTMusicUpsellAlertController
- (void)showAlert { if (!ADS_ENABLED) %orig; }
%end

// Disable Premium check for certain features (makes some features "just work")
%hook YTIPremiumPreference
- (BOOL)isPremium { return ADS_ENABLED ? YES : %orig; }
%end

// Hide "Get YouTube Premium" button in account menu
%hook YTSettingsSectionItemManager
- (void)updatePremiumSectionWithEntry:(id)entry { if (!ADS_ENABLED) %orig; }
%end

// ═══════════════════════════════════════════════
// LAYER 6: Shorts-Specific Ad Removal
// ═══════════════════════════════════════════════

// Shorts ad interstitials
%hook YTReelInFeedAdRenderer
- (id)init { return ADS_ENABLED ? nil : %orig; }
%end

// Shorts shopping overlay buttons
%hook YTReelShoppingRenderer
- (id)init { return ADS_ENABLED ? nil : %orig; }
%end

// Shorts "promoted" badge
%hook YTReelPromotedHeaderView
- (void)setHidden:(BOOL)hidden { %orig(ADS_ENABLED ? YES : hidden); }
%end

// Disable Shorts ad insertion coordinator
%hook YTReelAdsCoordinator
- (void)fetchAds { if (!ADS_ENABLED) %orig; }
- (void)onAdsReady:(id)ads { if (!ADS_ENABLED) %orig; }
%end

// ═══════════════════════════════════════════════
// LAYER 7: Notification & Inbox Promotional Content
// ═══════════════════════════════════════════════

%hook YTINotificationRenderer
- (BOOL)isPromotional { return ADS_ENABLED ? YES : %orig; }
%end

// Filter promotional notifications from the inbox
%hook YTNotificationCenterViewController
- (void)loadNotifications:(NSArray *)notifications {
    if (ADS_ENABLED) {
        NSMutableArray *filtered = [NSMutableArray array];
        for (id notification in notifications) {
            if (![notification respondsToSelector:@selector(isPromotional)] || ![notification isPromotional]) {
                [filtered addObject:notification];
            }
        }
        %orig(filtered);
        return;
    }
    %orig;
}
%end
