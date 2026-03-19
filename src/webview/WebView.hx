package webview;

import _internal.webview.IWebViewBackend;
import _internal.webview.WebViewBackend;

/**
	A framework-agnostic desktop webview wrapper for Haxe applications.

	Use this class when you want to host web content without depending on OpenFL.
	It exposes navigation, history, focus, sizing, top-level window control,
	messaging, and native-handle access while keeping the backend details private
	to the library.

	## Example

	```haxe
	import webview.WebView;
	import webview.WebViewHint;

	var webView = new WebView(nativeWindowHandle, {
		debug: true
	});

	webView.onLocationChange = function (location:String):Void
	{
		trace("Now visiting " + location);
	};

	webView.setSize(1280, 720, WebViewHint.NONE);
	webView.loadURL("https://haxe.org");
	```
**/
class WebView
{
	/** Whether the current target platform can create a runtime webview. */
	public static inline final isSupported:Bool =
	#if (windows || stagewebview_windows)
	true
	#else
	false
	#end;

	/** The native backend handle for this webview instance. */
	public var handle(get, never):WebViewHandle;

	/** Whether backward history navigation is currently available. */
	public var isHistoryBackEnabled(get, never):Bool;

	/** Whether forward history navigation is currently available. */
	public var isHistoryForwardEnabled(get, never):Bool;

	/** The current location reported by the backend. */
	public var location(get, never):String;

	/**
		Reserved for AIR-style parity and future backend configuration.

		The current Windows backend does not change behavior based on this flag yet.
	**/
	public var mediaPlaybackRequiresUserAction(get, set):Bool;

	/** The current page title reported by the backend. */
	public var title(get, never):String;

	/** Called after the current page finishes loading. */
	public var onComplete:Void->Void;

	/** Called when the backend reports a navigation or runtime error. */
	public var onError:String->Void;

	/** Called when the webview receives focus. */
	public var onFocusIn:Void->Void;

	/** Called when the webview loses focus. */
	public var onFocusOut:Void->Void;

	/** Called after the location changes. */
	public var onLocationChange:String->Void;

	/**
		Called before the location changes.

		Return `true` to cancel the navigation.
	**/
	public var onLocationChanging:String->Bool;

	/** Called when the page posts a message to the host application. */
	public var onMessage:String->Void;

	private var __backend:IWebViewBackend;
	private var __location:String;
	private var __options:WebViewOptions;
	private var __title:String;

	private static var __backendFactory:WebViewOptions->WebViewHandle->IWebViewBackend = __createBackend;

	/**
		Creates a new webview wrapper.

	Pass a native window handle when embedding into an existing application
	window, or omit `window` to let the backend create and own a top-level native
	window. Use `options.debug` to enable backend debugging when supported.

	@param window Optional native parent or child window handle that should host
		the browser surface. Leave this null to create a standalone window.
		@param options Optional construction settings such as debug mode and future
			parity flags.
		@throws Dynamic Thrown when the native backend cannot create a webview.
	**/
	public function new(?window:WebViewHandle, ?options:Dynamic)
	{
		__location = "";
		__title = "";
		__options = __cloneOptions(options);
		__backend = __backendFactory(__options, window);
		__configureCallbacks();
	}

	/**
		Convenience constructor for explicitly embedding into a host window.

		@param window Native handle for the host window.
		@param options Optional construction settings.
		@return A configured `webview.WebView` instance.
	**/
	public static inline function fromWindow(window:WebViewHandle, ?options:Dynamic):WebView
	{
		return new WebView(window, options);
	}

	/**
		Transfers focus into the webview.

		@param direction Optional backend-specific focus direction hint. Use `0`
			when you do not need directional focus behavior.
	**/
	public function assignFocus(direction:Int = 0):Void
	{
		if (__backend != null)
		{
			__backend.assignFocus(direction);
		}
	}

	/**
		Returns whether backward history navigation is available.

		@return `true` when the current page can navigate backward in history.
	**/
	public function canGoBack():Bool
	{
		return __backend != null ? __backend.canGoBack() : false;
	}

	/**
		Returns whether forward history navigation is available.

		@return `true` when the current page can navigate forward in history.
	**/
	public function canGoForward():Bool
	{
		return __backend != null ? __backend.canGoForward() : false;
	}

	/**
		Registers JavaScript that runs on every new document before page scripts.

		This is useful for bootstrapping page-side bridges or instrumentation that
		should survive reloads and navigations.

		@param script JavaScript source to inject on document creation.
	**/
	public function addInitScript(script:String):Void
	{
		if (__backend != null)
		{
			__backend.addInitScript(script);
		}
	}

	/**
		Alias for `dispose()`.

		Use this when you prefer `destroy` naming in non-OpenFL host code.
	**/
	public function destroy():Void
	{
		dispose();
	}

	/**
		Releases the native webview and its backing resources.

		It is safe to call this more than once.
	**/
	public function dispose():Void
	{
		if (__backend == null)
		{
			return;
		}

		__backend.destroy();
		__backend = null;
	}

	/**
		Returns the current location string reported by the backend.

		@return The last known URL, or an empty string when no location is known yet.
	**/
	public function getLocation():String
	{
		if (__backend != null)
		{
			var value = __backend.getLocation();
			if (value != null && value != "")
			{
				__location = value;
			}
		}

		return __location;
	}

	/**
		Returns a backend-specific native handle for advanced integrations.

		@param kind Selects which native object to retrieve.
		@return The requested native handle, or `null` when unavailable on the current
			backend.
	**/
	public function getNativeHandle(kind:NativeHandleKind):WebViewHandle
	{
		return __backend != null ? __backend.getNativeHandle(kind) : null;
	}

	/**
		Returns the current page title reported by the backend.

		@return The last known page title, or an empty string before a title is known.
	**/
	public function getTitle():String
	{
		if (__backend != null)
		{
			var value = __backend.getTitle();
			if (value != null)
			{
				__title = value;
			}
		}

		return __title;
	}

	/**
		Navigates backward in history when available.
	**/
	public function historyBack():Void
	{
		if (__backend != null)
		{
			__backend.historyBack();
		}
	}

	/**
		Navigates forward in history when available.
	**/
	public function historyForward():Void
	{
		if (__backend != null)
		{
			__backend.historyForward();
		}
	}

	/**
		Loads an HTML string into the webview.

		Only `text/html` and `application/xhtml+xml` are currently supported.

		@param text HTML or XHTML markup to render.
		@param mimeType MIME type describing the provided markup.
		@throws Dynamic Thrown when `mimeType` is not one of the supported HTML
			values.

		## Example

		```haxe
		webView.loadString('
			<!doctype html>
			<html>
				<body>
					<h1>Hello from Haxe</h1>
				</body>
			</html>
		');
		```
	**/
	public function loadString(text:String, mimeType:String = "text/html"):Void
	{
		if (mimeType != "text/html" && mimeType != "application/xhtml+xml")
		{
			throw "WebView.loadString only supports text/html and application/xhtml+xml";
		}

		__location = "about:blank";
		__title = "";

		if (__backend != null)
		{
			__backend.setHtml(text);
		}
	}

	/**
		Alias for `navigate()`.

		@param url URL to load.
	**/
	public inline function loadURL(url:String):Void
	{
		navigate(url);
	}

	/**
		Navigates the webview to a remote or local URL.

		@param url Destination URL. This may be an `https://` URL or a local
			`file://` URL.
	**/
	public function navigate(url:String):Void
	{
		__location = url != null ? url : "";
		__title = "";

		if (__backend != null)
		{
			__backend.navigate(url);
		}
	}

	/**
		Posts a message into the page when the backend supports messaging.

		Use this together with JavaScript message listeners such as
		`window.chrome.webview.addEventListener("message", ...)` on the page side.

		@param message Payload string to send to the page.
	**/
	public function postMessage(message:String):Void
	{
		if (__backend != null)
		{
			__backend.postMessage(message);
		}
	}

	/**
		Executes JavaScript in the active document.

		Use this together with `postMessage()` when you want the page to send a
		result back through the normal webview messaging channel.

		@param script JavaScript source to execute in the current page.
	**/
	public function evaluateJavaScript(script:String):Void
	{
		if (__backend != null)
		{
			__backend.evaluateJavaScript(script);
		}
	}

	/**
		Reloads the current page.
	**/
	public function reload():Void
	{
		if (__backend != null)
		{
			__backend.reload();
		}
	}

	/**
		Runs the native event loop for a top-level owned window.

		Call this after `new WebView()` when the webview created its own window and
		should stay alive until the user closes it.
	**/
	public function run():Void
	{
		if (__backend != null)
		{
			__backend.run();
		}
	}

	/**
		Alias for `loadString()`.

		@param html HTML markup to render.
	**/
	public inline function setHtml(html:String):Void
	{
		loadString(html);
	}

	/**
		Applies a viewport-sized native bounds update when supported.

		This is primarily useful when the host framework manages native child window
		bounds separately from overall view sizing.

		@param width New width in pixels.
		@param height New height in pixels.
	**/
	public function setBounds(width:Int, height:Int):Void
	{
		if (__backend != null)
		{
			__backend.setBounds(width, height);
		}
	}

	/**
		Requests a backend resize using the provided sizing hint.

		@param width Requested width in pixels.
		@param height Requested height in pixels.
		@param hints Optional sizing hint for the backend.
	**/
	public function setSize(width:Int, height:Int, hints:WebViewHint = WebViewHint.NONE):Void
	{
		if (__backend != null)
		{
			__backend.setSize(width, height, hints);
		}
	}

	/**
		Sets the native window title when the backend owns a top-level window.

		@param title Text to show in the native title bar.
	**/
	public function setTitle(title:String):Void
	{
		if (__backend != null)
		{
			__backend.setTitle(title);
		}
	}

	/**
		Stops the current navigation or load operation.
	**/
	public function stop():Void
	{
		if (__backend != null)
		{
			__backend.stop();
		}
	}

	/**
		Requests the top-level owned window to close its run loop.
	**/
	public function terminate():Void
	{
		if (__backend != null)
		{
			__backend.terminate();
		}
	}

	@:allow(openfl.media.StageWebView)
	@:dox(hide)
	@:noCompletion
	public function __capturePreviewBase64(format:Int):String
	{
		return __backend != null ? __backend.capturePreviewBase64(format) : null;
	}

	private function __configureCallbacks():Void
	{
		if (__backend == null)
		{
			return;
		}

		__backend.onLocationChanging = __handleLocationChanging;
		__backend.onLocationChange = __handleLocationChange;
		__backend.onComplete = __handleComplete;
		__backend.onError = __handleError;
		__backend.onFocusIn = __handleFocusIn;
		__backend.onFocusOut = __handleFocusOut;
		__backend.onMessage = __handleMessage;
	}

	private function __handleComplete():Void
	{
		__title = getTitle();

		if (onComplete != null)
		{
			onComplete();
		}
	}

	private function __handleError(message:String):Void
	{
		if (onError != null)
		{
			onError(message);
		}
	}

	private function __handleFocusIn():Void
	{
		if (onFocusIn != null)
		{
			onFocusIn();
		}
	}

	private function __handleFocusOut():Void
	{
		if (onFocusOut != null)
		{
			onFocusOut();
		}
	}

	private function __handleLocationChange(location:String):Void
	{
		__location = (location != null && location != "") ? location : (__location != "" ? __location : "about:blank");
		__title = getTitle();

		if (onLocationChange != null)
		{
			onLocationChange(__location);
		}
	}

	private function __handleLocationChanging(location:String):Bool
	{
		return onLocationChanging != null ? onLocationChanging(location) : false;
	}

	private function __handleMessage(message:String):Void
	{
		if (onMessage != null)
		{
			onMessage(message);
		}
	}

	private function __cloneOptions(options:Dynamic):WebViewOptions
	{
		var copy = new WebViewOptions();

		if (options == null)
		{
			return copy;
		}

		copy.debug = __readOption(options, "debug");
		copy.mediaPlaybackRequiresUserAction = __readOption(options, "mediaPlaybackRequiresUserAction");
		copy.userAgent = __readOption(options, "userAgent");
		copy.enableContextMenu = __readOption(options, "enableContextMenu");
		copy.enableKeyboardShortcuts = __readOption(options, "enableKeyboardShortcuts");
		copy.enableDevTools = __readOption(options, "enableDevTools");
		copy.enableStatusBar = __readOption(options, "enableStatusBar");
		copy.enableZoom = __readOption(options, "enableZoom");
		return copy;
	}

	private function __readOption(source:Dynamic, field:String):Dynamic
	{
		return Reflect.isObject(source) && Reflect.hasField(source, field) ? Reflect.field(source, field) : null;
	}

	private static function __createBackend(options:WebViewOptions, window:WebViewHandle):IWebViewBackend
	{
		return new WebViewBackend(window, options);
	}

	private static function __resetBackendFactory():Void
	{
		__backendFactory = __createBackend;
	}

	private static function __setBackendFactory(factory:WebViewOptions->WebViewHandle->IWebViewBackend):Void
	{
		__backendFactory = factory != null ? factory : __createBackend;
	}

	private inline function get_handle():WebViewHandle
	{
		return __backend != null ? __backend.handle : null;
	}

	private inline function get_isHistoryBackEnabled():Bool
	{
		return canGoBack();
	}

	private inline function get_isHistoryForwardEnabled():Bool
	{
		return canGoForward();
	}

	private inline function get_location():String
	{
		return getLocation();
	}

	private inline function get_mediaPlaybackRequiresUserAction():Bool
	{
		return __options != null && __options.mediaPlaybackRequiresUserAction != null ? __options.mediaPlaybackRequiresUserAction : true;
	}

	private inline function get_title():String
	{
		return getTitle();
	}

	private inline function set_mediaPlaybackRequiresUserAction(value:Bool):Bool
	{
		if (__options == null)
		{
			__options = new WebViewOptions();
		}

		__options.mediaPlaybackRequiresUserAction = value;
		return value;
	}
}
