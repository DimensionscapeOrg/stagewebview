// macOS and iOS engine: one WKWebView implementation for both. Compiled with ARC.
//
// webview.h's Cocoa backend is not used here: given a host window it replaces that window's content
// view, which would remove SDL's view, and it has no iOS backend. Everything it would provide (user
// scripts, a script message handler, evaluate, load) is a few WKWebView calls.
#import <TargetConditionals.h>
#import <WebKit/WebKit.h>

#if TARGET_OS_IPHONE
#import <UIKit/UIKit.h>
typedef UIView PlatformView;
#else
#import <Cocoa/Cocoa.h>
typedef NSView PlatformView;
#endif

#include <string>
#include <utility>

#include "../PlatformWebView.h"

namespace stagewebview {
class ApplePlatformWebView;
}

static NSString *const MESSAGE_HANDLER = @"stagewebview";
static const CGFloat HIDDEN_WIDTH = 1024;
static const CGFloat HIDDEN_HEIGHT = 1366;

// One printToPdf request, kept alive until the platform reports back.
@interface StageWebViewPdfJob : NSObject
@property(nonatomic, assign) stagewebview::WebViewPdfCallback callback;
@property(nonatomic, assign) void *userData;
@property(nonatomic, assign) stagewebview::WebViewPdfOptions options;
@property(nonatomic, strong) NSURL *url;
@property(nonatomic, assign) BOOL tablesSplit;
@end

@implementation StageWebViewPdfJob
@end

// Receives WKWebView navigation callbacks and page messages for one ApplePlatformWebView.
@interface StageWebViewDelegate : NSObject <WKNavigationDelegate, WKScriptMessageHandler>
@property(nonatomic, assign) stagewebview::ApplePlatformWebView *owner;
@end

namespace stagewebview {

class ApplePlatformWebView : public PlatformWebView
{
public:
	ApplePlatformWebView(int debug, void *window, const WebViewCreateOptions &options)
	{
		delegate = [StageWebViewDelegate new];
		delegate.owner = this;

		WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];
		WKUserContentController *content = configuration.userContentController;
		[content addScriptMessageHandler:delegate name:MESSAGE_HANDLER];

		std::string bridge = bridgeScript("function (message) { window.webkit.messageHandlers.stagewebview.postMessage(message); }");
		[content addUserScript:[[WKUserScript alloc] initWithSource:[NSString stringWithUTF8String:bridge.c_str()]
												injectionTime:WKUserScriptInjectionTimeAtDocumentStart
											 forMainFrameOnly:YES]];

		if (options.mediaPlaybackRequiresUserAction != -1)
		{
			configuration.mediaTypesRequiringUserActionForPlayback =
				options.mediaPlaybackRequiresUserAction == 1 ? WKAudiovisualMediaTypeAll : WKAudiovisualMediaTypeNone;
		}

		#if !TARGET_OS_IPHONE
		if (debug || options.enableDevTools == 1)
		{
			[configuration.preferences setValue:@YES forKey:@"developerExtrasEnabled"];
		}
		#endif

		PlatformView *host = (__bridge PlatformView *)window;
		CGRect frame = host != nil ? host.bounds : CGRectMake(0, 0, HIDDEN_WIDTH, HIDDEN_HEIGHT);
		view = [[WKWebView alloc] initWithFrame:frame configuration:configuration];
		view.navigationDelegate = delegate;

		if (@available(macOS 13.3, iOS 16.4, *))
		{
			if (debug || options.enableDevTools == 1)
			{
				view.inspectable = YES;
			}
		}

		if (!options.userAgent.empty())
		{
			view.customUserAgent = [NSString stringWithUTF8String:options.userAgent.c_str()];
		}

		if (host != nil)
		{
			// Embedded: fill the container the facade positions.
			#if TARGET_OS_IPHONE
			view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
			#else
			view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
			#endif
			[host addSubview:view];
			return;
		}

		#if TARGET_OS_IPHONE
		// iOS: an unattached view still loads, lays out and prints. A visible top-level window is not offered.
		(void)options;
		#else
		ensureApplication(options.startHidden != 1);

		NSRect rect = options.startHidden == 1 ? NSMakeRect(-20000, -20000, HIDDEN_WIDTH, HIDDEN_HEIGHT) : NSMakeRect(0, 0, 1024, 768);
		NSWindowStyleMask style = options.startHidden == 1
			? NSWindowStyleMaskBorderless
			: (NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable);
		ownedWindow = [[NSWindow alloc] initWithContentRect:rect styleMask:style backing:NSBackingStoreBuffered defer:NO];
		ownedWindow.releasedWhenClosed = NO;
		ownedWindow.contentView = view;

		// A hidden webview lives in a window that is never ordered in. WebKit printing on macOS runs
		// modally for a window, so it needs one even when nothing is shown.
		if (options.startHidden != 1)
		{
			[ownedWindow center];
			[ownedWindow makeKeyAndOrderFront:nil];
			[NSApp activateIgnoringOtherApps:YES];
		}
		#endif
	}

	~ApplePlatformWebView() override
	{
		[view stopLoading];
		[view.configuration.userContentController removeScriptMessageHandlerForName:MESSAGE_HANDLER];
		view.navigationDelegate = nil;
		delegate.owner = nullptr;
		[view removeFromSuperview];
		view = nil;

		#if !TARGET_OS_IPHONE
		if (ownedWindow != nil)
		{
			[ownedWindow orderOut:nil];
			ownedWindow.contentView = nil;
			[ownedWindow close];
			ownedWindow = nil;
		}
		#endif
	}

	int setSize(int width, int height, int hints) override
	{
		(void)hints;

		#if !TARGET_OS_IPHONE
		if (ownedWindow != nil)
		{
			[ownedWindow setContentSize:NSMakeSize(width, height)];
			return 0;
		}
		#endif

		if (view.superview == nil)
		{
			view.frame = CGRectMake(0, 0, width, height);
		}

		return 0;
	}

	int navigate(const char *url) override
	{
		NSString *text = [NSString stringWithUTF8String:url != nullptr && url[0] != '\0' ? url : "about:blank"];
		NSURL *target = [NSURL URLWithString:text];
		if (target == nil)
		{
			return -1;
		}

		if (target.isFileURL)
		{
			// Let the page read its siblings (stylesheets, images) next to it.
			[view loadFileURL:target allowingReadAccessToURL:target.URLByDeletingLastPathComponent];
		}
		else
		{
			[view loadRequest:[NSURLRequest requestWithURL:target]];
		}

		return 0;
	}

	int setHtml(const char *html) override
	{
		[view loadHTMLString:[NSString stringWithUTF8String:html != nullptr ? html : ""] baseURL:nil];
		return 0;
	}

	int addInitScript(const char *script) override
	{
		[view.configuration.userContentController addUserScript:[[WKUserScript alloc] initWithSource:[NSString stringWithUTF8String:script]
																					 injectionTime:WKUserScriptInjectionTimeAtDocumentStart
																				  forMainFrameOnly:YES]];
		return 0;
	}

	int evaluateJavaScript(const char *script) override
	{
		[view evaluateJavaScript:[NSString stringWithUTF8String:script] completionHandler:nil];
		return 0;
	}

	int historyBack() override
	{
		[view goBack];
		return 0;
	}

	int historyForward() override
	{
		[view goForward];
		return 0;
	}

	int reload() override
	{
		[view reload];
		return 0;
	}

	int stop() override
	{
		[view stopLoading];
		return 0;
	}

	int run() override
	{
		#if TARGET_OS_IPHONE
		return -1;
		#else
		[NSApp run];
		return 0;
		#endif
	}

	int terminate() override
	{
		#if TARGET_OS_IPHONE
		return -1;
		#else
		[NSApp stop:nil];
		// stop: only takes effect after the next event, so post one.
		NSEvent *event = [NSEvent otherEventWithType:NSEventTypeApplicationDefined location:NSZeroPoint modifierFlags:0 timestamp:0
										windowNumber:0 context:nil subtype:0 data1:0 data2:0];
		[NSApp postEvent:event atStart:YES];
		return 0;
		#endif
	}

	int setTitle(const char *title) override
	{
		#if TARGET_OS_IPHONE
		(void)title;
		return -1;
		#else
		if (ownedWindow == nil)
		{
			return -1;
		}

		ownedWindow.title = [NSString stringWithUTF8String:title];
		return 0;
		#endif
	}

	int assignFocus(int direction) override
	{
		(void)direction;

		#if TARGET_OS_IPHONE
		[view becomeFirstResponder];
		#else
		[view.window makeFirstResponder:view];
		#endif

		notifyFocusIn();
		return 0;
	}

	int canGoBack() const override
	{
		return view.canGoBack ? 1 : 0;
	}

	int canGoForward() const override
	{
		return view.canGoForward ? 1 : 0;
	}

	std::string capturePreviewBase64(int format) const override
	{
		__block BOOL done = NO;
		__block NSData *data = nil;

		[view takeSnapshotWithConfiguration:nil
						  completionHandler:^(id image, NSError *error) {
							  (void)error;
							  #if TARGET_OS_IPHONE
							  UIImage *snapshot = image;
							  data = snapshot == nil ? nil : (format == 1 ? UIImageJPEGRepresentation(snapshot, 0.9) : UIImagePNGRepresentation(snapshot));
							  #else
							  NSImage *snapshot = image;
							  CGImageRef cgImage = [snapshot CGImageForProposedRect:nil context:nil hints:nil];
							  if (cgImage != nullptr)
							  {
								  NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithCGImage:cgImage];
								  data = [bitmap representationUsingType:(format == 1 ? NSBitmapImageFileTypeJPEG : NSBitmapImageFileTypePNG) properties:@{}];
							  }
							  #endif
							  done = YES;
						  }];

		NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:10];
		while (!done && [deadline timeIntervalSinceNow] > 0)
		{
			[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
		}

		if (data == nil)
		{
			return std::string();
		}

		return base64Encode(static_cast<const unsigned char *>(data.bytes), data.length);
	}

	std::string getLocation() const override
	{
		NSString *location = view.URL.absoluteString;
		return location != nil ? location.UTF8String : "";
	}

	std::string getTitle() const override
	{
		NSString *title = view.title;
		return title != nil ? title.UTF8String : "";
	}

	void *getNativeHandle(int kind) const override
	{
		switch (kind)
		{
			case 0:
				return (__bridge void *)view.window;

			default:
				return (__bridge void *)view;
		}
	}

	int printToPdf(const char *path, const WebViewPdfOptions &options, WebViewPdfCallback callback, void *userData) override
	{
		StageWebViewPdfJob *job = [StageWebViewPdfJob new];
		job.callback = callback;
		job.userData = userData;
		job.options = options;
		job.url = [NSURL fileURLWithPath:[NSString stringWithUTF8String:path]];

		if (@available(macOS 13.3, iOS 16.4, *))
		{
			if (options.printBackground != -1)
			{
				view.configuration.preferences.shouldPrintBackgrounds = options.printBackground == 1;
			}
		}

		if (options.repeatTableHeaders == 0)
		{
			startPrint(job);
			return 0;
		}

		std::string script = tableHeaderScript(options, WEBKIT_PRINT_PIXELS_PER_INCH);
		[view evaluateJavaScript:[NSString stringWithUTF8String:script.c_str()]
			   completionHandler:^(id result, NSError *error) {
				   (void)result;
				   (void)error;
				   job.tablesSplit = YES;
				   startPrint(job);
			   }];
		return 0;
	}

	void finishPrint(StageWebViewPdfJob *job, bool success, const std::string &message)
	{
		if (job.tablesSplit)
		{
			evaluateJavaScript(tableHeaderRestoreScript().c_str());
		}

		// Report on a later turn of the main queue, outside WebKit's and AppKit's callbacks, so the callback
		// may dispose this webview or create another.
		std::string reported = message;
		dispatch_async(dispatch_get_main_queue(), ^{
			if (job.callback != nullptr)
			{
				job.callback(job.userData, success, reported);
			}
		});
	}

	// Called by StageWebViewDelegate.
	bool handleLocationChanging(const std::string &location)
	{
		return notifyLocationChanging(location);
	}

	void handleCommit()
	{
		notifyLocationChange(getLocation());
	}

	void handleFinish()
	{
		notifyComplete();
	}

	void handleError(NSError *error)
	{
		notifyError(std::string("Navigation failed: ") + (error.localizedDescription != nil ? error.localizedDescription.UTF8String : "unknown error"));
	}

	void handleMessage(id body)
	{
		if ([body isKindOfClass:[NSString class]])
		{
			notifyMessage(((NSString *)body).UTF8String);
		}
		else if (body != nil && [NSJSONSerialization isValidJSONObject:body])
		{
			NSData *json = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
			notifyMessage(std::string(static_cast<const char *>(json.bytes), json.length));
		}
		else if (body != nil)
		{
			notifyMessage([body description].UTF8String);
		}
	}

private:
	#if !TARGET_OS_IPHONE
	static void ensureApplication(bool visible)
	{
		NSApplication *application = [NSApplication sharedApplication];

		// A Lime/SDL host has already set itself up; a plain Haxe program has not.
		if (application.delegate == nil && !application.running)
		{
			static bool launched = false;
			if (!launched)
			{
				launched = true;
				[application setActivationPolicy:visible ? NSApplicationActivationPolicyRegular : NSApplicationActivationPolicyAccessory];
				[application finishLaunching];
			}
		}
	}
	#endif

	void startPrint(StageWebViewPdfJob *job)
	{
		const WebViewPdfOptions &options = job.options;
		double pageWidth = (options.pageWidth > 0 ? options.pageWidth : 8.5) * 72.0;
		double pageHeight = (options.pageHeight > 0 ? options.pageHeight : 11.0) * 72.0;
		double marginTop = (options.marginTop >= 0 ? options.marginTop : 0.4) * 72.0;
		double marginRight = (options.marginRight >= 0 ? options.marginRight : 0.4) * 72.0;
		double marginBottom = (options.marginBottom >= 0 ? options.marginBottom : 0.4) * 72.0;
		double marginLeft = (options.marginLeft >= 0 ? options.marginLeft : 0.4) * 72.0;
		if (options.landscape == 1)
		{
			std::swap(pageWidth, pageHeight);
		}

		#if TARGET_OS_IPHONE
		// UIKit printing renders synchronously into a PDF context; the result is reported on the next turn
		// of the run loop so callers see the same asynchronous contract as every other platform.
		UIPrintPageRenderer *renderer = [UIPrintPageRenderer new];
		[renderer addPrintFormatter:view.viewPrintFormatter startingAtPageAtIndex:0];
		CGRect paper = CGRectMake(0, 0, pageWidth, pageHeight);
		CGRect printable = CGRectMake(marginLeft, marginTop, pageWidth - marginLeft - marginRight, pageHeight - marginTop - marginBottom);
		[renderer setValue:[NSValue valueWithCGRect:paper] forKey:@"paperRect"];
		[renderer setValue:[NSValue valueWithCGRect:printable] forKey:@"printableRect"];

		NSMutableData *data = [NSMutableData data];
		UIGraphicsBeginPDFContextToData(data, paper, nil);
		NSInteger pages = renderer.numberOfPages;
		[renderer prepareForDrawingPages:NSMakeRange(0, pages)];
		for (NSInteger page = 0; page < pages; page++)
		{
			UIGraphicsBeginPDFPage();
			[renderer drawPageAtIndex:page inRect:UIGraphicsGetPDFContextBounds()];
		}
		UIGraphicsEndPDFContext();

		NSError *error = nil;
		BOOL written = pages > 0 && [data writeToURL:job.url options:NSDataWritingAtomic error:&error];
		std::string message = written ? "" : (error != nil ? error.localizedDescription.UTF8String : "UIPrintPageRenderer produced no pages");
		finishPrint(job, written, message);
		#else
		NSPrintInfo *info = [[NSPrintInfo alloc] initWithDictionary:@{
			NSPrintJobDisposition: NSPrintSaveJob,
			NSPrintJobSavingURL: job.url,
		}];
		info.paperSize = NSMakeSize(pageWidth, pageHeight);
		info.topMargin = marginTop;
		info.rightMargin = marginRight;
		info.bottomMargin = marginBottom;
		info.leftMargin = marginLeft;
		info.horizontalPagination = NSPrintingPaginationModeAutomatic;
		info.verticalPagination = NSPrintingPaginationModeAutomatic;
		info.horizontallyCentered = NO;
		info.verticallyCentered = NO;
		if (options.scale > 0)
		{
			info.dictionary[NSPrintScalingFactor] = @(options.scale);
		}

		NSPrintOperation *operation = [view printOperationWithPrintInfo:info];
		operation.showsPrintPanel = NO;
		operation.showsProgressPanel = NO;
		// WKWebView's print view starts with an empty frame; without one the output is blank.
		operation.view.frame = view.bounds;

		// WebKit renders print pages in its web process, so the operation must run modally for a window
		// (asynchronously) rather than through runOperation, which returns before pages arrive.
		if (view.window != nil)
		{
			[operation runOperationModalForWindow:view.window
										 delegate:delegate
								   didRunSelector:@selector(printOperationDidRun:success:contextInfo:)
									  contextInfo:(__bridge_retained void *)job];
		}
		else
		{
			BOOL success = [operation runOperation];
			finishPrint(job, success, success ? "" : "NSPrintOperation failed");
		}
		#endif
	}

	WKWebView *view = nil;
	StageWebViewDelegate *delegate = nil;
	#if !TARGET_OS_IPHONE
	NSWindow *ownedWindow = nil;
	#endif
};

PlatformWebView *createPlatformWebView(int debug, void *window, const WebViewCreateOptions &options)
{
	@autoreleasepool
	{
		return new ApplePlatformWebView(debug, window, options);
	}
}

int PlatformWebView::processEvents()
{
	int processed = 0;

	@autoreleasepool
	{
		#if !TARGET_OS_IPHONE
		NSApplication *application = [NSApplication sharedApplication];
		NSEvent *event = nil;
		while (processed < 1000
			&& (event = [application nextEventMatchingMask:NSEventMaskAny untilDate:[NSDate distantPast] inMode:NSDefaultRunLoopMode dequeue:YES]) != nil)
		{
			[application sendEvent:event];
			processed++;
		}
		#endif

		// Run loop sources (WebKit IPC replies, dispatch_async to the main queue) are not events.
		while (processed < 1000 && CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, true) == kCFRunLoopRunHandledSource)
		{
			processed++;
		}
	}

	return processed;
}

} // namespace stagewebview

@implementation StageWebViewDelegate

- (void)webView:(WKWebView *)webView
	decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
					decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler
{
	(void)webView;
	BOOL mainFrame = navigationAction.targetFrame == nil || navigationAction.targetFrame.isMainFrame;
	if (mainFrame && self.owner != nullptr)
	{
		NSString *location = navigationAction.request.URL.absoluteString;
		if (self.owner->handleLocationChanging(location != nil ? location.UTF8String : ""))
		{
			decisionHandler(WKNavigationActionPolicyCancel);
			return;
		}
	}

	decisionHandler(WKNavigationActionPolicyAllow);
}

- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation
{
	(void)webView;
	(void)navigation;
	if (self.owner != nullptr)
	{
		self.owner->handleCommit();
	}
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation
{
	(void)webView;
	(void)navigation;
	if (self.owner != nullptr)
	{
		self.owner->handleFinish();
	}
}

- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
	(void)webView;
	(void)navigation;
	if (self.owner != nullptr)
	{
		self.owner->handleError(error);
	}
}

- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error
{
	(void)webView;
	(void)navigation;
	if (self.owner != nullptr)
	{
		self.owner->handleError(error);
	}
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message
{
	(void)userContentController;
	if (self.owner != nullptr)
	{
		self.owner->handleMessage(message.body);
	}
}

#if !TARGET_OS_IPHONE
- (void)printOperationDidRun:(NSPrintOperation *)operation success:(BOOL)success contextInfo:(void *)contextInfo
{
	(void)operation;
	StageWebViewPdfJob *job = (__bridge_transfer StageWebViewPdfJob *)contextInfo;
	if (self.owner != nullptr)
	{
		self.owner->finishPrint(job, success, success ? "" : "NSPrintOperation failed");
	}
	else if (job.callback != nullptr)
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			job.callback(job.userData, false, "The webview was disposed while printing");
		});
	}
}
#endif

@end
