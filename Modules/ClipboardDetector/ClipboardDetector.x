/**
 * ClipboardDetector.x
 *
 * When YouTube becomes active (foreground), checks clipboard for YouTube URLs.
 * If found (and not already opened), shows a toast/banner:
 *   "YouTube link detected — Open video?"
 * Tapping opens the video inside the app (not Safari).
 *
 * Supports: youtube.com/watch, youtu.be, youtube.com/shorts, m.youtube.com
 *
 * Build: make package ENABLE_CLIPBOARD=1
 */

#import "ClipboardDetector.h"

// ──────────────────────────────────────────────
// MARK: - Singleton Detector
// ──────────────────────────────────────────────

@implementation YTLClipboardDetector

+ (instancetype)sharedInstance {
    static YTLClipboardDetector *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (void)checkClipboard {
    if (!ytlBool(@"clipboardDetection")) return;
    
    UIPasteboard *pb = [UIPasteboard generalPasteboard];
    if (!pb.hasStrings && !pb.hasURLs) return;
    
    NSString *clipText = pb.string ?: pb.URL.absoluteString;
    if (!clipText) return;
    
    NSString *videoID = [self extractVideoIDFromURL:clipText];
    if (!videoID) return;
    
    // Don't re-prompt for the same URL
    if ([self.lastDetectedURL isEqualToString:clipText]) return;
    self.lastDetectedURL = clipText;
    
    // Show prompt after a short delay (let app finish launching)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self showOpenPromptForURL:clipText videoID:videoID];
    });
}

- (NSString *)extractVideoIDFromURL:(NSString *)urlString {
    if (!urlString) return nil;
    
    // Trim whitespace
    urlString = [urlString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    // Patterns to match:
    // https://www.youtube.com/watch?v=VIDEO_ID
    // https://youtu.be/VIDEO_ID
    // https://youtube.com/shorts/VIDEO_ID
    // https://m.youtube.com/watch?v=VIDEO_ID
    // https://www.youtube.com/embed/VIDEO_ID
    // https://youtube.com/live/VIDEO_ID
    
    NSArray *patterns = @[
        @"(?:youtube\\.com/watch\\?.*v=)([a-zA-Z0-9_-]{11})",
        @"(?:youtu\\.be/)([a-zA-Z0-9_-]{11})",
        @"(?:youtube\\.com/shorts/)([a-zA-Z0-9_-]{11})",
        @"(?:youtube\\.com/embed/)([a-zA-Z0-9_-]{11})",
        @"(?:youtube\\.com/live/)([a-zA-Z0-9_-]{11})"
    ];
    
    for (NSString *pattern in patterns) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
        NSTextCheckingResult *match = [regex firstMatchInString:urlString options:0 range:NSMakeRange(0, urlString.length)];
        
        if (match && match.numberOfRanges >= 2) {
            return [urlString substringWithRange:[match rangeAtIndex:1]];
        }
    }
    
    return nil;
}

- (void)showOpenPromptForURL:(NSString *)urlString videoID:(NSString *)videoID {
    UIViewController *topVC = [%c(YTUIUtils) topViewControllerForPresenting];
    if (!topVC) return;
    
    // Build an in-app YouTube URL
    NSString *inAppURL = [NSString stringWithFormat:@"vnd.youtube://%@", videoID];
    
    YTAlertView *alert = [%c(YTAlertView) confirmationDialogWithAction:^{
        NSURL *url = [NSURL URLWithString:inAppURL];
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
    }
    actionTitle:LOC(@"Open")
    cancelTitle:LOC(@"Dismiss")];
    
    alert.title = LOC(@"ClipboardDetected");
    alert.subtitle = [NSString stringWithFormat:@"%@\n\nVideo ID: %@", LOC(@"ClipboardDetectedDesc"), videoID];
    [alert show];
}

@end

// ──────────────────────────────────────────────
// MARK: - App Delegate Hook: Trigger on Foreground
// ──────────────────────────────────────────────

%hook YTAppDelegate

- (void)applicationDidBecomeActive:(UIApplication *)application {
    %orig;
    
    [[YTLClipboardDetector sharedInstance] checkClipboard];
}

%end
