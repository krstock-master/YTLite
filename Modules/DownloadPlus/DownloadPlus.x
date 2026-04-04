/**
 * DownloadPlus.x
 *
 * Adds subtitle export and playlist download capabilities.
 *
 * Subtitle Export Flow:
 *   Video ID → timedtext API (srv3 XML) → Parse timestamps → Generate .srt → Share
 *
 * SRT Format:
 *   1
 *   00:00:01,000 --> 00:00:04,500
 *   Hello and welcome to this video
 *
 * Build: make package ENABLE_DOWNLOAD_PLUS=1
 */

#import "DownloadPlus.h"

// ══════════════════════════════════════════════
// MARK: - Subtitle Exporter Implementation
// ══════════════════════════════════════════════

@implementation YTLSubtitleExporter

+ (instancetype)sharedInstance {
    static YTLSubtitleExporter *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (void)exportSubtitlesForVideoID:(NSString *)videoID
                            title:(NSString *)title
                   fromController:(UIViewController *)presenter {
    if (!videoID) {
        [[%c(YTToastResponderEvent) eventWithMessage:LOC(@"Error")
                                      firstResponder:presenter] send];
        return;
    }

    [[%c(YTToastResponderEvent) eventWithMessage:LOC(@"SubtitleExporting")
                                  firstResponder:presenter] send];

    // Try multiple languages
    NSArray *langs = @[@"en", @"ko", @"ja", @"de", @"fr", @"es", @"pt", @"ru", @"zh-Hans"];
    [self fetchSubtitlesForVideoID:videoID languages:langs index:0 title:title presenter:presenter];
}

- (void)fetchSubtitlesForVideoID:(NSString *)videoID
                       languages:(NSArray *)langs
                           index:(NSUInteger)index
                           title:(NSString *)title
                       presenter:(UIViewController *)presenter {
    if (index >= langs.count) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[%c(YTToastResponderEvent) eventWithMessage:LOC(@"SubtitleNotFound")
                                          firstResponder:presenter] send];
        });
        return;
    }

    NSString *lang = langs[index];
    // srv3 format gives us proper timestamps
    NSString *urlStr = [NSString stringWithFormat:
        @"https://www.youtube.com/api/timedtext?v=%@&lang=%@&fmt=srv3", videoID, lang];

    [[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:urlStr]
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = (NSHTTPURLResponse *)response;

        if (error || http.statusCode != 200 || !data || data.length < 100) {
            [self fetchSubtitlesForVideoID:videoID languages:langs index:index + 1 title:title presenter:presenter];
            return;
        }

        NSString *xml = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSString *srt = [self convertTimedTextXMLToSRT:xml];

        if (!srt || srt.length < 20) {
            [self fetchSubtitlesForVideoID:videoID languages:langs index:index + 1 title:title presenter:presenter];
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            [self shareSRT:srt title:title language:lang presenter:presenter];
        });
    }] resume];
}

- (NSString *)convertTimedTextXMLToSRT:(NSString *)xml {
    if (!xml) return nil;

    NSMutableString *srt = [NSMutableString string];
    NSInteger counter = 1;

    // Parse <p t="START_MS" d="DURATION_MS">TEXT</p> format (srv3)
    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:@"<p\\s+t=\"(\\d+)\"\\s+d=\"(\\d+)\"[^>]*>([^<]*(?:<[^/][^>]*>[^<]*</[^>]*>)*[^<]*)</p>"
        options:0 error:nil];

    NSArray *matches = [regex matchesInString:xml options:0 range:NSMakeRange(0, xml.length)];

    for (NSTextCheckingResult *match in matches) {
        if (match.numberOfRanges < 4) continue;

        CGFloat startMs = [[xml substringWithRange:[match rangeAtIndex:1]] floatValue];
        CGFloat durationMs = [[xml substringWithRange:[match rangeAtIndex:2]] floatValue];
        NSString *rawText = [xml substringWithRange:[match rangeAtIndex:3]];

        CGFloat startSec = startMs / 1000.0;
        CGFloat endSec = (startMs + durationMs) / 1000.0;

        // Strip inner XML tags and decode HTML entities
        NSString *text = [self stripHTMLTags:rawText];
        text = [self decodeHTMLEntities:text];
        text = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        if (text.length == 0) continue;

        [srt appendFormat:@"%ld\n%@ --> %@\n%@\n\n",
            (long)counter,
            [self srtTimestamp:startSec],
            [self srtTimestamp:endSec],
            text];
        counter++;
    }

    return srt;
}

- (NSString *)stripHTMLTags:(NSString *)html {
    NSRegularExpression *tagRegex = [NSRegularExpression
        regularExpressionWithPattern:@"<[^>]+>" options:0 error:nil];
    return [tagRegex stringByReplacingMatchesInString:html options:0
            range:NSMakeRange(0, html.length) withTemplate:@""];
}

- (NSString *)decodeHTMLEntities:(NSString *)text {
    text = [text stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
    text = [text stringByReplacingOccurrencesOfString:@"&lt;" withString:@"<"];
    text = [text stringByReplacingOccurrencesOfString:@"&gt;" withString:@">"];
    text = [text stringByReplacingOccurrencesOfString:@"&#39;" withString:@"'"];
    text = [text stringByReplacingOccurrencesOfString:@"&quot;" withString:@"\""];
    text = [text stringByReplacingOccurrencesOfString:@"&nbsp;" withString:@" "];
    return text;
}

- (NSString *)srtTimestamp:(CGFloat)seconds {
    NSInteger hrs = (NSInteger)(seconds / 3600);
    NSInteger mins = ((NSInteger)seconds % 3600) / 60;
    NSInteger secs = (NSInteger)seconds % 60;
    NSInteger ms = (NSInteger)((seconds - floor(seconds)) * 1000);
    return [NSString stringWithFormat:@"%02ld:%02ld:%02ld,%03ld",
            (long)hrs, (long)mins, (long)secs, (long)ms];
}

- (void)shareSRT:(NSString *)srt
           title:(NSString *)title
        language:(NSString *)lang
       presenter:(UIViewController *)presenter {
    // Sanitize filename
    NSString *safeTitle = [[title componentsSeparatedByCharactersInSet:
        [[NSCharacterSet alphanumericCharacterSet] invertedSet]]
        componentsJoinedByString:@"_"];
    if (safeTitle.length > 80) safeTitle = [safeTitle substringToIndex:80];

    NSString *filename = [NSString stringWithFormat:@"%@_%@.srt", safeTitle, lang];
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:filename];

    NSError *writeError = nil;
    [srt writeToFile:tempPath atomically:YES encoding:NSUTF8StringEncoding error:&writeError];

    if (writeError) {
        [[%c(YTToastResponderEvent) eventWithMessage:LOC(@"Error")
                                      firstResponder:presenter] send];
        return;
    }

    NSURL *fileURL = [NSURL fileURLWithPath:tempPath];
    UIActivityViewController *shareVC = [[UIActivityViewController alloc]
        initWithActivityItems:@[fileURL] applicationActivities:nil];

    if ([presenter isKindOfClass:[UIViewController class]]) {
        // iPad popover support
        shareVC.popoverPresentationController.sourceView = presenter.view;
        shareVC.popoverPresentationController.sourceRect = CGRectMake(
            presenter.view.bounds.size.width / 2, presenter.view.bounds.size.height / 2, 0, 0);
    }

    [[%c(YTUIUtils) topViewControllerForPresenting] presentViewController:shareVC animated:YES completion:nil];
}

@end

// ══════════════════════════════════════════════
// MARK: - Playlist Download Queue Implementation
// ══════════════════════════════════════════════

@implementation YTLPlaylistDownloadManager

+ (instancetype)sharedInstance {
    static YTLPlaylistDownloadManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        instance.queue = [NSMutableArray array];
    });
    return instance;
}

- (void)enqueueVideoIDs:(NSArray<NSString *> *)videoIDs {
    for (NSString *vid in videoIDs) {
        [self.queue addObject:@{@"videoID": vid, @"status": @"pending"}];
    }

    NSString *msg = [NSString stringWithFormat:LOC(@"PlaylistQueued"), (unsigned long)videoIDs.count];
    [[%c(YTToastResponderEvent) eventWithMessage:msg
                                  firstResponder:[%c(YTUIUtils) topViewControllerForPresenting]] send];
}

- (void)startProcessing {
    if (self.isProcessing) return;
    self.isProcessing = YES;
    self.completedCount = 0;
    
    // Process queue by opening each video URL sequentially
    // The actual download is handled by YTLite's built-in download manager
    [self processNextInQueue];
}

- (void)processNextInQueue {
    if (self.queue.count == 0) {
        self.isProcessing = NO;
        NSString *msg = [NSString stringWithFormat:LOC(@"PlaylistComplete"), (long)self.completedCount];
        [[%c(YTToastResponderEvent) eventWithMessage:msg
                                      firstResponder:[%c(YTUIUtils) topViewControllerForPresenting]] send];
        return;
    }

    NSDictionary *item = self.queue.firstObject;
    [self.queue removeObjectAtIndex:0];
    self.completedCount++;

    NSString *videoID = item[@"videoID"];
    NSString *progress = [NSString stringWithFormat:@"[%ld/%ld] %@",
                          (long)self.completedCount,
                          (long)(self.completedCount + self.queue.count),
                          videoID];

    [[%c(YTToastResponderEvent) eventWithMessage:progress
                                  firstResponder:[%c(YTUIUtils) topViewControllerForPresenting]] send];

    // Open the video in-app (user can then trigger download via YTLite's manager)
    NSString *urlStr = [NSString stringWithFormat:@"vnd.youtube://%@", videoID];
    NSURL *url = [NSURL URLWithString:urlStr];

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([[UIApplication sharedApplication] canOpenURL:url]) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
                // Wait before processing next to avoid overwhelming
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                    dispatch_get_main_queue(), ^{
                    [self processNextInQueue];
                });
            }];
        } else {
            [self processNextInQueue];
        }
    });
}

- (void)cancelAll {
    [self.queue removeAllObjects];
    self.isProcessing = NO;

    [[%c(YTToastResponderEvent) eventWithMessage:LOC(@"PlaylistCancelled")
                                  firstResponder:[%c(YTUIUtils) topViewControllerForPresenting]] send];
}

@end

// ══════════════════════════════════════════════
// MARK: - Hook: "Export Subtitles" action
// The sheet presentation hook is in core YTLite.x
// (guarded by #ifdef ENABLE_DOWNLOAD_PLUS) to avoid
// conflicts with AutoTranslate module.
// ══════════════════════════════════════════════
