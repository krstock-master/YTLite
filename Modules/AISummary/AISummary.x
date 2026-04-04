/**
 * AISummary.x
 *
 * Flow: Video ID → Fetch captions → Parse transcript → LLM API → Show summary
 *
 * Transcript source: YouTube's timedtext API (same as auto-captions)
 * URL: https://www.youtube.com/api/timedtext?v=VIDEO_ID&lang=en&fmt=srv3
 *
 * LLM APIs supported:
 *   Groq:       https://api.groq.com/openai/v1/chat/completions
 *   OpenRouter: https://openrouter.ai/api/v1/chat/completions
 *   Custom:     any OpenAI-compatible endpoint
 *
 * Build: make package ENABLE_AI_SUMMARY=1
 */

#import "AISummary.h"

// ──────────────────────────────────────────────
// MARK: - API Endpoints
// ──────────────────────────────────────────────

static NSString *const kGroqEndpoint = @"https://api.groq.com/openai/v1/chat/completions";
static NSString *const kGroqModel = @"llama-3.1-8b-instant";

static NSString *const kOpenRouterEndpoint = @"https://openrouter.ai/api/v1/chat/completions";
static NSString *const kOpenRouterModel = @"meta-llama/llama-3.1-8b-instruct:free";

static NSString *const kSystemPrompt =
    @"You are a helpful assistant that summarizes YouTube video transcripts. "
    @"Provide a concise summary in 3-5 bullet points. Each bullet should be one clear sentence. "
    @"If the transcript is in a non-English language, summarize in that language. "
    @"Start directly with the bullet points, no introduction.";

// ──────────────────────────────────────────────
// MARK: - Manager Implementation
// ──────────────────────────────────────────────

@implementation YTLAISummaryManager

+ (instancetype)sharedInstance {
    static YTLAISummaryManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        instance.provider = (YTLAIProvider)[[YTLUserDefaults standardUserDefaults] integerForKey:@"aiProvider"];
        instance.apiKey = [[YTLUserDefaults standardUserDefaults] objectForKey:@"aiApiKey"];
        instance.customEndpoint = [[YTLUserDefaults standardUserDefaults] objectForKey:@"aiCustomEndpoint"];
    });
    return instance;
}

- (void)summarizeVideoWithID:(NSString *)videoID
              fromController:(UIViewController *)presenter {
    if (!videoID || videoID.length == 0) {
        [self showError:@"No video ID" presenter:presenter];
        return;
    }
    
    if (!self.apiKey || self.apiKey.length == 0) {
        [self showError:LOC(@"AISummaryNoKey") presenter:presenter];
        return;
    }
    
    // Show loading toast
    [[%c(YTToastResponderEvent) eventWithMessage:LOC(@"AISummaryLoading")
                                  firstResponder:presenter] send];
    
    // Step 1: Fetch transcript
    [self fetchTranscriptForVideoID:videoID completion:^(NSString *transcript, NSError *error) {
        if (error || !transcript || transcript.length < 50) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self showError:LOC(@"AISummaryNoTranscript") presenter:presenter];
            });
            return;
        }
        
        // Truncate to ~4000 words to stay within token limits
        NSArray *words = [transcript componentsSeparatedByString:@" "];
        if (words.count > 4000) {
            transcript = [[words subarrayWithRange:NSMakeRange(0, 4000)] componentsJoinedByString:@" "];
        }
        
        // Step 2: Generate summary via LLM
        [self generateSummaryFromTranscript:transcript completion:^(NSString *summary, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error || !summary) {
                    [self showError:[NSString stringWithFormat:@"%@: %@", LOC(@"Error"), error.localizedDescription ?: @"Unknown"] presenter:presenter];
                    return;
                }
                
                [self showSummary:summary presenter:presenter];
            });
        }];
    }];
}

// ──────────────────────────────────────────────
// MARK: - Transcript Fetching
// ──────────────────────────────────────────────

- (void)fetchTranscriptForVideoID:(NSString *)videoID
                       completion:(void (^)(NSString *, NSError *))completion {
    // Try English first, then auto-detect
    NSArray *langs = @[@"en", @"ko", @"ja", @"de", @"fr", @"es", @"pt", @"ru", @"zh"];
    
    [self tryFetchTranscriptForVideoID:videoID languages:langs index:0 completion:completion];
}

- (void)tryFetchTranscriptForVideoID:(NSString *)videoID
                           languages:(NSArray *)langs
                               index:(NSUInteger)index
                          completion:(void (^)(NSString *, NSError *))completion {
    if (index >= langs.count) {
        completion(nil, [NSError errorWithDomain:@"YTLite" code:404 userInfo:@{NSLocalizedDescriptionKey: @"No captions found"}]);
        return;
    }
    
    NSString *lang = langs[index];
    NSString *urlStr = [NSString stringWithFormat:
        @"https://www.youtube.com/api/timedtext?v=%@&lang=%@&fmt=srv3", videoID, lang];
    
    NSURL *url = [NSURL URLWithString:urlStr];
    NSURLSession *session = [NSURLSession sharedSession];
    
    [[session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        
        if (error || httpResponse.statusCode != 200 || !data || data.length < 100) {
            // Try next language
            [self tryFetchTranscriptForVideoID:videoID languages:langs index:index + 1 completion:completion];
            return;
        }
        
        // Parse XML captions → plain text
        NSString *xml = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSString *transcript = [self parseTranscriptXML:xml];
        
        if (transcript.length > 50) {
            completion(transcript, nil);
        } else {
            [self tryFetchTranscriptForVideoID:videoID languages:langs index:index + 1 completion:completion];
        }
    }] resume];
}

- (NSString *)parseTranscriptXML:(NSString *)xml {
    if (!xml) return @"";
    
    // Simple regex extraction of text between <p> or <text> tags
    NSMutableString *result = [NSMutableString string];
    
    // Pattern: <p ...>TEXT</p> or <text ...>TEXT</text>
    NSRegularExpression *regex = [NSRegularExpression
        regularExpressionWithPattern:@"<(?:p|text)[^>]*>([^<]+)</(?:p|text)>"
        options:0 error:nil];
    
    NSArray *matches = [regex matchesInString:xml options:0 range:NSMakeRange(0, xml.length)];
    
    for (NSTextCheckingResult *match in matches) {
        if (match.numberOfRanges >= 2) {
            NSString *text = [xml substringWithRange:[match rangeAtIndex:1]];
            // Decode HTML entities
            text = [text stringByReplacingOccurrencesOfString:@"&amp;" withString:@"&"];
            text = [text stringByReplacingOccurrencesOfString:@"&lt;" withString:@"<"];
            text = [text stringByReplacingOccurrencesOfString:@"&gt;" withString:@">"];
            text = [text stringByReplacingOccurrencesOfString:@"&#39;" withString:@"'"];
            text = [text stringByReplacingOccurrencesOfString:@"&quot;" withString:@"\""];
            text = [text stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
            
            [result appendFormat:@"%@ ", text];
        }
    }
    
    return [result stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

// ──────────────────────────────────────────────
// MARK: - LLM API Call
// ──────────────────────────────────────────────

- (void)generateSummaryFromTranscript:(NSString *)transcript
                           completion:(void (^)(NSString *, NSError *))completion {
    NSString *endpoint;
    NSString *model;
    
    switch (self.provider) {
        case YTLAIProviderGroq:
            endpoint = kGroqEndpoint;
            model = kGroqModel;
            break;
        case YTLAIProviderOpenRouter:
            endpoint = kOpenRouterEndpoint;
            model = kOpenRouterModel;
            break;
        case YTLAIProviderCustom:
            endpoint = self.customEndpoint ?: kGroqEndpoint;
            model = @"default";
            break;
    }
    
    NSDictionary *body = @{
        @"model": model,
        @"messages": @[
            @{@"role": @"system", @"content": kSystemPrompt},
            @{@"role": @"user", @"content": [NSString stringWithFormat:@"Summarize this video transcript:\n\n%@", transcript]}
        ],
        @"max_tokens": @(500),
        @"temperature": @(0.3)
    };
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:endpoint]];
    request.HTTPMethod = @"POST";
    request.HTTPBody = jsonData;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", self.apiKey] forHTTPHeaderField:@"Authorization"];
    
    if (self.provider == YTLAIProviderOpenRouter) {
        [request setValue:@"YouTubePlus-iOS" forHTTPHeaderField:@"X-Title"];
    }
    
    request.timeoutInterval = 30.0;
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            completion(nil, error);
            return;
        }
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        
        NSString *content = json[@"choices"][0][@"message"][@"content"];
        if (content) {
            completion(content, nil);
        } else {
            NSString *errMsg = json[@"error"][@"message"] ?: @"Invalid API response";
            completion(nil, [NSError errorWithDomain:@"YTLite" code:500 userInfo:@{NSLocalizedDescriptionKey: errMsg}]);
        }
    }] resume];
}

// ──────────────────────────────────────────────
// MARK: - UI Presentation
// ──────────────────────────────────────────────

- (void)showSummary:(NSString *)summary presenter:(UIViewController *)presenter {
    YTAlertView *alert = [%c(YTAlertView) infoDialog];
    alert.title = LOC(@"AISummary");
    alert.subtitle = summary;
    [alert show];
}

- (void)showError:(NSString *)message presenter:(UIViewController *)presenter {
    [[%c(YTToastResponderEvent) eventWithMessage:message firstResponder:presenter] send];
}

@end

// ──────────────────────────────────────────────
// MARK: - UI Integration
// The AI Summary button is added via the core YTLite.x
// YTEngagementPanelView hook (guarded by #ifdef ENABLE_AI_SUMMARY)
// to avoid hook conflicts with other modules.
// ──────────────────────────────────────────────
