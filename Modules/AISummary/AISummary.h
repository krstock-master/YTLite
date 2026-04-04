/**
 * AISummary Module
 *
 * Fetches the video's auto-generated captions/transcript, sends them to
 * an LLM API (Groq / OpenRouter / custom), and displays a concise summary.
 *
 * - Adds "AI Summary" button in the video description engagement panel
 * - Shows summary in a native YouTube engagement panel
 * - Configurable API provider and API key in settings
 * - Supports: Groq (free tier), OpenRouter, custom OpenAI-compatible endpoint
 *
 * Build flag: ENABLE_AI_SUMMARY=1
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "../../YTLite.h"

typedef NS_ENUM(NSInteger, YTLAIProvider) {
    YTLAIProviderGroq = 0,
    YTLAIProviderOpenRouter = 1,
    YTLAIProviderCustom = 2
};

@interface YTLAISummaryManager : NSObject

+ (instancetype)sharedInstance;

/// Fetch transcript for a video and generate summary
- (void)summarizeVideoWithID:(NSString *)videoID
              fromController:(UIViewController *)presenter;

/// Fetch captions XML URL from YouTube's timedtext API
- (void)fetchTranscriptForVideoID:(NSString *)videoID
                       completion:(void (^)(NSString *transcript, NSError *error))completion;

/// Send transcript to LLM API
- (void)generateSummaryFromTranscript:(NSString *)transcript
                           completion:(void (^)(NSString *summary, NSError *error))completion;

@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic, assign) YTLAIProvider provider;
@property (nonatomic, copy) NSString *customEndpoint;

@end
