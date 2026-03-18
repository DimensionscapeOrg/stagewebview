#include <hxcpp.h>
#include <limits.h>
#ifndef INT_MAX
#define INT_MAX 2147483647
#endif
#include <objidl.h>

#include "WebViewBackend.h"

namespace {

static const char *BASE64_TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static std::string base64Encode(const unsigned char *data, size_t length)
{
	if (data == nullptr || length == 0)
	{
		return std::string();
	}

	std::string encoded;
	encoded.reserve(((length + 2) / 3) * 4);

	for (size_t index = 0; index < length; index += 3)
	{
		const size_t remaining = length - index;
		const unsigned int chunk = (static_cast<unsigned int>(data[index]) << 16)
			| (remaining > 1 ? static_cast<unsigned int>(data[index + 1]) << 8 : 0)
			| (remaining > 2 ? static_cast<unsigned int>(data[index + 2]) : 0);

		encoded.push_back(BASE64_TABLE[(chunk >> 18) & 0x3F]);
		encoded.push_back(BASE64_TABLE[(chunk >> 12) & 0x3F]);
		encoded.push_back(remaining > 1 ? BASE64_TABLE[(chunk >> 6) & 0x3F] : '=');
		encoded.push_back(remaining > 2 ? BASE64_TABLE[chunk & 0x3F] : '=');
	}

	return encoded;
}

#if defined(_WIN32)
static std::string readStreamBytes(IStream *stream)
{
	if (stream == nullptr)
	{
		return std::string();
	}

	STATSTG stats{};
	if (FAILED(stream->Stat(&stats, STATFLAG_NONAME)) || stats.cbSize.HighPart != 0)
	{
		return std::string();
	}

	LARGE_INTEGER start{};
	if (FAILED(stream->Seek(start, STREAM_SEEK_SET, nullptr)))
	{
		return std::string();
	}

	std::string bytes;
	bytes.resize(static_cast<size_t>(stats.cbSize.QuadPart));

	ULONG read = 0;
	if (!bytes.empty() && FAILED(stream->Read(&bytes[0], static_cast<ULONG>(bytes.size()), &read)))
	{
		return std::string();
	}

	bytes.resize(read);
	return bytes;
}

static bool waitForHandleWithMessageLoop(HANDLE handle)
{
	if (handle == nullptr)
	{
		return false;
	}

	while (true)
	{
		DWORD result = MsgWaitForMultipleObjects(1, &handle, FALSE, INFINITE, QS_ALLINPUT);
		if (result == WAIT_OBJECT_0)
		{
			return true;
		}

		if (result != WAIT_OBJECT_0 + 1)
		{
			return false;
		}

		MSG message{};
		while (PeekMessage(&message, nullptr, 0, 0, PM_REMOVE))
		{
			TranslateMessage(&message);
			DispatchMessage(&message);
		}
	}
}
#endif

} // namespace

namespace stagewebview {

WebViewBackend *WebViewBackend::create(int debug, void *window, const WebViewCreateOptions &options)
{
	auto *backend = new WebViewBackend();
	backend->createOptions = options;
	backend->handle = webview_create(debug, window);

	if (backend->handle == nullptr)
	{
		delete backend;
		return nullptr;
	}

	#if defined(_WIN32)
	backend->cacheNativeHandles();
	backend->applySettings();
	backend->registerEvents();
	#endif

	return backend;
}

WebViewBackend::~WebViewBackend()
{
	#if defined(_WIN32)
	unregisterEvents();

	if (core != nullptr)
	{
		core->Release();
		core = nullptr;
	}

	if (controller != nullptr)
	{
		controller->Release();
		controller = nullptr;
	}
	#endif

	if (handle != nullptr)
	{
		webview_destroy(handle);
		handle = nullptr;
	}
}

int WebViewBackend::setSize(int width, int height, int hints)
{
	if (handle == nullptr)
	{
		return -1;
	}

	return static_cast<int>(webview_set_size(handle, width, height, static_cast<webview_hint_t>(hints)));
}

int WebViewBackend::navigate(const char *url)
{
	if (handle == nullptr)
	{
		return -1;
	}

	return static_cast<int>(webview_navigate(handle, url));
}

int WebViewBackend::setHtml(const char *html)
{
	if (handle == nullptr)
	{
		return -1;
	}

	return static_cast<int>(webview_set_html(handle, html));
}

void WebViewBackend::setCallbacks(const WebViewCallbackSet &value)
{
	callbacks = value;
}

int WebViewBackend::historyBack()
{
	#if defined(_WIN32)
	if (core == nullptr)
	{
		return -1;
	}

	return static_cast<int>(core->GoBack());
	#else
	return -1;
	#endif
}

int WebViewBackend::historyForward()
{
	#if defined(_WIN32)
	if (core == nullptr)
	{
		return -1;
	}

	return static_cast<int>(core->GoForward());
	#else
	return -1;
	#endif
}

int WebViewBackend::reload()
{
	#if defined(_WIN32)
	if (core == nullptr)
	{
		return -1;
	}

	return static_cast<int>(core->Reload());
	#else
	return -1;
	#endif
}

int WebViewBackend::stop()
{
	#if defined(_WIN32)
	if (core == nullptr)
	{
		return -1;
	}

	return static_cast<int>(core->Stop());
	#else
	return -1;
	#endif
}

int WebViewBackend::run()
{
	if (handle == nullptr)
	{
		return -1;
	}

	return static_cast<int>(webview_run(handle));
}

int WebViewBackend::terminate()
{
	if (handle == nullptr)
	{
		return -1;
	}

	return static_cast<int>(webview_terminate(handle));
}

int WebViewBackend::setTitle(const char *title)
{
	if (handle == nullptr)
	{
		return -1;
	}

	return static_cast<int>(webview_set_title(handle, title != nullptr ? title : ""));
}

int WebViewBackend::postMessage(const char *message)
{
	#if defined(_WIN32)
	if (core == nullptr)
	{
		return -1;
	}

	auto wideMessage = webview::detail::widen_string(message != nullptr ? std::string(message) : std::string());
	return static_cast<int>(core->PostWebMessageAsString(wideMessage.c_str()));
	#else
	(void)message;
	return -1;
	#endif
}

int WebViewBackend::assignFocus(int direction)
{
	#if defined(_WIN32)
	if (controller == nullptr)
	{
		return -1;
	}

	auto reason = COREWEBVIEW2_MOVE_FOCUS_REASON_PROGRAMMATIC;
	switch (direction)
	{
		case 0:
			reason = COREWEBVIEW2_MOVE_FOCUS_REASON_PREVIOUS;
			break;

		case 2:
			reason = COREWEBVIEW2_MOVE_FOCUS_REASON_NEXT;
			break;

		default:
			reason = COREWEBVIEW2_MOVE_FOCUS_REASON_PROGRAMMATIC;
			break;
	}

	return static_cast<int>(controller->MoveFocus(reason));
	#else
	(void)direction;
	return -1;
	#endif
}

int WebViewBackend::canGoBack() const
{
	#if defined(_WIN32)
	if (core == nullptr)
	{
		return 0;
	}

	BOOL value = FALSE;
	if (FAILED(core->get_CanGoBack(&value)))
	{
		return 0;
	}

	return value ? 1 : 0;
	#else
	return 0;
	#endif
}

int WebViewBackend::canGoForward() const
{
	#if defined(_WIN32)
	if (core == nullptr)
	{
		return 0;
	}

	BOOL value = FALSE;
	if (FAILED(core->get_CanGoForward(&value)))
	{
		return 0;
	}

	return value ? 1 : 0;
	#else
	return 0;
	#endif
}

std::string WebViewBackend::capturePreviewBase64(int format) const
{
	#if defined(_WIN32)
	if (core == nullptr)
	{
		return std::string();
	}

	IStream *stream = nullptr;
	if (FAILED(CreateStreamOnHGlobal(nullptr, TRUE, &stream)) || stream == nullptr)
	{
		return std::string();
	}

	HANDLE completedEvent = CreateEventW(nullptr, TRUE, FALSE, nullptr);
	if (completedEvent == nullptr)
	{
		stream->Release();
		return std::string();
	}

	HRESULT completionResult = E_FAIL;
	auto imageFormat = format == 1 ? COREWEBVIEW2_CAPTURE_PREVIEW_IMAGE_FORMAT_JPEG : COREWEBVIEW2_CAPTURE_PREVIEW_IMAGE_FORMAT_PNG;
	auto startResult = core->CapturePreview(
		imageFormat,
		stream,
		Microsoft::WRL::Callback<ICoreWebView2CapturePreviewCompletedHandler>(
			[&completionResult, completedEvent](HRESULT errorCode) -> HRESULT
			{
				completionResult = errorCode;
				SetEvent(completedEvent);
				return S_OK;
			})
			.Get());

	bool completed = false;
	if (SUCCEEDED(startResult))
	{
		completed = waitForHandleWithMessageLoop(completedEvent);
	}

	CloseHandle(completedEvent);

	if (FAILED(startResult) || !completed || FAILED(completionResult))
	{
		stream->Release();
		return std::string();
	}

	auto bytes = readStreamBytes(stream);
	stream->Release();

	if (bytes.empty())
	{
		return std::string();
	}

	return base64Encode(reinterpret_cast<const unsigned char *>(bytes.data()), bytes.size());
	#else
	(void)format;
	return std::string();
	#endif
}

std::string WebViewBackend::getLocation() const
{
	#if defined(_WIN32)
	if (core == nullptr)
	{
		return std::string();
	}

	LPWSTR source = nullptr;
	if (FAILED(core->get_Source(&source)))
	{
		return std::string();
	}

	auto result = wideToUtf8(source);
	if (source != nullptr)
	{
		CoTaskMemFree(source);
	}

	return result;
	#else
	return std::string();
	#endif
}

std::string WebViewBackend::getTitle() const
{
	#if defined(_WIN32)
	if (core == nullptr)
	{
		return std::string();
	}

	LPWSTR title = nullptr;
	if (FAILED(core->get_DocumentTitle(&title)))
	{
		return std::string();
	}

	auto result = wideToUtf8(title);
	if (title != nullptr)
	{
		CoTaskMemFree(title);
	}

	return result;
	#else
	return std::string();
	#endif
}

void *WebViewBackend::getNativeHandle(int kind) const
{
	if (handle == nullptr)
	{
		return nullptr;
	}

	return webview_get_native_handle(handle, static_cast<webview_native_handle_kind_t>(kind));
}

void WebViewBackend::webView2ControllerSetBounds(void *controllerHandle, int width, int height)
{
	#if defined(_WIN32)
	auto *ctrl = reinterpret_cast<ICoreWebView2Controller *>(controllerHandle);
	if (ctrl == nullptr)
	{
		return;
	}

	RECT bounds{};
	bounds.left = 0;
	bounds.top = 0;
	bounds.right = width;
	bounds.bottom = height;
	ctrl->put_Bounds(bounds);
	#else
	(void)controllerHandle;
	(void)width;
	(void)height;
	#endif
}

bool WebViewBackend::notifyLocationChanging(const std::string &location) const
{
	return callbacks.onLocationChanging != nullptr ? callbacks.onLocationChanging(callbacks.userData, location) : false;
}

void WebViewBackend::notifyLocationChange(const std::string &location) const
{
	if (callbacks.onLocationChange != nullptr)
	{
		callbacks.onLocationChange(callbacks.userData, location);
	}
}

void WebViewBackend::notifyComplete() const
{
	if (callbacks.onComplete != nullptr)
	{
		callbacks.onComplete(callbacks.userData);
	}
}

void WebViewBackend::notifyError(const std::string &message) const
{
	if (callbacks.onError != nullptr)
	{
		callbacks.onError(callbacks.userData, message);
	}
}

void WebViewBackend::notifyFocusIn() const
{
	if (callbacks.onFocusIn != nullptr)
	{
		callbacks.onFocusIn(callbacks.userData);
	}
}

void WebViewBackend::notifyFocusOut() const
{
	if (callbacks.onFocusOut != nullptr)
	{
		callbacks.onFocusOut(callbacks.userData);
	}
}

void WebViewBackend::notifyMessage(const std::string &message) const
{
	if (callbacks.onMessage != nullptr)
	{
		callbacks.onMessage(callbacks.userData, message);
	}
}

#if defined(_WIN32)
void WebViewBackend::applySettings()
{
	if (core == nullptr)
	{
		return;
	}

	ICoreWebView2Settings *settings = nullptr;
	if (FAILED(core->get_Settings(&settings)) || settings == nullptr)
	{
		return;
	}

	if (createOptions.enableDevTools != -1)
	{
		settings->put_AreDevToolsEnabled(createOptions.enableDevTools == 1 ? TRUE : FALSE);
	}

	if (createOptions.enableStatusBar != -1)
	{
		settings->put_IsStatusBarEnabled(createOptions.enableStatusBar == 1 ? TRUE : FALSE);
	}

	if (createOptions.enableContextMenu != -1)
	{
		settings->put_AreDefaultContextMenusEnabled(createOptions.enableContextMenu == 1 ? TRUE : FALSE);
	}

	if (createOptions.enableZoom != -1)
	{
		settings->put_IsZoomControlEnabled(createOptions.enableZoom == 1 ? TRUE : FALSE);
	}

	if (createOptions.userAgent != "")
	{
		ICoreWebView2Settings2 *settings2 = nullptr;
		if (SUCCEEDED(settings->QueryInterface(IID_ICoreWebView2Settings2, reinterpret_cast<void **>(&settings2))) && settings2 != nullptr)
		{
			auto wideUserAgent = webview::detail::widen_string(createOptions.userAgent);
			settings2->put_UserAgent(wideUserAgent.c_str());
			settings2->Release();
		}
	}

	if (createOptions.enableKeyboardShortcuts != -1)
	{
		ICoreWebView2Settings3 *settings3 = nullptr;
		if (SUCCEEDED(settings->QueryInterface(IID_ICoreWebView2Settings3, reinterpret_cast<void **>(&settings3))) && settings3 != nullptr)
		{
			settings3->put_AreBrowserAcceleratorKeysEnabled(createOptions.enableKeyboardShortcuts == 1 ? TRUE : FALSE);
			settings3->Release();
		}
	}

	settings->Release();
}

std::string WebViewBackend::wideToUtf8(const wchar_t *value)
{
	return value != nullptr ? webview::detail::narrow_string(value) : std::string();
}

void WebViewBackend::cacheNativeHandles()
{
	auto *nativeController = reinterpret_cast<ICoreWebView2Controller *>(webview_get_native_handle(handle,
		WEBVIEW_NATIVE_HANDLE_KIND_BROWSER_CONTROLLER));
	if (nativeController == nullptr)
	{
		return;
	}

	controller = nativeController;
	controller->AddRef();

	if (FAILED(controller->get_CoreWebView2(&core)))
	{
		core = nullptr;
	}
}

void WebViewBackend::registerEvents()
{
	if (controller == nullptr || core == nullptr)
	{
		return;
	}

	if (SUCCEEDED(core->add_NavigationStarting(
			Microsoft::WRL::Callback<ICoreWebView2NavigationStartingEventHandler>(
				[this](ICoreWebView2 *, ICoreWebView2NavigationStartingEventArgs *args) -> HRESULT
				{
					LPWSTR uri = nullptr;
					args->get_Uri(&uri);
					auto location = wideToUtf8(uri);
					if (uri != nullptr)
					{
						CoTaskMemFree(uri);
					}

					if (notifyLocationChanging(location))
					{
						args->put_Cancel(TRUE);
					}

					return S_OK;
				})
				.Get(),
			&navigationStartingToken)))
	{
		hasNavigationStarting = true;
	}

	if (SUCCEEDED(core->add_SourceChanged(
			Microsoft::WRL::Callback<ICoreWebView2SourceChangedEventHandler>(
				[this](ICoreWebView2 *sender, ICoreWebView2SourceChangedEventArgs *) -> HRESULT
				{
					LPWSTR source = nullptr;
					sender->get_Source(&source);
					auto location = wideToUtf8(source);
					if (source != nullptr)
					{
						CoTaskMemFree(source);
					}

					notifyLocationChange(location);
					return S_OK;
				})
				.Get(),
			&sourceChangedToken)))
	{
		hasSourceChanged = true;
	}

	if (SUCCEEDED(core->add_NavigationCompleted(
			Microsoft::WRL::Callback<ICoreWebView2NavigationCompletedEventHandler>(
				[this](ICoreWebView2 *, ICoreWebView2NavigationCompletedEventArgs *args) -> HRESULT
				{
					BOOL isSuccess = FALSE;
					args->get_IsSuccess(&isSuccess);

					if (isSuccess)
					{
						notifyComplete();
						return S_OK;
					}

					COREWEBVIEW2_WEB_ERROR_STATUS status = COREWEBVIEW2_WEB_ERROR_STATUS_UNKNOWN;
					args->get_WebErrorStatus(&status);
					notifyError("Navigation failed: " + std::to_string(static_cast<int>(status)));
					return S_OK;
				})
				.Get(),
			&navigationCompletedToken)))
	{
		hasNavigationCompleted = true;
	}

	if (SUCCEEDED(controller->add_GotFocus(
			Microsoft::WRL::Callback<ICoreWebView2FocusChangedEventHandler>(
				[this](ICoreWebView2Controller *, IUnknown *) -> HRESULT
				{
					notifyFocusIn();
					return S_OK;
				})
				.Get(),
			&gotFocusToken)))
	{
		hasGotFocus = true;
	}

	if (SUCCEEDED(controller->add_LostFocus(
			Microsoft::WRL::Callback<ICoreWebView2FocusChangedEventHandler>(
				[this](ICoreWebView2Controller *, IUnknown *) -> HRESULT
				{
					notifyFocusOut();
					return S_OK;
				})
				.Get(),
			&lostFocusToken)))
	{
		hasLostFocus = true;
	}

	if (SUCCEEDED(core->add_WebMessageReceived(
			Microsoft::WRL::Callback<ICoreWebView2WebMessageReceivedEventHandler>(
				[this](ICoreWebView2 *, ICoreWebView2WebMessageReceivedEventArgs *args) -> HRESULT
				{
					LPWSTR message = nullptr;
					auto result = args->TryGetWebMessageAsString(&message);
					if (SUCCEEDED(result) && message != nullptr)
					{
						notifyMessage(wideToUtf8(message));
					}

					if (message != nullptr)
					{
						CoTaskMemFree(message);
					}

					return S_OK;
				})
				.Get(),
			&messageReceivedToken)))
	{
		hasMessageReceived = true;
	}
}

void WebViewBackend::unregisterEvents()
{
	if (controller != nullptr)
	{
		if (hasGotFocus)
		{
			controller->remove_GotFocus(gotFocusToken);
			hasGotFocus = false;
		}

		if (hasLostFocus)
		{
			controller->remove_LostFocus(lostFocusToken);
			hasLostFocus = false;
		}
	}

	if (core != nullptr)
	{
		if (hasNavigationStarting)
		{
			core->remove_NavigationStarting(navigationStartingToken);
			hasNavigationStarting = false;
		}

		if (hasSourceChanged)
		{
			core->remove_SourceChanged(sourceChangedToken);
			hasSourceChanged = false;
		}

		if (hasNavigationCompleted)
		{
			core->remove_NavigationCompleted(navigationCompletedToken);
			hasNavigationCompleted = false;
		}

		if (hasMessageReceived)
		{
			core->remove_WebMessageReceived(messageReceivedToken);
			hasMessageReceived = false;
		}
	}
}
#endif

} // namespace stagewebview
