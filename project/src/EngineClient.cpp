// The platform engine over stagewebview-gtk.so, in place of gtk/GtkWebView.cpp and gtk/GtkHostWindow.cpp, for a framework
// whose binary cannot link WebKitGTK: see stagewebview/Engine.h. The library is opened when a webview is first asked for,
// so nothing depends on it until then.
#if !defined(_WIN32)

#include <dlfcn.h>
#include <unistd.h>

#include <string>

#include <stagewebview/Engine.h>
#include <stagewebview/WindowBackend.h>

#include "PlatformWebView.h"

namespace stagewebview {

namespace {

static const char *LIBRARY = "stagewebview-gtk.so";

void *openBeside(const std::string &binary)
{
	size_t slash = binary.rfind('/');
	return slash != std::string::npos ? dlopen((binary.substr(0, slash + 1) + LIBRARY).c_str(), RTLD_NOW | RTLD_LOCAL) : nullptr;
}

void *openLibrary()
{
	// Beside this binary, or beside the program when this one is linked in, and then wherever the system looks
	Dl_info info;
	void *library = dladdr(reinterpret_cast<void *>(&openLibrary), &info) != 0 && info.dli_fname != nullptr ? openBeside(info.dli_fname) : nullptr;

	if (library == nullptr)
	{
		char program[4096];
		ssize_t length = readlink("/proc/self/exe", program, sizeof(program));
		if (length > 0)
		{
			library = openBeside(std::string(program, static_cast<size_t>(length)));
		}
	}

	return library != nullptr ? library : dlopen(LIBRARY, RTLD_NOW | RTLD_LOCAL);
}

const StageWebViewEngine *findEngine()
{
	void *library = openLibrary();
	if (library == nullptr)
	{
		return nullptr;
	}

	auto *entry = reinterpret_cast<const StageWebViewEngine *(*)(void)>(dlsym(library, "stagewebview_engine"));
	const StageWebViewEngine *found = entry != nullptr ? entry() : nullptr;
	if (found == nullptr || found->version != STAGEWEBVIEW_ENGINE_VERSION)
	{
		dlclose(library);
		return nullptr;
	}

	return found;
}

const StageWebViewEngine *engine()
{
	static const StageWebViewEngine *found = findEngine();
	return found;
}

std::string take(char *value)
{
	std::string text = value != nullptr ? value : "";
	if (value != nullptr)
	{
		engine()->freeString(value);
	}

	return text;
}

struct ClientRequest
{
	WebViewResultCallback callback;
	void *userData;
};

void onResult(void *userData, int success, const char *message)
{
	auto *request = static_cast<ClientRequest *>(userData);
	request->callback(request->userData, success != 0, message != nullptr ? message : "");
	delete request;
}

class EngineWebView : public PlatformWebView
{
public:
	explicit EngineWebView(void *view): view(view)
	{
		StageWebViewEngineCallbacks set;
		set.userData = this;
		set.onLocationChanging = onLocationChanging;
		set.onLocationChange = onLocationChange;
		set.onComplete = onComplete;
		set.onError = onError;
		set.onFocusIn = onFocusIn;
		set.onFocusOut = onFocusOut;
		set.onMessage = onMessage;
		engine()->setCallbacks(view, &set);
	}

	~EngineWebView() override
	{
		engine()->destroy(view);
	}

	int setSize(int width, int height, int hints) override
	{
		return engine()->setSize(view, width, height, hints);
	}

	int navigate(const char *url) override
	{
		return engine()->navigate(view, url);
	}

	int setHtml(const char *html) override
	{
		return engine()->setHtml(view, html);
	}

	int addInitScript(const char *script) override
	{
		return engine()->addInitScript(view, script);
	}

	int evaluateJavaScript(const char *script, WebViewResultCallback callback, void *userData) override
	{
		if (callback == nullptr)
		{
			return engine()->evaluateJavaScript(view, script, nullptr, nullptr);
		}

		auto *request = new ClientRequest{callback, userData};
		int result = engine()->evaluateJavaScript(view, script, onResult, request);
		if (result != 0)
		{
			delete request;
		}

		return result;
	}

	int historyBack() override
	{
		return engine()->historyBack(view);
	}

	int historyForward() override
	{
		return engine()->historyForward(view);
	}

	int reload() override
	{
		return engine()->reload(view);
	}

	int stop() override
	{
		return engine()->stop(view);
	}

	int run() override
	{
		return engine()->run(view);
	}

	int terminate() override
	{
		return engine()->terminate(view);
	}

	int setTitle(const char *title) override
	{
		return engine()->setTitle(view, title);
	}

	int assignFocus(int direction) override
	{
		return engine()->assignFocus(view, direction);
	}

	int canGoBack() const override
	{
		return engine()->canGoBack(view);
	}

	int canGoForward() const override
	{
		return engine()->canGoForward(view);
	}

	std::string capturePreviewBase64(int format) const override
	{
		return take(engine()->capturePreviewBase64(view, format));
	}

	std::string getLocation() const override
	{
		return take(engine()->getLocation(view));
	}

	std::string getTitle() const override
	{
		return take(engine()->getTitle(view));
	}

	void *getNativeHandle(int kind) const override
	{
		return engine()->getNativeHandle(view, kind);
	}

	int printToPdf(const char *path, const WebViewPdfOptions &options, WebViewResultCallback callback, void *userData) override
	{
		StageWebViewEnginePdfOptions pdf;
		pdf.pageWidth = options.pageWidth;
		pdf.pageHeight = options.pageHeight;
		pdf.marginTop = options.marginTop;
		pdf.marginRight = options.marginRight;
		pdf.marginBottom = options.marginBottom;
		pdf.marginLeft = options.marginLeft;
		pdf.landscape = options.landscape;
		pdf.printBackground = options.printBackground;
		pdf.scale = options.scale;
		pdf.repeatTableHeaders = options.repeatTableHeaders;

		auto *request = new ClientRequest{callback, userData};
		int result = engine()->printToPdf(view, path, &pdf, onResult, request);
		if (result != 0)
		{
			delete request;
		}

		return result;
	}

private:
	static int onLocationChanging(void *userData, const char *location)
	{
		return static_cast<EngineWebView *>(userData)->notifyLocationChanging(location) ? 1 : 0;
	}

	static void onLocationChange(void *userData, const char *location)
	{
		static_cast<EngineWebView *>(userData)->notifyLocationChange(location);
	}

	static void onComplete(void *userData)
	{
		static_cast<EngineWebView *>(userData)->notifyComplete();
	}

	static void onError(void *userData, const char *message)
	{
		static_cast<EngineWebView *>(userData)->notifyError(message);
	}

	static void onFocusIn(void *userData)
	{
		static_cast<EngineWebView *>(userData)->notifyFocusIn();
	}

	static void onFocusOut(void *userData)
	{
		static_cast<EngineWebView *>(userData)->notifyFocusOut();
	}

	static void onMessage(void *userData, const char *message)
	{
		static_cast<EngineWebView *>(userData)->notifyMessage(message);
	}

	void *view;
};

} // namespace

PlatformWebView *createPlatformWebView(int debug, void *window, const WebViewCreateOptions &options)
{
	if (engine() == nullptr)
	{
		return nullptr;
	}

	StageWebViewEngineOptions created;
	created.mediaPlaybackRequiresUserAction = options.mediaPlaybackRequiresUserAction;
	created.userAgent = options.userAgent.c_str();
	created.enableContextMenu = options.enableContextMenu;
	created.enableKeyboardShortcuts = options.enableKeyboardShortcuts;
	created.enableDevTools = options.enableDevTools;
	created.enableStatusBar = options.enableStatusBar;
	created.enableZoom = options.enableZoom;
	created.startHidden = options.startHidden;

	void *view = engine()->create(debug, window, &created);
	return view != nullptr ? new EngineWebView(view) : nullptr;
}

bool PlatformWebView::isSupported()
{
	return engine() != nullptr && engine()->isSupported() != 0;
}

int PlatformWebView::processEvents()
{
	return engine() != nullptr ? engine()->processEvents() : 0;
}

void *windowCreateChildWindow(void *parentHandle, int x, int y, int width, int height)
{
	return engine() != nullptr ? engine()->windowCreateChildWindow(parentHandle, x, y, width, height) : nullptr;
}

void windowShow(void *handle)
{
	if (engine() != nullptr)
	{
		engine()->windowShow(handle);
	}
}

void windowHide(void *handle)
{
	if (engine() != nullptr)
	{
		engine()->windowHide(handle);
	}
}

void windowDestroy(void *handle)
{
	if (engine() != nullptr)
	{
		engine()->windowDestroy(handle);
	}
}

void windowMove(void *handle, int x, int y, int width, int height)
{
	if (engine() != nullptr)
	{
		engine()->windowMove(handle, x, y, width, height);
	}
}

void windowSetFocus(void *handle)
{
	if (engine() != nullptr)
	{
		engine()->windowSetFocus(handle);
	}
}

} // namespace stagewebview

#endif
