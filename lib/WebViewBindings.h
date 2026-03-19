#pragma once

#include <hxcpp.h>

namespace stagewebview {

class HxcppWebViewBindings
{
public:
	static void *create(int debug, void *window, const char *userAgent, int mediaPlaybackRequiresUserAction, int enableContextMenu, int enableKeyboardShortcuts,
		int enableDevTools, int enableStatusBar, int enableZoom);
	static void destroy(void *w);
	static int setSize(void *w, int width, int height, int hints);
	static int navigate(void *w, const char *url);
	static int setHtml(void *w, const char *html);
	static int addInitScript(void *w, const char *script);
	static int evaluateJavaScript(void *w, const char *script);
	static void setCallbacks(void *w, Dynamic onLocationChanging, Dynamic onLocationChange, Dynamic onComplete, Dynamic onError, Dynamic onFocusIn,
		Dynamic onFocusOut, Dynamic onMessage);
	static int historyBack(void *w);
	static int historyForward(void *w);
	static int reload(void *w);
	static int stop(void *w);
	static int run(void *w);
	static int terminate(void *w);
	static int setTitle(void *w, const char *title);
	static int postMessage(void *w, const char *message);
	static int assignFocus(void *w, int direction);
	static int canGoBack(void *w);
	static int canGoForward(void *w);
	static String capturePreviewBase64(void *w, int format);
	static String getLocation(void *w);
	static String getTitle(void *w);
	static void *getNativeHandle(void *w, int kind);
	static void webView2ControllerSetBounds(void *controller, int width, int height);
};

} // namespace stagewebview
