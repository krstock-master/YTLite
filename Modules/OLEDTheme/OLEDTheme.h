/**
 * OLEDTheme Module
 *
 * Replaces YouTube's dark gray (#212121) with pure black (#000000) across
 * the entire app for OLED displays. Saves battery on OLED iPhones and
 * provides a more immersive viewing experience.
 *
 * Hooks UIColor factory methods, view backgrounds, tab bars, nav bars,
 * engagement panels, comment sections, settings, and more.
 *
 * Build flag: ENABLE_OLED=1
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "../../YTLite.h"

// YouTube's standard dark mode colors that we replace
// #212121 = RGB(33, 33, 33) — primary background
// #181818 = RGB(24, 24, 24) — secondary background
// #282828 = RGB(40, 40, 40) — elevated surfaces
// #3f3f3f = RGB(63, 63, 63) — separators/borders

#define IS_OLED_ENABLED (ytlBool(@"oledMode") && (UITraitCollection.currentTraitCollection.userInterfaceStyle == UIUserInterfaceStyleDark))

#define OLED_BLACK [UIColor blackColor]
#define OLED_NEAR_BLACK [UIColor colorWithRed:0.05 green:0.05 blue:0.05 alpha:1.0]

@interface YTCommonColorPalette : NSObject
@end

@interface YTColor : NSObject
@end
