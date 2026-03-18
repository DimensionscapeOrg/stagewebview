#include <hxcpp.h>
#include <limits.h>
#ifndef INT_MAX
#define INT_MAX 2147483647
#endif
#include <hx/GC.h>

#include "WebViewBackend.h"
#include "WebViewBindings.h"

namespace {

struct RootedCallback
{
	hx::Object *value = nullptr;

	RootedCallback()
	{
		hx::GCAddRoot(&value);
	}

	~RootedCallback()
	{
		hx::GCRemoveRoot(&value);
	}
};

struct HxcppCallbackState
{
	RootedCallback *onLocationChanging = nullptr;
	RootedCallback *onLocationChange = nullptr;
	RootedCallback *onComplete = nullptr;
	RootedCallback *onError = nullptr;
	RootedCallback *onFocusIn = nullptr;
	RootedCallback *onFocusOut = nullptr;
	RootedCallback *onMessage = nullptr;

	~HxcppCallbackState()
	{
		clear(onLocationChanging);
		clear(onLocationChange);
		clear(onComplete);
		clear(onError);
		clear(onFocusIn);
		clear(onFocusOut);
		clear(onMessage);
	}

	static void clear(RootedCallback *&slot)
	{
		if (slot != nullptr)
		{
			delete slot;
			slot = nullptr;
		}
	}
};

struct HxcppWebViewHandle
{
	stagewebview::WebViewBackend *backend = nullptr;
	HxcppCallbackState callbacks;

	~HxcppWebViewHandle()
	{
		delete backend;
		backend = nullptr;
	}
};

static HxcppWebViewHandle *unwrap(void *value)
{
	return reinterpret_cast<HxcppWebViewHandle *>(value);
}

static Dynamic dynamicFromRoot(const RootedCallback *slot)
{
	return slot == nullptr || slot->value == nullptr ? Dynamic(null()) : Dynamic(slot->value);
}

static void setCallback(RootedCallback *&slot, Dynamic callback)
{
	if (callback == null())
	{
		HxcppCallbackState::clear(slot);
		return;
	}

	if (slot == nullptr)
	{
		slot = new RootedCallback();
	}

	slot->value = callback.mPtr;
}

static bool invokeBool(RootedCallback *slot, const std::string &value)
{
	if (slot == nullptr)
	{
		return false;
	}

	Dynamic callback = dynamicFromRoot(slot);
	return callback != null() ? callback(String(value.c_str())) : false;
}

static void invokeVoid(RootedCallback *slot)
{
	if (slot == nullptr)
	{
		return;
	}

	Dynamic callback = dynamicFromRoot(slot);
	if (callback != null())
	{
		callback();
	}
}

static void invokeString(RootedCallback *slot, const std::string &value)
{
	if (slot == nullptr)
	{
		return;
	}

	Dynamic callback = dynamicFromRoot(slot);
	if (callback != null())
	{
		callback(String(value.c_str()));
	}
}

static bool onLocationChangingThunk(void *userData, const std::string &location)
{
	auto *callbacks = reinterpret_cast<HxcppCallbackState *>(userData);
	return invokeBool(callbacks->onLocationChanging, location);
}

static void onLocationChangeThunk(void *userData, const std::string &location)
{
	auto *callbacks = reinterpret_cast<HxcppCallbackState *>(userData);
	invokeString(callbacks->onLocationChange, location);
}

static void onCompleteThunk(void *userData)
{
	auto *callbacks = reinterpret_cast<HxcppCallbackState *>(userData);
	invokeVoid(callbacks->onComplete);
}

static void onErrorThunk(void *userData, const std::string &message)
{
	auto *callbacks = reinterpret_cast<HxcppCallbackState *>(userData);
	invokeString(callbacks->onError, message);
}

static void onFocusInThunk(void *userData)
{
	auto *callbacks = reinterpret_cast<HxcppCallbackState *>(userData);
	invokeVoid(callbacks->onFocusIn);
}

static void onFocusOutThunk(void *userData)
{
	auto *callbacks = reinterpret_cast<HxcppCallbackState *>(userData);
	invokeVoid(callbacks->onFocusOut);
}

static void onMessageThunk(void *userData, const std::string &message)
{
	auto *callbacks = reinterpret_cast<HxcppCallbackState *>(userData);
	invokeString(callbacks->onMessage, message);
}

static void refreshCallbacks(HxcppWebViewHandle *handle)
{
	if (handle == nullptr || handle->backend == nullptr)
	{
		return;
	}

	stagewebview::WebViewCallbackSet callbacks;
	callbacks.userData = &handle->callbacks;
	callbacks.onLocationChanging = handle->callbacks.onLocationChanging != nullptr ? onLocationChangingThunk : nullptr;
	callbacks.onLocationChange = handle->callbacks.onLocationChange != nullptr ? onLocationChangeThunk : nullptr;
	callbacks.onComplete = handle->callbacks.onComplete != nullptr ? onCompleteThunk : nullptr;
	callbacks.onError = handle->callbacks.onError != nullptr ? onErrorThunk : nullptr;
	callbacks.onFocusIn = handle->callbacks.onFocusIn != nullptr ? onFocusInThunk : nullptr;
	callbacks.onFocusOut = handle->callbacks.onFocusOut != nullptr ? onFocusOutThunk : nullptr;
	callbacks.onMessage = handle->callbacks.onMessage != nullptr ? onMessageThunk : nullptr;
	handle->backend->setCallbacks(callbacks);
}

} // namespace

namespace stagewebview {

void *HxcppWebViewBindings::create(int debug, void *window, const char *userAgent, int mediaPlaybackRequiresUserAction, int enableContextMenu,
	int enableKeyboardShortcuts, int enableDevTools, int enableStatusBar, int enableZoom)
{
	auto *handle = new HxcppWebViewHandle();
	WebViewCreateOptions options;
	options.mediaPlaybackRequiresUserAction = mediaPlaybackRequiresUserAction;
	options.userAgent = userAgent != nullptr ? userAgent : "";
	options.enableContextMenu = enableContextMenu;
	options.enableKeyboardShortcuts = enableKeyboardShortcuts;
	options.enableDevTools = enableDevTools;
	options.enableStatusBar = enableStatusBar;
	options.enableZoom = enableZoom;
	handle->backend = WebViewBackend::create(debug, window, options);

	if (handle->backend == nullptr)
	{
		delete handle;
		return nullptr;
	}

	return handle;
}

void HxcppWebViewBindings::destroy(void *w)
{
	delete unwrap(w);
}

int HxcppWebViewBindings::setSize(void *w, int width, int height, int hints)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->setSize(width, height, hints) : -1;
}

int HxcppWebViewBindings::navigate(void *w, const char *url)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->navigate(url) : -1;
}

int HxcppWebViewBindings::setHtml(void *w, const char *html)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->setHtml(html) : -1;
}

void HxcppWebViewBindings::setCallbacks(void *w, Dynamic onLocationChanging, Dynamic onLocationChange, Dynamic onComplete, Dynamic onError,
	Dynamic onFocusIn, Dynamic onFocusOut, Dynamic onMessage)
{
	auto *handle = unwrap(w);
	if (handle == nullptr)
	{
		return;
	}

	setCallback(handle->callbacks.onLocationChanging, onLocationChanging);
	setCallback(handle->callbacks.onLocationChange, onLocationChange);
	setCallback(handle->callbacks.onComplete, onComplete);
	setCallback(handle->callbacks.onError, onError);
	setCallback(handle->callbacks.onFocusIn, onFocusIn);
	setCallback(handle->callbacks.onFocusOut, onFocusOut);
	setCallback(handle->callbacks.onMessage, onMessage);
	refreshCallbacks(handle);
}

int HxcppWebViewBindings::historyBack(void *w)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->historyBack() : -1;
}

int HxcppWebViewBindings::historyForward(void *w)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->historyForward() : -1;
}

int HxcppWebViewBindings::reload(void *w)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->reload() : -1;
}

int HxcppWebViewBindings::stop(void *w)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->stop() : -1;
}

int HxcppWebViewBindings::run(void *w)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->run() : -1;
}

int HxcppWebViewBindings::terminate(void *w)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->terminate() : -1;
}

int HxcppWebViewBindings::setTitle(void *w, const char *title)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->setTitle(title) : -1;
}

int HxcppWebViewBindings::postMessage(void *w, const char *message)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->postMessage(message) : -1;
}

int HxcppWebViewBindings::assignFocus(void *w, int direction)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->assignFocus(direction) : -1;
}

int HxcppWebViewBindings::canGoBack(void *w)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->canGoBack() : 0;
}

int HxcppWebViewBindings::canGoForward(void *w)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->canGoForward() : 0;
}

String HxcppWebViewBindings::capturePreviewBase64(void *w, int format)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? String(handle->backend->capturePreviewBase64(format).c_str()) : String();
}

String HxcppWebViewBindings::getLocation(void *w)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? String(handle->backend->getLocation().c_str()) : String();
}

String HxcppWebViewBindings::getTitle(void *w)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? String(handle->backend->getTitle().c_str()) : String();
}

void *HxcppWebViewBindings::getNativeHandle(void *w, int kind)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->getNativeHandle(kind) : nullptr;
}

void HxcppWebViewBindings::webView2ControllerSetBounds(void *controller, int width, int height)
{
	WebViewBackend::webView2ControllerSetBounds(controller, width, height);
}

} // namespace stagewebview
