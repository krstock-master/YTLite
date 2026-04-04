/**
 * DownloadPlus Module
 *
 * Enhances the existing YTLite download manager with:
 * 1. Subtitle/Caption export as .srt files
 * 2. Playlist batch download queue
 * 3. Quick download action (long-press download button → instant best quality)
 *
 * Build flag: ENABLE_DOWNLOAD_PLUS=1
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "../../YTLite.h"

// ──────────────────────────────────────────────
// MARK: - Subtitle Exporter
// ──────────────────────────────────────────────

@interface YTLSubtitleExporter : NSObject

+ (instancetype)sharedInstance;

/// Fetch and save subtitles as .srt file
- (void)exportSubtitlesForVideoID:(NSString *)videoID
                            title:(NSString *)title
                   fromController:(UIViewController *)presenter;

/// Parse YouTube timedtext XML (srv3 format) to SRT format
- (NSString *)convertTimedTextXMLToSRT:(NSString *)xml;

/// Format seconds to SRT timestamp: HH:MM:SS,mmm
- (NSString *)srtTimestamp:(CGFloat)seconds;

@end

// ──────────────────────────────────────────────
// MARK: - Playlist Download Queue
// ──────────────────────────────────────────────

@interface YTLPlaylistDownloadManager : NSObject

@property (nonatomic, strong) NSMutableArray<NSDictionary *> *queue;
@property (nonatomic, assign) NSInteger completedCount;
@property (nonatomic, assign) BOOL isProcessing;

+ (instancetype)sharedInstance;

- (void)enqueueVideoIDs:(NSArray<NSString *> *)videoIDs;
- (void)startProcessing;
- (void)cancelAll;

@end
