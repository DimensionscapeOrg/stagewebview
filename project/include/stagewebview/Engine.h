#pragma once

// The Linux engine as a library of its own, ndll/Linux64/stagewebview-gtk.so.
//
// A framework's binary that every program loads cannot link WebKitGTK: without it on the system, no program could start.
// Such a framework builds src/EngineClient.cpp in place of the engine's sources, and it opens this library when a webview
// is first asked for. Only C crosses here, and the framework needs no GTK or WebKitGTK to build.

#define STAGEWEBVIEW_ENGINE_VERSION 1

#ifdef __cplusplus
extern "C" {
#endif

typedef void (*StageWebViewResultCallback)(void *userData, int success, const char *message);

typedef struct StageWebViewEngineCallbacks
{
	void *userData;
	int (*onLocationChanging)(void *userData, const char *location);
	void (*onLocationChange)(void *userData, const char *location);
	void (*onComplete)(void *userData);
	void (*onError)(void *userData, const char *message);
	void (*onFocusIn)(void *userData);
	void (*onFocusOut)(void *userData);
	void (*onMessage)(void *userData, const char *message);
} StageWebViewEngineCallbacks;

typedef struct StageWebViewEngineOptions
{
	int mediaPlaybackRequiresUserAction;
	const char *userAgent;
	int enableContextMenu;
	int enableKeyboardShortcuts;
	int enableDevTools;
	int enableStatusBar;
	int enableZoom;
	int startHidden;
} StageWebViewEngineOptions;

typedef struct StageWebViewEnginePdfOptions
{
	double pageWidth;
	double pageHeight;
	double marginTop;
	double marginRight;
	double marginBottom;
	double marginLeft;
	int landscape;
	int printBackground;
	double scale;
	int repeatTableHeaders;
} StageWebViewEnginePdfOptions;

// What returns a char * leaves it to be released with freeString.
typedef struct StageWebViewEngine
{
	int version;
	int (*isSupported)(void);
	int (*processEvents)(void);
	void (*freeString)(char *value);

	void *(*create)(int debug, void *window, const StageWebViewEngineOptions *options);
	void (*destroy)(void *view);
	void (*setCallbacks)(void *view, const StageWebViewEngineCallbacks *callbacks);
	int (*setSize)(void *view, int width, int height, int hints);
	int (*navigate)(void *view, const char *url);
	int (*setHtml)(void *view, const char *html);
	int (*addInitScript)(void *view, const char *script);
	int (*evaluateJavaScript)(void *view, const char *script, StageWebViewResultCallback callback, void *userData);
	int (*historyBack)(void *view);
	int (*historyForward)(void *view);
	int (*reload)(void *view);
	int (*stop)(void *view);
	int (*run)(void *view);
	int (*terminate)(void *view);
	int (*setTitle)(void *view, const char *title);
	int (*assignFocus)(void *view, int direction);
	int (*canGoBack)(void *view);
	int (*canGoForward)(void *view);
	char *(*capturePreviewBase64)(void *view, int format);
	char *(*getLocation)(void *view);
	char *(*getTitle)(void *view);
	void *(*getNativeHandle)(void *view, int kind);
	int (*printToPdf)(void *view, const char *path, const StageWebViewEnginePdfOptions *options, StageWebViewResultCallback callback,
		void *userData);

	void *(*windowCreateChildWindow)(void *parent, int x, int y, int width, int height);
	void (*windowShow)(void *handle);
	void (*windowHide)(void *handle);
	void (*windowDestroy)(void *handle);
	void (*windowMove)(void *handle, int x, int y, int width, int height);
	void (*windowSetFocus)(void *handle);
} StageWebViewEngine;

// The one symbol the library exports.
const StageWebViewEngine *stagewebview_engine(void);

#ifdef __cplusplus
}
#endif
