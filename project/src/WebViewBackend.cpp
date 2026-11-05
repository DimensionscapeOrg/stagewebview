// Windows (WebView2) implementation. Other platforms implement WebViewBackend in WebViewBackendPlatform.cpp.
#include <limits.h>
#ifndef INT_MAX
#define INT_MAX 2147483647
#endif
#include <objidl.h>

#include <stagewebview/WebViewBackend.h>

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

// Width and height of the never-shown host window used by startHidden.
static constexpr int HIDDEN_HOST_WIDTH = 1024;
static constexpr int HIDDEN_HOST_HEIGHT = 1366;

static HWND createHiddenHostWindow()
{
	static constexpr LPCWSTR className = L"StageWebViewHiddenHost";
	HINSTANCE instance = GetModuleHandle(nullptr);

	// webview.h only initializes COM for windows it creates itself, as WindowBackend does for child windows.
	CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

	WNDCLASSEXW existing{};
	if (!GetClassInfoExW(instance, className, &existing))
	{
		WNDCLASSEXW wc{};
		wc.cbSize = sizeof(WNDCLASSEXW);
		wc.lpfnWndProc = DefWindowProcW;
		wc.hInstance = instance;
		wc.lpszClassName = className;
		if (!RegisterClassExW(&wc))
		{
			return nullptr;
		}
	}

	// WS_POPUP without WS_VISIBLE: the window exists for WebView2 to parent into, and is never shown.
	return CreateWindowExW(WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE, className, nullptr, WS_POPUP, 0, 0, HIDDEN_HOST_WIDTH, HIDDEN_HOST_HEIGHT,
		nullptr, nullptr, instance, nullptr);
}
#endif

} // namespace

namespace stagewebview {

namespace {

struct PendingResult
{
	WebViewResultCallback callback;
	void *userData;
	bool success;
	std::string message;
};

// Report from the message loop rather than from inside a WebView2 handler: WebView2 cannot create a controller while
// one of its handlers is running, so a callback that opens a new webview (a preview of a PDF, say) would never return.
// A webview that closed in the meantime has no message loop to report from.
void reportResult(webview_t view, const std::shared_ptr<bool> &open, WebViewResultCallback callback, void *userData, bool success,
	const std::string &message)
{
	if (!*open)
	{
		callback(userData, false, "The webview has closed");
		return;
	}

	webview_dispatch(view,
		[](webview_t, void *arg)
		{
			auto *pending = static_cast<PendingResult *>(arg);
			pending->callback(pending->userData, pending->success, pending->message);
			delete pending;
		},
		new PendingResult{callback, userData, success, message});
}

} // namespace

WebViewBackend *WebViewBackend::create(int debug, void *window, const WebViewCreateOptions &options)
{
	auto *backend = new WebViewBackend();
	backend->createOptions = options;

	#if defined(_WIN32)
	if (window == nullptr && options.startHidden == 1)
	{
		backend->hiddenHost = createHiddenHostWindow();
		if (backend->hiddenHost == nullptr)
		{
			delete backend;
			return nullptr;
		}

		window = backend->hiddenHost;
	}
	#endif

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

	if (backend->hiddenHost != nullptr)
	{
		auto widget = reinterpret_cast<HWND>(webview_get_native_handle(backend->handle, WEBVIEW_NATIVE_HANDLE_KIND_UI_WIDGET));
		if (widget != nullptr)
		{
			MoveWindow(widget, 0, 0, HIDDEN_HOST_WIDTH, HIDDEN_HOST_HEIGHT, FALSE);
		}

		webView2ControllerSetBounds(backend->controller, HIDDEN_HOST_WIDTH, HIDDEN_HOST_HEIGHT);
	}
	#endif

	return backend;
}

WebViewBackend::~WebViewBackend()
{
	#if defined(_WIN32)
	*open = false;
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

	#if defined(_WIN32)
	if (hiddenHost != nullptr)
	{
		DestroyWindow(hiddenHost);
		hiddenHost = nullptr;
	}
	#endif
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

	loadingHtml = true;
	return static_cast<int>(webview_set_html(handle, html));
}

int WebViewBackend::addInitScript(const char *script)
{
	if (handle == nullptr)
	{
		return -1;
	}

	return static_cast<int>(webview_init(handle, script != nullptr ? script : ""));
}

int WebViewBackend::evaluateJavaScript(const char *script, WebViewResultCallback callback, void *userData)
{
	if (handle == nullptr)
	{
		return -1;
	}

	if (script == nullptr)
	{
		script = "";
	}

	if (callback == nullptr)
	{
		return static_cast<int>(webview_eval(handle, script));
	}

	if (core == nullptr)
	{
		return -2;
	}

	auto wideScript = webview::detail::widen_string(std::string(script));
	webview_t view = handle;
	std::shared_ptr<bool> isOpen = open;

	// Only this newer call says that a script threw: the older one reports that as null.
	ICoreWebView2_21 *core21 = nullptr;
	if (SUCCEEDED(core->QueryInterface(IID_ICoreWebView2_21, reinterpret_cast<void **>(&core21))) && core21 != nullptr)
	{
		auto result = core21->ExecuteScriptWithResult(wideScript.c_str(),
			Microsoft::WRL::Callback<ICoreWebView2ExecuteScriptWithResultCompletedHandler>(
				[callback, userData, view, isOpen](HRESULT errorCode, ICoreWebView2ExecuteScriptResult *executed) -> HRESULT
				{
					BOOL succeeded = FALSE;
					if (FAILED(errorCode) || executed == nullptr || FAILED(executed->get_Succeeded(&succeeded)))
					{
						reportResult(view, isOpen, callback, userData, false, "ExecuteScript failed: " + std::to_string(static_cast<long>(errorCode)));
						return S_OK;
					}

					LPWSTR text = nullptr;
					if (succeeded)
					{
						executed->get_ResultAsJson(&text);
					}
					else
					{
						ICoreWebView2ScriptException *exception = nullptr;
						if (SUCCEEDED(executed->get_Exception(&exception)) && exception != nullptr)
						{
							exception->get_Message(&text);
							exception->Release();
						}
					}

					std::string message = wideToUtf8(text);
					CoTaskMemFree(text);
					reportResult(view, isOpen, callback, userData, succeeded != FALSE, !message.empty() ? message : (succeeded ? "null" : "The script threw"));
					return S_OK;
				})
				.Get());

		core21->Release();
		return SUCCEEDED(result) ? 0 : -3;
	}

	auto result = core->ExecuteScript(wideScript.c_str(),
		Microsoft::WRL::Callback<ICoreWebView2ExecuteScriptCompletedHandler>(
			[callback, userData, view, isOpen](HRESULT errorCode, LPCWSTR json) -> HRESULT
			{
				bool success = SUCCEEDED(errorCode);
				reportResult(view, isOpen, callback, userData, success,
					success ? wideToUtf8(json) : "ExecuteScript failed: " + std::to_string(static_cast<long>(errorCode)));
				return S_OK;
			})
			.Get());

	return SUCCEEDED(result) ? 0 : -3;
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

int WebViewBackend::printToPdf(const char *path, const WebViewPdfOptions &options, WebViewResultCallback callback, void *userData)
{
	if (core == nullptr || path == nullptr || path[0] == '\0')
	{
		return -1;
	}

	ICoreWebView2_7 *core7 = nullptr;
	if (FAILED(core->QueryInterface(IID_ICoreWebView2_7, reinterpret_cast<void **>(&core7))) || core7 == nullptr)
	{
		return -2;
	}

	// Print settings come from the environment; without them PrintToPdf uses WebView2 defaults.
	ICoreWebView2PrintSettings *settings = nullptr;
	ICoreWebView2_2 *core2 = nullptr;
	if (SUCCEEDED(core->QueryInterface(IID_ICoreWebView2_2, reinterpret_cast<void **>(&core2))) && core2 != nullptr)
	{
		ICoreWebView2Environment *environment = nullptr;
		if (SUCCEEDED(core2->get_Environment(&environment)) && environment != nullptr)
		{
			ICoreWebView2Environment6 *environment6 = nullptr;
			if (SUCCEEDED(environment->QueryInterface(IID_ICoreWebView2Environment6, reinterpret_cast<void **>(&environment6))) && environment6 != nullptr)
			{
				environment6->CreatePrintSettings(&settings);
				environment6->Release();
			}

			environment->Release();
		}

		core2->Release();
	}

	if (settings != nullptr)
	{
		if (options.pageWidth > 0)
		{
			settings->put_PageWidth(options.pageWidth);
		}

		if (options.pageHeight > 0)
		{
			settings->put_PageHeight(options.pageHeight);
		}

		if (options.marginTop >= 0)
		{
			settings->put_MarginTop(options.marginTop);
		}

		if (options.marginRight >= 0)
		{
			settings->put_MarginRight(options.marginRight);
		}

		if (options.marginBottom >= 0)
		{
			settings->put_MarginBottom(options.marginBottom);
		}

		if (options.marginLeft >= 0)
		{
			settings->put_MarginLeft(options.marginLeft);
		}

		if (options.landscape != -1)
		{
			settings->put_Orientation(options.landscape == 1 ? COREWEBVIEW2_PRINT_ORIENTATION_LANDSCAPE : COREWEBVIEW2_PRINT_ORIENTATION_PORTRAIT);
		}

		if (options.printBackground != -1)
		{
			settings->put_ShouldPrintBackgrounds(options.printBackground == 1 ? TRUE : FALSE);
		}

		if (options.scale > 0)
		{
			settings->put_ScaleFactor(options.scale);
		}

		settings->put_ShouldPrintHeaderAndFooter(FALSE);
	}

	auto widePath = webview::detail::widen_string(std::string(path));
	webview_t view = handle;
	std::shared_ptr<bool> isOpen = open;
	auto result = core7->PrintToPdf(widePath.c_str(), settings,
		Microsoft::WRL::Callback<ICoreWebView2PrintToPdfCompletedHandler>(
			[callback, userData, view, isOpen](HRESULT errorCode, BOOL isSuccessful) -> HRESULT
			{
				if (callback == nullptr)
				{
					return S_OK;
				}

				bool success = SUCCEEDED(errorCode) && isSuccessful;
				reportResult(view, isOpen, callback, userData, success,
					success ? std::string() : "PrintToPdf failed: " + std::to_string(static_cast<long>(errorCode)));
				return S_OK;
			})
			.Get());

	if (settings != nullptr)
	{
		settings->Release();
	}

	core7->Release();
	return SUCCEEDED(result) ? 0 : -3;
}

bool WebViewBackend::isSupported()
{
	// The runtime comes with Windows 11 but not with every Windows 10, and a webview cannot start without it.
	webview::detail::mswebview2::loader loader;
	LPWSTR version = nullptr;
	bool supported = loader.get_available_browser_version_string(nullptr, &version) == S_OK && version != nullptr;
	CoTaskMemFree(version);
	return supported;
}

int WebViewBackend::processEvents()
{
	int processed = 0;
	MSG message{};
	while (PeekMessage(&message, nullptr, 0, 0, PM_REMOVE))
	{
		if (message.message == WM_QUIT)
		{
			// Leave the quit request for the host's own loop.
			PostQuitMessage(static_cast<int>(message.wParam));
			break;
		}

		TranslateMessage(&message);
		DispatchMessage(&message);
		processed++;
	}

	return processed;
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

					// The page from setHtml is the application's own, so there is nothing to ask. WebView2 gives it a data URL.
					if (loadingHtml && location.compare(0, 5, "data:") == 0)
					{
						loadingHtml = false;
					}
					else if (notifyLocationChanging(location))
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

					// The host stopped it, which is not a failure
					if (status != COREWEBVIEW2_WEB_ERROR_STATUS_OPERATION_CANCELED)
					{
						notifyError("Navigation failed: " + std::to_string(static_cast<int>(status)));
					}

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
