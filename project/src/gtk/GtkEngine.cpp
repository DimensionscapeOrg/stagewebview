// The exports of stagewebview-gtk.so: see stagewebview/Engine.h. build-gtk-engine.sh builds this with the engine's sources.
#include <cstdlib>
#include <cstring>
#include <string>

#include <stagewebview/Engine.h>
#include <stagewebview/WebViewBackend.h>
#include <stagewebview/WindowBackend.h>

#include "GtkSupport.h"

using namespace stagewebview;

namespace {

struct EngineView
{
	WebViewBackend *backend;
	StageWebViewEngineCallbacks callbacks;
};

struct EngineRequest
{
	StageWebViewResultCallback callback;
	void *userData;
};

WebViewBackend *backendOf(void *view)
{
	return static_cast<EngineView *>(view)->backend;
}

char *copyOf(const std::string &value)
{
	return strdup(value.c_str());
}

void onResult(void *userData, bool success, const std::string &message)
{
	auto *request = static_cast<EngineRequest *>(userData);
	request->callback(request->userData, success ? 1 : 0, message.c_str());
	delete request;
}

bool onLocationChanging(void *userData, const std::string &location)
{
	auto *callbacks = &static_cast<EngineView *>(userData)->callbacks;
	return callbacks->onLocationChanging != nullptr && callbacks->onLocationChanging(callbacks->userData, location.c_str()) != 0;
}

void onLocationChange(void *userData, const std::string &location)
{
	auto *callbacks = &static_cast<EngineView *>(userData)->callbacks;
	if (callbacks->onLocationChange != nullptr)
	{
		callbacks->onLocationChange(callbacks->userData, location.c_str());
	}
}

void onComplete(void *userData)
{
	auto *callbacks = &static_cast<EngineView *>(userData)->callbacks;
	if (callbacks->onComplete != nullptr)
	{
		callbacks->onComplete(callbacks->userData);
	}
}

void onError(void *userData, const std::string &message)
{
	auto *callbacks = &static_cast<EngineView *>(userData)->callbacks;
	if (callbacks->onError != nullptr)
	{
		callbacks->onError(callbacks->userData, message.c_str());
	}
}

void onFocusIn(void *userData)
{
	auto *callbacks = &static_cast<EngineView *>(userData)->callbacks;
	if (callbacks->onFocusIn != nullptr)
	{
		callbacks->onFocusIn(callbacks->userData);
	}
}

void onFocusOut(void *userData)
{
	auto *callbacks = &static_cast<EngineView *>(userData)->callbacks;
	if (callbacks->onFocusOut != nullptr)
	{
		callbacks->onFocusOut(callbacks->userData);
	}
}

void onMessage(void *userData, const std::string &message)
{
	auto *callbacks = &static_cast<EngineView *>(userData)->callbacks;
	if (callbacks->onMessage != nullptr)
	{
		callbacks->onMessage(callbacks->userData, message.c_str());
	}
}

int engineIsSupported()
{
	return WebViewBackend::isSupported() ? 1 : 0;
}

int engineProcessEvents()
{
	return WebViewBackend::processEvents();
}

void engineFreeString(char *value)
{
	std::free(value);
}

void *engineCreate(int debug, void *window, const StageWebViewEngineOptions *options)
{
	WebViewCreateOptions created;
	created.mediaPlaybackRequiresUserAction = options->mediaPlaybackRequiresUserAction;
	created.userAgent = options->userAgent != nullptr ? options->userAgent : "";
	created.enableContextMenu = options->enableContextMenu;
	created.enableKeyboardShortcuts = options->enableKeyboardShortcuts;
	created.enableDevTools = options->enableDevTools;
	created.enableStatusBar = options->enableStatusBar;
	created.enableZoom = options->enableZoom;
	created.startHidden = options->startHidden;

	WebViewBackend *backend = WebViewBackend::create(debug, window, created);
	if (backend == nullptr)
	{
		return nullptr;
	}

	auto *view = new EngineView();
	view->backend = backend;
	std::memset(&view->callbacks, 0, sizeof(view->callbacks));

	WebViewCallbackSet callbacks;
	callbacks.userData = view;
	callbacks.onLocationChanging = onLocationChanging;
	callbacks.onLocationChange = onLocationChange;
	callbacks.onComplete = onComplete;
	callbacks.onError = onError;
	callbacks.onFocusIn = onFocusIn;
	callbacks.onFocusOut = onFocusOut;
	callbacks.onMessage = onMessage;
	backend->setCallbacks(callbacks);
	return view;
}

void engineDestroy(void *view)
{
	delete backendOf(view);
	delete static_cast<EngineView *>(view);
}

void engineSetCallbacks(void *view, const StageWebViewEngineCallbacks *callbacks)
{
	static_cast<EngineView *>(view)->callbacks = *callbacks;
}

int engineSetSize(void *view, int width, int height, int hints)
{
	return backendOf(view)->setSize(width, height, hints);
}

int engineNavigate(void *view, const char *url)
{
	return backendOf(view)->navigate(url);
}

int engineSetHtml(void *view, const char *html)
{
	return backendOf(view)->setHtml(html);
}

int engineAddInitScript(void *view, const char *script)
{
	return backendOf(view)->addInitScript(script);
}

int engineEvaluateJavaScript(void *view, const char *script, StageWebViewResultCallback callback, void *userData)
{
	if (callback == nullptr)
	{
		return backendOf(view)->evaluateJavaScript(script);
	}

	auto *request = new EngineRequest{callback, userData};
	int result = backendOf(view)->evaluateJavaScript(script, onResult, request);
	if (result != 0)
	{
		delete request;
	}

	return result;
}

int engineHistoryBack(void *view)
{
	return backendOf(view)->historyBack();
}

int engineHistoryForward(void *view)
{
	return backendOf(view)->historyForward();
}

int engineReload(void *view)
{
	return backendOf(view)->reload();
}

int engineStop(void *view)
{
	return backendOf(view)->stop();
}

int engineRun(void *view)
{
	return backendOf(view)->run();
}

int engineTerminate(void *view)
{
	return backendOf(view)->terminate();
}

int engineSetTitle(void *view, const char *title)
{
	return backendOf(view)->setTitle(title);
}

int engineAssignFocus(void *view, int direction)
{
	return backendOf(view)->assignFocus(direction);
}

int engineCanGoBack(void *view)
{
	return backendOf(view)->canGoBack();
}

int engineCanGoForward(void *view)
{
	return backendOf(view)->canGoForward();
}

char *engineCapturePreviewBase64(void *view, int format)
{
	return copyOf(backendOf(view)->capturePreviewBase64(format));
}

char *engineGetLocation(void *view)
{
	return copyOf(backendOf(view)->getLocation());
}

char *engineGetTitle(void *view)
{
	return copyOf(backendOf(view)->getTitle());
}

void *engineGetNativeHandle(void *view, int kind)
{
	return backendOf(view)->getNativeHandle(kind);
}

int enginePrintToPdf(void *view, const char *path, const StageWebViewEnginePdfOptions *options, StageWebViewResultCallback callback, void *userData)
{
	WebViewPdfOptions pdf;
	pdf.pageWidth = options->pageWidth;
	pdf.pageHeight = options->pageHeight;
	pdf.marginTop = options->marginTop;
	pdf.marginRight = options->marginRight;
	pdf.marginBottom = options->marginBottom;
	pdf.marginLeft = options->marginLeft;
	pdf.landscape = options->landscape;
	pdf.printBackground = options->printBackground;
	pdf.scale = options->scale;
	pdf.repeatTableHeaders = options->repeatTableHeaders;

	auto *request = new EngineRequest{callback, userData};
	int result = backendOf(view)->printToPdf(path, pdf, onResult, request);
	if (result != 0)
	{
		delete request;
	}

	return result;
}

const StageWebViewEngine ENGINE = {
	STAGEWEBVIEW_ENGINE_VERSION,
	engineIsSupported,
	engineProcessEvents,
	engineFreeString,
	engineCreate,
	engineDestroy,
	engineSetCallbacks,
	engineSetSize,
	engineNavigate,
	engineSetHtml,
	engineAddInitScript,
	engineEvaluateJavaScript,
	engineHistoryBack,
	engineHistoryForward,
	engineReload,
	engineStop,
	engineRun,
	engineTerminate,
	engineSetTitle,
	engineAssignFocus,
	engineCanGoBack,
	engineCanGoForward,
	engineCapturePreviewBase64,
	engineGetLocation,
	engineGetTitle,
	engineGetNativeHandle,
	enginePrintToPdf,
	windowCreateChildWindow,
	windowShow,
	windowHide,
	windowDestroy,
	windowMove,
	windowSetFocus,
};

} // namespace

extern "C" __attribute__((visibility("default"))) const StageWebViewEngine *stagewebview_engine(void)
{
	return &ENGINE;
}
