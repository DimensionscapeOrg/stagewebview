#pragma once

#include <climits>
#include <string>

#if defined(_WIN32)
#include "vendor/webview.h"

#include <wrl.h>

#include "windows/WebView2.h"
#endif

namespace stagewebview {

struct WebViewCallbackSet
{
	void *userData = nullptr;
	bool (*onLocationChanging)(void *userData, const std::string &location) = nullptr;
	void (*onLocationChange)(void *userData, const std::string &location) = nullptr;
	void (*onComplete)(void *userData) = nullptr;
	void (*onError)(void *userData, const std::string &message) = nullptr;
	void (*onFocusIn)(void *userData) = nullptr;
	void (*onFocusOut)(void *userData) = nullptr;
	void (*onMessage)(void *userData, const std::string &message) = nullptr;
};

struct WebViewCreateOptions
{
	int mediaPlaybackRequiresUserAction = -1;
	std::string userAgent;
	int enableContextMenu = -1;
	int enableKeyboardShortcuts = -1;
	int enableDevTools = -1;
	int enableStatusBar = -1;
	int enableZoom = -1;
	int startHidden = -1;
};

// Page geometry for printToPdf, in inches. A value below zero keeps the platform default.
struct WebViewPdfOptions
{
	double pageWidth = -1;
	double pageHeight = -1;
	double marginTop = -1;
	double marginRight = -1;
	double marginBottom = -1;
	double marginLeft = -1;
	int landscape = -1;
	int printBackground = -1;
	double scale = -1;
	// WebKit engines only (Linux, macOS, iOS): split tables at page breaks and repeat their thead, which
	// WebKit's print layout does not do. Chromium engines repeat thead natively and ignore this.
	int repeatTableHeaders = -1;
};

// Called once per printToPdf request, from the platform event loop on the thread that pumps it (never from
// inside the engine's own handler), so it may dispose the webview or create another.
typedef void (*WebViewPdfCallback)(void *userData, bool success, const std::string &message);

#if !defined(_WIN32)
class PlatformWebView;
#endif

class WebViewBackend
{
public:
	static WebViewBackend *create(int debug, void *window, const WebViewCreateOptions &options = {});
	~WebViewBackend();

	int setSize(int width, int height, int hints);
	int navigate(const char *url);
	int setHtml(const char *html);
	int addInitScript(const char *script);
	int evaluateJavaScript(const char *script);
	void setCallbacks(const WebViewCallbackSet &value);
	int historyBack();
	int historyForward();
	int reload();
	int stop();
	int run();
	int terminate();
	int setTitle(const char *title);
	int postMessage(const char *message);
	int assignFocus(int direction);
	int canGoBack() const;
	int canGoForward() const;
	std::string capturePreviewBase64(int format) const;
	std::string getLocation() const;
	std::string getTitle() const;
	void *getNativeHandle(int kind) const;
	int printToPdf(const char *path, const WebViewPdfOptions &options, WebViewPdfCallback callback, void *userData);

	static void webView2ControllerSetBounds(void *controllerHandle, int width, int height);
	static int processEvents();
	static bool isSupported();

private:
	WebViewBackend() = default;

	bool notifyLocationChanging(const std::string &location) const;
	void notifyLocationChange(const std::string &location) const;
	void notifyComplete() const;
	void notifyError(const std::string &message) const;
	void notifyFocusIn() const;
	void notifyFocusOut() const;
	void notifyMessage(const std::string &message) const;

	#if defined(_WIN32)
	void applySettings();
	static std::string wideToUtf8(const wchar_t *value);
	void cacheNativeHandles();
	void registerEvents();
	void unregisterEvents();
	#endif

	#if defined(_WIN32)
	webview_t handle = nullptr;
	#else
	PlatformWebView *platform = nullptr;
	#endif
	WebViewCallbackSet callbacks;
	WebViewCreateOptions createOptions;

	#if defined(_WIN32)
	HWND hiddenHost = nullptr;
	ICoreWebView2Controller *controller = nullptr;
	ICoreWebView2 *core = nullptr;

	EventRegistrationToken navigationStartingToken{};
	EventRegistrationToken sourceChangedToken{};
	EventRegistrationToken navigationCompletedToken{};
	EventRegistrationToken gotFocusToken{};
	EventRegistrationToken lostFocusToken{};
	EventRegistrationToken messageReceivedToken{};

	bool hasNavigationStarting = false;
	bool hasSourceChanged = false;
	bool hasNavigationCompleted = false;
	bool hasGotFocus = false;
	bool hasLostFocus = false;
	bool hasMessageReceived = false;
	#endif
};

} // namespace stagewebview
