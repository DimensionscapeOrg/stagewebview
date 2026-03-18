#pragma once

#include <climits>
#include <string>

#include "vendor/webview.h"

#if defined(_WIN32)
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
};

class WebViewBackend
{
public:
	static WebViewBackend *create(int debug, void *window, const WebViewCreateOptions &options = {});
	~WebViewBackend();

	int setSize(int width, int height, int hints);
	int navigate(const char *url);
	int setHtml(const char *html);
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

	static void webView2ControllerSetBounds(void *controllerHandle, int width, int height);

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

	webview_t handle = nullptr;
	WebViewCallbackSet callbacks;
	WebViewCreateOptions createOptions;

	#if defined(_WIN32)
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
