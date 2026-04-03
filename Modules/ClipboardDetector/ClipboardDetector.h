/**
 * ClipboardDetector Module
 * Detects YouTube URLs on the clipboard when the app becomes active.
 * Shows a non-intrusive banner asking if user wants to open the video.
 *
 * Build flag: ENABLE_CLIPBOARD=1
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "../../YTLite.h"

@interface YTLClipboardDetector : NSObject

+ (instancetype)sharedInstance;
- (void)checkClipboard;
- (NSString *)extractVideoIDFromURL:(NSString *)urlString;

@property (nonatomic, copy) NSString *lastDetectedURL;

@end
