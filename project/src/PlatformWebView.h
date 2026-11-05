#pragma once

#include <string>

#include <stagewebview/WebViewBackend.h>

namespace stagewebview {

// Engine contract for every platform except Windows, which keeps its WebView2 code in WebViewBackend.cpp.
// One implementation is compiled per platform: gtk/GtkWebView.cpp, apple/AppleWebView.mm.
class PlatformWebView
{
public:
	virtual ~PlatformWebView() = default;

	virtual int setSize(int width, int height, int hints) = 0;
	virtual int navigate(const char *url) = 0;
	virtual int setHtml(const char *html) = 0;
	virtual int addInitScript(const char *script) = 0;
	virtual int evaluateJavaScript(const char *script, WebViewResultCallback callback, void *userData) = 0;
	virtual int historyBack() = 0;
	virtual int historyForward() = 0;
	virtual int reload() = 0;
	virtual int stop() = 0;
	virtual int run() = 0;
	virtual int terminate() = 0;
	virtual int setTitle(const char *title) = 0;
	virtual int assignFocus(int direction) = 0;
	virtual int canGoBack() const = 0;
	virtual int canGoForward() const = 0;
	virtual std::string capturePreviewBase64(int format) const = 0;
	virtual std::string getLocation() const = 0;
	virtual std::string getTitle() const = 0;
	virtual void *getNativeHandle(int kind) const = 0;
	virtual int printToPdf(const char *path, const WebViewPdfOptions &options, WebViewResultCallback callback, void *userData) = 0;

	// Sends a message to the page's window.chrome.webview listeners, matching WebView2's PostWebMessageAsString.
	int postMessage(const char *message);

	void setCallbacks(const WebViewCallbackSet &value)
	{
		callbacks = value;
	}

	// Pumps the platform loop once without blocking. Implemented per platform.
	static int processEvents();

	// Whether a webview can be created here. Implemented per platform.
	static bool isSupported();

protected:
	// Installs window.chrome.webview on pages that have no native WebView2 bridge.
	// postFunction is a JavaScript expression evaluating to function(string) that reaches the host.
	static std::string bridgeScript(const std::string &postFunction);
	static std::string jsonString(const std::string &value);

	// WebKit print layout does not repeat <thead> on each page. Before printing, these split every table
	// at the page boundaries computed from the PDF options and clone its header onto each continuation;
	// the restore script puts the page back afterwards. Both evaluate to the number of tables touched.
	// cssPixelsPerInch is the engine's print resolution: WebKit lays pages out at its minimum shrink
	// factor of 1.25, so one printed inch holds 72 * 1.25 = 90 CSS pixels rather than 96.
	static constexpr double WEBKIT_PRINT_PIXELS_PER_INCH = 90.0;
	static std::string tableHeaderScript(const WebViewPdfOptions &options, double cssPixelsPerInch);
	static std::string tableHeaderRestoreScript();

	bool notifyLocationChanging(const std::string &location)
	{
		// The page from setHtml is the application's own, so there is nothing to ask. WebKit calls it about:blank.
		if (loadingHtml && location == "about:blank")
		{
			loadingHtml = false;
			return false;
		}

		return callbacks.onLocationChanging != nullptr ? callbacks.onLocationChanging(callbacks.userData, location) : false;
	}

	void notifyLocationChange(const std::string &location) const
	{
		if (callbacks.onLocationChange != nullptr)
		{
			callbacks.onLocationChange(callbacks.userData, location);
		}
	}

	void notifyComplete() const
	{
		if (callbacks.onComplete != nullptr)
		{
			callbacks.onComplete(callbacks.userData);
		}
	}

	void notifyError(const std::string &message) const
	{
		if (callbacks.onError != nullptr)
		{
			callbacks.onError(callbacks.userData, message);
		}
	}

	void notifyFocusIn() const
	{
		if (callbacks.onFocusIn != nullptr)
		{
			callbacks.onFocusIn(callbacks.userData);
		}
	}

	void notifyFocusOut() const
	{
		if (callbacks.onFocusOut != nullptr)
		{
			callbacks.onFocusOut(callbacks.userData);
		}
	}

	void notifyMessage(const std::string &message) const
	{
		if (callbacks.onMessage != nullptr)
		{
			callbacks.onMessage(callbacks.userData, message);
		}
	}

	static std::string base64Encode(const unsigned char *data, size_t length);

	WebViewCallbackSet callbacks;
	bool loadingHtml = false;
};

PlatformWebView *createPlatformWebView(int debug, void *window, const WebViewCreateOptions &options);

} // namespace stagewebview
