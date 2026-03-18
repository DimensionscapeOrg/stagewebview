#include <hxcpp.h>
#include <limits.h>
#ifndef INT_MAX
#define INT_MAX 2147483647
#endif

#define HL_NAME(n) stagewebview_##n
#include <hl.h>
#undef DEFINE_PRIM
#define DEFINE_HL_PRIM(t, name, args) DEFINE_PRIM_WITH_NAME(t, name, args, name)

#include <cstring>

#include "WebViewBackend.h"

namespace {

struct HL_CFFIPointer
{
	void *finalizer;
	void *ptr;
};

struct HLRootedClosure
{
	vclosure *value = nullptr;

	HLRootedClosure()
	{
		hl_add_root(&value);
	}

	~HLRootedClosure()
	{
		hl_remove_root(&value);
	}
};

struct HLCallbackState
{
	HLRootedClosure *onLocationChanging = nullptr;
	HLRootedClosure *onLocationChange = nullptr;
	HLRootedClosure *onComplete = nullptr;
	HLRootedClosure *onError = nullptr;
	HLRootedClosure *onFocusIn = nullptr;
	HLRootedClosure *onFocusOut = nullptr;
	HLRootedClosure *onMessage = nullptr;

	~HLCallbackState()
	{
		clear(onLocationChanging);
		clear(onLocationChange);
		clear(onComplete);
		clear(onError);
		clear(onFocusIn);
		clear(onFocusOut);
		clear(onMessage);
	}

	static void clear(HLRootedClosure *&slot)
	{
		if (slot != nullptr)
		{
			delete slot;
			slot = nullptr;
		}
	}
};

struct HLWebViewHandle
{
	stagewebview::WebViewBackend *backend = nullptr;
	HLCallbackState callbacks;

	~HLWebViewHandle()
	{
		delete backend;
		backend = nullptr;
	}
};

static HL_CFFIPointer *allocPointer(void *ptr, void (*finalizer)(void *) = nullptr)
{
	if (ptr == nullptr)
	{
		return nullptr;
	}

	auto *value = reinterpret_cast<HL_CFFIPointer *>(hl_gc_alloc_finalizer(sizeof(HL_CFFIPointer)));
	value->finalizer = finalizer != nullptr ? reinterpret_cast<void *>(finalizer) : nullptr;
	value->ptr = ptr;
	return value;
}

static HLWebViewHandle *unwrap(HL_CFFIPointer *value)
{
	return value != nullptr ? reinterpret_cast<HLWebViewHandle *>(value->ptr) : nullptr;
}

static void deleteHandle(void *value)
{
	delete reinterpret_cast<HLWebViewHandle *>(value);
}

static void setCallback(HLRootedClosure *&slot, vclosure *callback)
{
	if (callback == nullptr)
	{
		HLCallbackState::clear(slot);
		return;
	}

	if (slot == nullptr)
	{
		slot = new HLRootedClosure();
	}

	slot->value = callback;
}

static vdynamic *stringArgument(const std::string &value)
{
	return hl_alloc_strbytes(USTR("%s"), value.c_str());
}

static bool invokeBool(HLRootedClosure *slot, const std::string &value)
{
	if (slot == nullptr || slot->value == nullptr)
	{
		return false;
	}

	vdynamic *argument = stringArgument(value);
	vdynamic *result = hl_dyn_call(slot->value, &argument, 1);
	return result != nullptr && result->v.b;
}

static void invokeVoid(HLRootedClosure *slot)
{
	if (slot != nullptr && slot->value != nullptr)
	{
		hl_dyn_call(slot->value, nullptr, 0);
	}
}

static void invokeString(HLRootedClosure *slot, const std::string &value)
{
	if (slot == nullptr || slot->value == nullptr)
	{
		return;
	}

	vdynamic *argument = stringArgument(value);
	hl_dyn_call(slot->value, &argument, 1);
}

static bool onLocationChangingThunk(void *userData, const std::string &location)
{
	auto *callbacks = reinterpret_cast<HLCallbackState *>(userData);
	return invokeBool(callbacks->onLocationChanging, location);
}

static void onLocationChangeThunk(void *userData, const std::string &location)
{
	auto *callbacks = reinterpret_cast<HLCallbackState *>(userData);
	invokeString(callbacks->onLocationChange, location);
}

static void onCompleteThunk(void *userData)
{
	auto *callbacks = reinterpret_cast<HLCallbackState *>(userData);
	invokeVoid(callbacks->onComplete);
}

static void onErrorThunk(void *userData, const std::string &message)
{
	auto *callbacks = reinterpret_cast<HLCallbackState *>(userData);
	invokeString(callbacks->onError, message);
}

static void onFocusInThunk(void *userData)
{
	auto *callbacks = reinterpret_cast<HLCallbackState *>(userData);
	invokeVoid(callbacks->onFocusIn);
}

static void onFocusOutThunk(void *userData)
{
	auto *callbacks = reinterpret_cast<HLCallbackState *>(userData);
	invokeVoid(callbacks->onFocusOut);
}

static void onMessageThunk(void *userData, const std::string &message)
{
	auto *callbacks = reinterpret_cast<HLCallbackState *>(userData);
	invokeString(callbacks->onMessage, message);
}

static void refreshCallbacks(HLWebViewHandle *handle)
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

static const char *toUtf8(vstring *value)
{
	return value != nullptr ? hl_to_utf8(value->bytes) : nullptr;
}

static vbyte *copyBytes(const std::string &value)
{
	auto *bytes = hl_alloc_bytes(static_cast<int>(value.size()) + 1);
	std::memcpy(bytes, value.c_str(), value.size() + 1);
	return bytes;
}

} // namespace

#define _TCFFIPOINTER _DYN

HL_PRIM HL_CFFIPointer *HL_NAME(hl_webview_create)(int debug, HL_CFFIPointer *window, vstring *userAgent, int mediaPlaybackRequiresUserAction,
	int enableContextMenu, int enableKeyboardShortcuts, int enableDevTools, int enableStatusBar, int enableZoom)
{
	auto *handle = new HLWebViewHandle();
	stagewebview::WebViewCreateOptions options;
	options.mediaPlaybackRequiresUserAction = mediaPlaybackRequiresUserAction;
	options.userAgent = userAgent != nullptr ? toUtf8(userAgent) : "";
	options.enableContextMenu = enableContextMenu;
	options.enableKeyboardShortcuts = enableKeyboardShortcuts;
	options.enableDevTools = enableDevTools;
	options.enableStatusBar = enableStatusBar;
	options.enableZoom = enableZoom;
	handle->backend = stagewebview::WebViewBackend::create(debug, window != nullptr ? window->ptr : nullptr, options);

	if (handle->backend == nullptr)
	{
		delete handle;
		return nullptr;
	}

	return allocPointer(handle, deleteHandle);
}

HL_PRIM void HL_NAME(hl_webview_destroy)(HL_CFFIPointer *w)
{
	auto *handle = unwrap(w);
	if (handle == nullptr)
	{
		return;
	}

	if (w != nullptr)
	{
		w->ptr = nullptr;
	}

	delete handle;
}

HL_PRIM int HL_NAME(hl_webview_set_size)(HL_CFFIPointer *w, int width, int height, int hints)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->setSize(width, height, hints) : -1;
}

HL_PRIM int HL_NAME(hl_webview_navigate)(HL_CFFIPointer *w, vstring *url)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->navigate(toUtf8(url)) : -1;
}

HL_PRIM int HL_NAME(hl_webview_set_html)(HL_CFFIPointer *w, vstring *html)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->setHtml(toUtf8(html)) : -1;
}

HL_PRIM void HL_NAME(hl_webview_set_callbacks)(HL_CFFIPointer *w, vclosure *onLocationChanging, vclosure *onLocationChange, vclosure *onComplete,
	vclosure *onError, vclosure *onFocusIn, vclosure *onFocusOut, vclosure *onMessage)
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

HL_PRIM int HL_NAME(hl_webview_history_back)(HL_CFFIPointer *w)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->historyBack() : -1;
}

HL_PRIM int HL_NAME(hl_webview_history_forward)(HL_CFFIPointer *w)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->historyForward() : -1;
}

HL_PRIM int HL_NAME(hl_webview_reload)(HL_CFFIPointer *w)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->reload() : -1;
}

HL_PRIM int HL_NAME(hl_webview_stop)(HL_CFFIPointer *w)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->stop() : -1;
}

HL_PRIM int HL_NAME(hl_webview_run)(HL_CFFIPointer *w)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->run() : -1;
}

HL_PRIM int HL_NAME(hl_webview_terminate)(HL_CFFIPointer *w)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->terminate() : -1;
}

HL_PRIM int HL_NAME(hl_webview_set_title)(HL_CFFIPointer *w, vstring *title)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->setTitle(toUtf8(title)) : -1;
}

HL_PRIM int HL_NAME(hl_webview_post_message)(HL_CFFIPointer *w, vstring *message)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->postMessage(toUtf8(message)) : -1;
}

HL_PRIM int HL_NAME(hl_webview_assign_focus)(HL_CFFIPointer *w, int direction)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->assignFocus(direction) : -1;
}

HL_PRIM int HL_NAME(hl_webview_can_go_back)(HL_CFFIPointer *w)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->canGoBack() : 0;
}

HL_PRIM int HL_NAME(hl_webview_can_go_forward)(HL_CFFIPointer *w)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? handle->backend->canGoForward() : 0;
}

HL_PRIM vbyte *HL_NAME(hl_webview_capture_preview_base64)(HL_CFFIPointer *w, int format)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? copyBytes(handle->backend->capturePreviewBase64(format)) : nullptr;
}

HL_PRIM vbyte *HL_NAME(hl_webview_get_location)(HL_CFFIPointer *w)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? copyBytes(handle->backend->getLocation()) : nullptr;
}

HL_PRIM vbyte *HL_NAME(hl_webview_get_title)(HL_CFFIPointer *w)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? copyBytes(handle->backend->getTitle()) : nullptr;
}

HL_PRIM HL_CFFIPointer *HL_NAME(hl_webview_get_native_handle)(HL_CFFIPointer *w, int kind)
{
	auto *handle = unwrap(w);
	return handle != nullptr && handle->backend != nullptr ? allocPointer(handle->backend->getNativeHandle(kind)) : nullptr;
}

HL_PRIM void HL_NAME(hl_webview_webview2_controller_set_bounds)(HL_CFFIPointer *controller, int width, int height)
{
	stagewebview::WebViewBackend::webView2ControllerSetBounds(controller != nullptr ? controller->ptr : nullptr, width, height);
}

DEFINE_HL_PRIM(_TCFFIPOINTER, hl_webview_create, _I32 _TCFFIPOINTER _STRING _I32 _I32 _I32 _I32 _I32 _I32);
DEFINE_HL_PRIM(_VOID, hl_webview_destroy, _TCFFIPOINTER);
DEFINE_HL_PRIM(_I32, hl_webview_set_size, _TCFFIPOINTER _I32 _I32 _I32);
DEFINE_HL_PRIM(_I32, hl_webview_navigate, _TCFFIPOINTER _STRING);
DEFINE_HL_PRIM(_I32, hl_webview_set_html, _TCFFIPOINTER _STRING);
DEFINE_HL_PRIM(_VOID, hl_webview_set_callbacks, _TCFFIPOINTER _DYN _DYN _DYN _DYN _DYN _DYN _DYN);
DEFINE_HL_PRIM(_I32, hl_webview_history_back, _TCFFIPOINTER);
DEFINE_HL_PRIM(_I32, hl_webview_history_forward, _TCFFIPOINTER);
DEFINE_HL_PRIM(_I32, hl_webview_reload, _TCFFIPOINTER);
DEFINE_HL_PRIM(_I32, hl_webview_stop, _TCFFIPOINTER);
DEFINE_HL_PRIM(_I32, hl_webview_run, _TCFFIPOINTER);
DEFINE_HL_PRIM(_I32, hl_webview_terminate, _TCFFIPOINTER);
DEFINE_HL_PRIM(_I32, hl_webview_set_title, _TCFFIPOINTER _STRING);
DEFINE_HL_PRIM(_I32, hl_webview_post_message, _TCFFIPOINTER _STRING);
DEFINE_HL_PRIM(_I32, hl_webview_assign_focus, _TCFFIPOINTER _I32);
DEFINE_HL_PRIM(_I32, hl_webview_can_go_back, _TCFFIPOINTER);
DEFINE_HL_PRIM(_I32, hl_webview_can_go_forward, _TCFFIPOINTER);
DEFINE_HL_PRIM(_BYTES, hl_webview_capture_preview_base64, _TCFFIPOINTER _I32);
DEFINE_HL_PRIM(_BYTES, hl_webview_get_location, _TCFFIPOINTER);
DEFINE_HL_PRIM(_BYTES, hl_webview_get_title, _TCFFIPOINTER);
DEFINE_HL_PRIM(_TCFFIPOINTER, hl_webview_get_native_handle, _TCFFIPOINTER _I32);
DEFINE_HL_PRIM(_VOID, hl_webview_webview2_controller_set_bounds, _TCFFIPOINTER _I32 _I32);
