/**
 * AdBlock Module (Enhanced)
 *
 * Supplements the core YTLite ad-blocking with deeper, more aggressive hooks:
 * - Server-side ad response stripping (playerAds, adSlots, adPlacements)
 * - Shorts feed ad renderers
 * - Masthead / hero banners
 * - Shopping shelves & merchandise
 * - In-search sponsored results (additional patterns)
 * - Premium/Music upsell banners & dialogs
 * - Engagement panels with ad content
 * - Notification promotional content
 *
 * Build flag: ENABLE_ADBLOCK_PLUS=1
 * (Works alongside existing noAds toggle in core YTLite)
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "../../YTLite.h"

// Forward declarations for YouTube internal ad classes
@interface YTIAdSlotRenderer : NSObject
@end

@interface YTIAdPlacementRenderer : NSObject
@end

@interface YTIPlayerAdRenderer : NSObject
@end

@interface YTIInstreamVideoAdRenderer : NSObject
@end

@interface YTILinearAdSequenceRenderer : NSObject
@end

@interface YTIMastheadAdRenderer : NSObject
@end

@interface YTIStatementBannerRenderer : NSObject
@end

@interface YTIBannerPromoRenderer : NSObject
@end

@interface YTIMealbarPromoRenderer : NSObject
@end

@interface YTICompactPromotedItemRenderer : NSObject
@end

@interface YTIProductListRenderer : NSObject
@end

@interface YTIProductListItemRenderer : NSObject
@end

@interface YTIBackgroundPromoRenderer : NSObject
@end

@interface YTIPivotMessageRenderer : NSObject
@end

@interface YTInnerTubeRequest : NSObject
@end

@interface GPBExtensionField : NSObject
@end
