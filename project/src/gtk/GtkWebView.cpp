// Linux engine: the vendored webview.h GTK backend (GTK 3 + WebKitGTK 4.1) plus the WebKitGTK signals
// StageWebView needs for navigation events, messaging, snapshots and printing.
#include <stagewebview/vendor/webview.h>

#include <libintl.h>

#include <cstdint>
#include <cstring>
#include <string>

#include "../PlatformWebView.h"
#include "GtkSupport.h"

namespace stagewebview {

namespace {

static constexpr int HIDDEN_WIDTH = 1024;
static constexpr int HIDDEN_HEIGHT = 1366;
static constexpr const char *MESSAGE_HANDLER = "stagewebview";

class GtkPlatformWebView;

struct GtkPdfRequest
{
	GtkPlatformWebView *owner = nullptr;
	std::string uri;
	WebViewPdfOptions options;
	WebViewPdfCallback callback = nullptr;
	void *userData = nullptr;
	bool tablesSplit = false;
	bool failed = false;
	std::string error;
};

class GtkPlatformWebView : public PlatformWebView
{
public:
	GtkPlatformWebView(webview_t handle, GtkWidget *ownedHost) : handle(handle), ownedHost(ownedHost)
	{
		view = WEBKIT_WEB_VIEW(webview_get_native_handle(handle, WEBVIEW_NATIVE_HANDLE_KIND_BROWSER_CONTROLLER));

		auto *manager = webkit_web_view_get_user_content_manager(view);
		std::string signal = std::string("script-message-received::") + MESSAGE_HANDLER;
		messageHandlerId = g_signal_connect(manager, signal.c_str(), G_CALLBACK(onScriptMessage), this);
		webkit_user_content_manager_register_script_message_handler(manager, MESSAGE_HANDLER);
		webview_init(handle, bridgeScript("function (message) { window.webkit.messageHandlers.stagewebview.postMessage(message); }").c_str());

		g_signal_connect(view, "decide-policy", G_CALLBACK(onDecidePolicy), this);
		g_signal_connect(view, "notify::uri", G_CALLBACK(onUriChanged), this);
		g_signal_connect(view, "load-changed", G_CALLBACK(onLoadChanged), this);
		g_signal_connect(view, "load-failed", G_CALLBACK(onLoadFailed), this);
		g_signal_connect(view, "focus-in-event", G_CALLBACK(onFocusIn), this);
		g_signal_connect(view, "focus-out-event", G_CALLBACK(onFocusOut), this);
	}

	~GtkPlatformWebView() override
	{
		if (view != nullptr)
		{
			g_signal_handlers_disconnect_by_data(view, this);
			auto *manager = webkit_web_view_get_user_content_manager(view);
			g_signal_handler_disconnect(manager, messageHandlerId);
			webkit_user_content_manager_unregister_script_message_handler(manager, MESSAGE_HANDLER);
		}

		webview_destroy(handle);

		if (ownedHost != nullptr)
		{
			gtk_widget_destroy(ownedHost);
		}
	}

	int setSize(int width, int height, int hints) override
	{
		if (ownedHost != nullptr)
		{
			gtk_window_resize(GTK_WINDOW(ownedHost), width, height);
			gtk_widget_set_size_request(GTK_WIDGET(view), width, height);
			return 0;
		}

		return static_cast<int>(webview_set_size(handle, width, height, static_cast<webview_hint_t>(hints)));
	}

	int navigate(const char *url) override
	{
		return static_cast<int>(webview_navigate(handle, url != nullptr ? url : ""));
	}

	int setHtml(const char *html) override
	{
		return static_cast<int>(webview_set_html(handle, html != nullptr ? html : ""));
	}

	int addInitScript(const char *script) override
	{
		return static_cast<int>(webview_init(handle, script));
	}

	int evaluateJavaScript(const char *script) override
	{
		return static_cast<int>(webview_eval(handle, script));
	}

	int historyBack() override
	{
		webkit_web_view_go_back(view);
		return 0;
	}

	int historyForward() override
	{
		webkit_web_view_go_forward(view);
		return 0;
	}

	int reload() override
	{
		webkit_web_view_reload(view);
		return 0;
	}

	int stop() override
	{
		webkit_web_view_stop_loading(view);
		return 0;
	}

	int run() override
	{
		return static_cast<int>(webview_run(handle));
	}

	int terminate() override
	{
		return static_cast<int>(webview_terminate(handle));
	}

	int setTitle(const char *title) override
	{
		return static_cast<int>(webview_set_title(handle, title));
	}

	int assignFocus(int direction) override
	{
		(void)direction;
		gtk_widget_grab_focus(GTK_WIDGET(view));
		return 0;
	}

	int canGoBack() const override
	{
		return webkit_web_view_can_go_back(view) ? 1 : 0;
	}

	int canGoForward() const override
	{
		return webkit_web_view_can_go_forward(view) ? 1 : 0;
	}

	std::string capturePreviewBase64(int format) const override
	{
		struct SnapshotState
		{
			bool done = false;
			cairo_surface_t *surface = nullptr;
		} state;

		webkit_web_view_get_snapshot(view, WEBKIT_SNAPSHOT_REGION_VISIBLE, WEBKIT_SNAPSHOT_OPTIONS_NONE, nullptr,
			[](GObject *source, GAsyncResult *result, gpointer userData)
			{
				auto *snapshot = static_cast<SnapshotState *>(userData);
				snapshot->surface = webkit_web_view_get_snapshot_finish(WEBKIT_WEB_VIEW(source), result, nullptr);
				snapshot->done = true;
			},
			&state);

		while (!state.done)
		{
			g_main_context_iteration(nullptr, TRUE);
		}

		if (state.surface == nullptr)
		{
			return std::string();
		}

		std::string bytes;
		int width = cairo_image_surface_get_width(state.surface);
		int height = cairo_image_surface_get_height(state.surface);

		if (format == 1)
		{
			GdkPixbuf *pixbuf = gdk_pixbuf_get_from_surface(state.surface, 0, 0, width, height);
			gchar *buffer = nullptr;
			gsize size = 0;
			if (pixbuf != nullptr && gdk_pixbuf_save_to_buffer(pixbuf, &buffer, &size, "jpeg", nullptr, "quality", "90", nullptr))
			{
				bytes.assign(buffer, size);
				g_free(buffer);
			}

			if (pixbuf != nullptr)
			{
				g_object_unref(pixbuf);
			}
		}
		else
		{
			cairo_surface_write_to_png_stream(state.surface,
				[](void *closure, const unsigned char *data, unsigned int length) -> cairo_status_t
				{
					static_cast<std::string *>(closure)->append(reinterpret_cast<const char *>(data), length);
					return CAIRO_STATUS_SUCCESS;
				},
				&bytes);
		}

		cairo_surface_destroy(state.surface);
		return base64Encode(reinterpret_cast<const unsigned char *>(bytes.data()), bytes.size());
	}

	std::string getLocation() const override
	{
		const gchar *uri = webkit_web_view_get_uri(view);
		return uri != nullptr ? uri : "";
	}

	std::string getTitle() const override
	{
		const gchar *title = webkit_web_view_get_title(view);
		return title != nullptr ? title : "";
	}

	void *getNativeHandle(int kind) const override
	{
		return webview_get_native_handle(handle, static_cast<webview_native_handle_kind_t>(kind));
	}

	int printToPdf(const char *path, const WebViewPdfOptions &options, WebViewPdfCallback callback, void *userData) override
	{
		gchar *absolutePath = g_canonicalize_filename(path, nullptr);
		gchar *uri = g_filename_to_uri(absolutePath, nullptr, nullptr);
		g_free(absolutePath);
		if (uri == nullptr)
		{
			return -2;
		}

		auto *request = new GtkPdfRequest();
		request->owner = this;
		request->uri = uri;
		request->options = options;
		request->callback = callback;
		request->userData = userData;
		g_free(uri);

		if (options.repeatTableHeaders == 0)
		{
			startPrint(request);
			return 0;
		}

		// Print once the table headers are in place; the script's result does not matter.
		evaluate(tableHeaderScript(options, WEBKIT_PRINT_PIXELS_PER_INCH), [](GObject *, GAsyncResult *, gpointer data)
		{
			auto *pending = static_cast<GtkPdfRequest *>(data);
			pending->tablesSplit = true;
			pending->owner->startPrint(pending);
		}, request);
		return 0;
	}

private:
	void evaluate(const std::string &script, GAsyncReadyCallback done, gpointer data)
	{
#if (WEBKIT_MAJOR_VERSION == 2 && WEBKIT_MINOR_VERSION >= 40) || WEBKIT_MAJOR_VERSION > 2
		webkit_web_view_evaluate_javascript(view, script.c_str(), static_cast<gssize>(script.size()), nullptr, nullptr, nullptr, done, data);
#else
		webkit_web_view_run_javascript(view, script.c_str(), nullptr, done, data);
#endif
	}

	void startPrint(GtkPdfRequest *request)
	{
		const WebViewPdfOptions &options = request->options;

		// GTK names its file printer through gettext, so the lookup has to use the same translation.
		GtkPrintSettings *settings = gtk_print_settings_new();
		gtk_print_settings_set_printer(settings, dgettext("gtk30", "Print to File"));
		gtk_print_settings_set(settings, GTK_PRINT_SETTINGS_OUTPUT_FILE_FORMAT, "pdf");
		gtk_print_settings_set(settings, GTK_PRINT_SETTINGS_OUTPUT_URI, request->uri.c_str());

		if (options.scale > 0)
		{
			gtk_print_settings_set_scale(settings, options.scale * 100.0);
		}

		GtkPageSetup *setup = gtk_page_setup_new();
		GtkPaperSize *paper = options.pageWidth > 0 && options.pageHeight > 0
			? gtk_paper_size_new_custom("stagewebview", "StageWebView", options.pageWidth, options.pageHeight, GTK_UNIT_INCH)
			: gtk_paper_size_new(GTK_PAPER_NAME_LETTER);
		gtk_page_setup_set_paper_size(setup, paper);
		gtk_paper_size_free(paper);

		gtk_page_setup_set_top_margin(setup, options.marginTop >= 0 ? options.marginTop : 0.4, GTK_UNIT_INCH);
		gtk_page_setup_set_right_margin(setup, options.marginRight >= 0 ? options.marginRight : 0.4, GTK_UNIT_INCH);
		gtk_page_setup_set_bottom_margin(setup, options.marginBottom >= 0 ? options.marginBottom : 0.4, GTK_UNIT_INCH);
		gtk_page_setup_set_left_margin(setup, options.marginLeft >= 0 ? options.marginLeft : 0.4, GTK_UNIT_INCH);
		gtk_page_setup_set_orientation(setup, options.landscape == 1 ? GTK_PAGE_ORIENTATION_LANDSCAPE : GTK_PAGE_ORIENTATION_PORTRAIT);

		if (options.printBackground != -1)
		{
			webkit_settings_set_print_backgrounds(webkit_web_view_get_settings(view), options.printBackground == 1 ? TRUE : FALSE);
		}

		WebKitPrintOperation *operation = webkit_print_operation_new(view);
		webkit_print_operation_set_print_settings(operation, settings);
		webkit_print_operation_set_page_setup(operation, setup);
		g_object_unref(settings);
		g_object_unref(setup);

		g_signal_connect(operation, "failed", G_CALLBACK(+[](WebKitPrintOperation *, GError *error, gpointer data)
		{
			auto *pending = static_cast<GtkPdfRequest *>(data);
			pending->failed = true;
			pending->error = error != nullptr && error->message != nullptr ? error->message : "WebKitGTK print operation failed";
		}), request);

		g_signal_connect(operation, "finished", G_CALLBACK(+[](WebKitPrintOperation *finished, gpointer data)
		{
			auto *pending = static_cast<GtkPdfRequest *>(data);
			if (pending->tablesSplit)
			{
				pending->owner->evaluate(tableHeaderRestoreScript(), nullptr, nullptr);
			}

			g_object_unref(finished);

			// Report from an idle callback, outside WebKit's signal emission, so the callback may dispose this
			// webview or create another.
			g_idle_add(+[](gpointer data) -> gboolean
			{
				auto *done = static_cast<GtkPdfRequest *>(data);
				if (done->callback != nullptr)
				{
					done->callback(done->userData, !done->failed, done->error);
				}

				delete done;
				return G_SOURCE_REMOVE;
			}, pending);
		}), request);

		webkit_print_operation_print(operation);
	}

	static void onScriptMessage(WebKitUserContentManager *, WebKitJavascriptResult *result, gpointer data)
	{
		auto *self = static_cast<GtkPlatformWebView *>(data);
		JSCValue *value = webkit_javascript_result_get_js_value(result);
		gchar *text = jsc_value_to_string(value);
		std::string message = text != nullptr ? text : "";
		g_free(text);
		self->notifyMessage(message);
	}

	static gboolean onDecidePolicy(WebKitWebView *, WebKitPolicyDecision *decision, WebKitPolicyDecisionType type, gpointer data)
	{
		if (type != WEBKIT_POLICY_DECISION_TYPE_NAVIGATION_ACTION)
		{
			return FALSE;
		}

		auto *self = static_cast<GtkPlatformWebView *>(data);
		auto *action = webkit_navigation_policy_decision_get_navigation_action(WEBKIT_NAVIGATION_POLICY_DECISION(decision));
		const gchar *uri = webkit_uri_request_get_uri(webkit_navigation_action_get_request(action));

		if (self->notifyLocationChanging(uri != nullptr ? uri : ""))
		{
			webkit_policy_decision_ignore(decision);
			return TRUE;
		}

		return FALSE;
	}

	static void onUriChanged(WebKitWebView *view, GParamSpec *, gpointer data)
	{
		auto *self = static_cast<GtkPlatformWebView *>(data);
		const gchar *uri = webkit_web_view_get_uri(view);
		self->notifyLocationChange(uri != nullptr ? uri : "");
	}

	static void onLoadChanged(WebKitWebView *, WebKitLoadEvent event, gpointer data)
	{
		auto *self = static_cast<GtkPlatformWebView *>(data);

		if (event == WEBKIT_LOAD_STARTED)
		{
			self->loadFailed = false;
		}
		else if (event == WEBKIT_LOAD_FINISHED && !self->loadFailed)
		{
			self->notifyComplete();
		}
	}

	static gboolean onLoadFailed(WebKitWebView *, WebKitLoadEvent, gchar *, GError *error, gpointer data)
	{
		auto *self = static_cast<GtkPlatformWebView *>(data);
		self->loadFailed = true;
		self->notifyError(std::string("Navigation failed: ") + (error != nullptr && error->message != nullptr ? error->message : "unknown error"));
		return FALSE;
	}

	static gboolean onFocusIn(GtkWidget *, GdkEvent *, gpointer data)
	{
		static_cast<GtkPlatformWebView *>(data)->notifyFocusIn();
		return FALSE;
	}

	static gboolean onFocusOut(GtkWidget *, GdkEvent *, gpointer data)
	{
		static_cast<GtkPlatformWebView *>(data)->notifyFocusOut();
		return FALSE;
	}

	webview_t handle = nullptr;
	GtkWidget *ownedHost = nullptr;
	WebKitWebView *view = nullptr;
	gulong messageHandlerId = 0;
	bool loadFailed = false;
};

} // namespace

PlatformWebView *createPlatformWebView(int debug, void *window, const WebViewCreateOptions &options)
{
	if (!gtk::ensureInitialized())
	{
		return nullptr;
	}

	GtkWidget *ownedHost = nullptr;
	if (window == nullptr && options.startHidden == 1)
	{
		// An offscreen window is realized and laid out like any other, but never reaches the screen.
		ownedHost = gtk_offscreen_window_new();
		gtk_window_set_default_size(GTK_WINDOW(ownedHost), HIDDEN_WIDTH, HIDDEN_HEIGHT);
		window = ownedHost;
	}

	webview_t handle = webview_create(debug, window);
	if (handle == nullptr)
	{
		if (ownedHost != nullptr)
		{
			gtk_widget_destroy(ownedHost);
		}

		return nullptr;
	}

	auto *view = GTK_WIDGET(webview_get_native_handle(handle, WEBVIEW_NATIVE_HANDLE_KIND_BROWSER_CONTROLLER));
	auto *settings = webkit_web_view_get_settings(WEBKIT_WEB_VIEW(view));

	if (!options.userAgent.empty())
	{
		webkit_settings_set_user_agent(settings, options.userAgent.c_str());
	}

	if (options.enableDevTools != -1)
	{
		webkit_settings_set_enable_developer_extras(settings, options.enableDevTools == 1 ? TRUE : FALSE);
	}

	if (options.mediaPlaybackRequiresUserAction != -1)
	{
		webkit_settings_set_media_playback_requires_user_gesture(settings, options.mediaPlaybackRequiresUserAction == 1 ? TRUE : FALSE);
	}

	if (ownedHost != nullptr)
	{
		gtk_widget_set_size_request(view, HIDDEN_WIDTH, HIDDEN_HEIGHT);
		gtk_widget_show_all(ownedHost);
	}

	return new GtkPlatformWebView(handle, ownedHost);
}

int PlatformWebView::processEvents()
{
	// Bounded so a page that keeps the loop busy cannot starve the host's own frame.
	int processed = 0;
	while (processed < 1000 && g_main_context_iteration(nullptr, FALSE))
	{
		processed++;
	}

	return processed;
}

} // namespace stagewebview
