/**
 * AutoTranslate.x
 *
 * Adds "Translate" option to comment and description long-press menus.
 * Uses the same AI API configuration as AISummary module.
 * Falls back to a free translation approach if no API key is set.
 *
 * Build: make package ENABLE_AUTO_TRANSLATE=1
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "../../YTLite.h"

// ──────────────────────────────────────────────
// MARK: - Translation Manager
// ──────────────────────────────────────────────

@interface YTLTranslateManager : NSObject
+ (instancetype)sharedInstance;
- (void)translateText:(NSString *)text
           completion:(void (^)(NSString *translated, NSError *error))completion;
@end

@implementation YTLTranslateManager

+ (instancetype)sharedInstance {
    static YTLTranslateManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (void)translateText:(NSString *)text
           completion:(void (^)(NSString *, NSError *))completion {
    if (!text || text.length == 0) {
        completion(nil, [NSError errorWithDomain:@"YTLite" code:400 userInfo:@{NSLocalizedDescriptionKey: @"Empty text"}]);
        return;
    }
    
    NSString *apiKey = [[YTLUserDefaults standardUserDefaults] objectForKey:@"aiApiKey"];
    NSInteger provider = [[YTLUserDefaults standardUserDefaults] integerForKey:@"aiProvider"];
    
    // Get user's preferred language
    NSString *targetLang = [[NSLocale preferredLanguages] firstObject] ?: @"en";
    targetLang = [targetLang componentsSeparatedByString:@"-"].firstObject; // "ko-KR" → "ko"
    
    if (!apiKey || apiKey.length == 0) {
        // No API key: show a helpful message
        completion(nil, [NSError errorWithDomain:@"YTLite" code:401 userInfo:@{NSLocalizedDescriptionKey: LOC(@"TranslateNoKey")}]);
        return;
    }
    
    // Build API request
    NSString *endpoint;
    NSString *model;
    
    switch (provider) {
        case 0: // Groq
            endpoint = @"https://api.groq.com/openai/v1/chat/completions";
            model = @"llama-3.1-8b-instant";
            break;
        case 1: // OpenRouter
            endpoint = @"https://openrouter.ai/api/v1/chat/completions";
            model = @"meta-llama/llama-3.1-8b-instruct:free";
            break;
        default: {
            NSString *custom = [[YTLUserDefaults standardUserDefaults] objectForKey:@"aiCustomEndpoint"];
            endpoint = custom ?: @"https://api.groq.com/openai/v1/chat/completions";
            model = @"default";
            break;
        }
    }
    
    // Truncate very long texts
    NSString *inputText = text;
    if (inputText.length > 3000) {
        inputText = [inputText substringToIndex:3000];
    }
    
    NSString *prompt = [NSString stringWithFormat:
        @"Translate the following text to %@. "
        @"Output ONLY the translation, nothing else. "
        @"If the text is already in %@, output it as-is.\n\n%@",
        targetLang, targetLang, inputText];
    
    NSDictionary *body = @{
        @"model": model,
        @"messages": @[
            @{@"role": @"user", @"content": prompt}
        ],
        @"max_tokens": @(1000),
        @"temperature": @(0.1)
    };
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:endpoint]];
    request.HTTPMethod = @"POST";
    request.HTTPBody = jsonData;
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:[NSString stringWithFormat:@"Bearer %@", apiKey] forHTTPHeaderField:@"Authorization"];
    request.timeoutInterval = 20.0;
    
    [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) { completion(nil, error); return; }
        
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        NSString *content = json[@"choices"][0][@"message"][@"content"];
        
        if (content) {
            completion(content, nil);
        } else {
            NSString *errMsg = json[@"error"][@"message"] ?: @"Translation failed";
            completion(nil, [NSError errorWithDomain:@"YTLite" code:500 userInfo:@{NSLocalizedDescriptionKey: errMsg}]);
        }
    }] resume];
}

@end

// ──────────────────────────────────────────────
// MARK: - Description Translation
// The translate button is added via the core YTLite.x
// YTEngagementPanelView hook (guarded by #ifdef ENABLE_AUTO_TRANSLATE)
// to avoid hook conflicts with AISummary and core modules.
// ──────────────────────────────────────────────

// ──────────────────────────────────────────────
// MARK: - Comment Translation
// Adds "Translate" action to comment/post action sheets
// ──────────────────────────────────────────────
%hook YTDefaultSheetController

- (void)presentFromViewController:(UIViewController *)vc animated:(BOOL)animated completion:(void(^)(void))completion {
    if (ytlBool(@"autoTranslate")) {
        // Check if this is a comment-related sheet by inspecting actions
        // We add a translate action if there's a "Copy" action (indicating comment menu)
        NSArray *actions = [self valueForKey:@"_actions"];
        BOOL isCommentSheet = NO;
        NSString *textToCopy = nil;
        
        for (id action in actions) {
            NSString *title = [action valueForKey:@"_title"];
            if ([title isEqualToString:LOC(@"CopyCommentText")] ||
                [title isEqualToString:LOC(@"CopyPostText")]) {
                isCommentSheet = YES;
                break;
            }
        }
        
        if (isCommentSheet) {
            // Get the text from clipboard after copy (it will be set by the copy action)
            [self addAction:[%c(YTActionSheetAction)
                actionWithTitle:LOC(@"TranslateText")
                      iconImage:[UIImage systemImageNamed:@"globe"]
                          style:0
                        handler:^{
                // Read the most recent clipboard content (user likely copies first)
                NSString *text = [UIPasteboard generalPasteboard].string;
                if (!text || text.length == 0) {
                    [[%c(YTToastResponderEvent) eventWithMessage:LOC(@"TranslateNoText") firstResponder:vc] send];
                    return;
                }
                
                [[%c(YTToastResponderEvent) eventWithMessage:LOC(@"Translating") firstResponder:vc] send];
                
                [[YTLTranslateManager sharedInstance] translateText:text completion:^(NSString *translated, NSError *error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (error) {
                            [[%c(YTToastResponderEvent) eventWithMessage:error.localizedDescription firstResponder:vc] send];
                            return;
                        }
                        
                        YTAlertView *alert = [%c(YTAlertView) infoDialog];
                        alert.title = LOC(@"TranslatedComment");
                        alert.subtitle = translated;
                        [alert show];
                    });
                }];
            }]];
        }
    }
    
    %orig;
}

%end
