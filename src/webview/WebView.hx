package webview;

import webview._internal.IWebViewBackend;
#if android
import webview._internal.android.AndroidWebViewBackend;
#else
import webview._internal.WebViewBackend;
#end

/**
	A framework-agnostic webview for Haxe applications.

	Backends: WebView2 on Windows, WebKitGTK on Linux, WKWebView on macOS and
	iOS, and `android.webkit.WebView` on Android.

	Use this class when you want to host web content without depending on OpenFL.
	It exposes navigation, history, focus, sizing, top-level window control,
	messaging, and native-handle access while keeping the backend details private
	to the library.

	## Example

	```haxe
	import webview.WebView;

	var webView = new WebView(nativeWindowHandle, {devTools: true});

	webView.onURLChange = function(url:String):Void
	{
		trace("Now visiting " + url);
	};

	webView.resize(1280, 720);
	webView.load("https://haxe.org");
	```
**/
class WebView
{
	/**
		Whether a webview can be created here: `false` on targets without a backend,
		and on Windows when the WebView2 Runtime is not installed.
	**/
	public static var isSupported(get, never):Bool;

	/** Whether there is a page to go back to. */
	public var canGoBack(get, never):Bool;

	/** Whether there is a page to go forward to. */
	public var canGoForward(get, never):Bool;

	/** The native backend handle for this webview instance. */
	public var handle(get, never):WebViewHandle;

	/** The title of the current page. On WebKitGTK it can update just after `onLoad`. */
	public var title(get, never):String;

	/** The URL of the current page, which is `about:blank` for a page from `loadHTML()`. */
	public var url(get, never):String;

	/** Called when a page could not be loaded, or the backend reports an error. */
	public var onError:String->Void;

	/** Called when the webview takes the focus. */
	public var onFocusIn:Void->Void;

	/** Called when the webview loses the focus. */
	public var onFocusOut:Void->Void;

	/** Called when a page has finished loading. */
	public var onLoad:Void->Void;

	/** Called for each message the page posted. */
	public var onMessage:String->Void;

	/**
		Called before the webview goes to a URL, while the engine waits, for `load()`
		and for the page's own navigations. A page from `loadHTML()` goes nowhere, so
		it is not asked about.

		Return `true` to cancel the navigation.
	**/
	public var onNavigate:String->Bool;

	/** Called after the webview went to a URL. */
	public var onURLChange:String->Void;

	private var __backend:IWebViewBackend;
	private var __embedded:Bool;
	private var __title:String;
	private var __url:String;

	private static var __backendFactory:WebViewOptions->WebViewHandle->IWebViewBackend = __createBackend;

	/**
		Creates a new webview.

		Pass a native window handle to embed it in an existing application window,
		or omit `window` to let the backend create and own a top-level native window.

		@param window Optional native window that hosts the browser surface.
		@param options Optional construction settings.
		@throws Dynamic Thrown when the native backend cannot create a webview.
	**/
	public function new(?window:WebViewHandle, ?options:WebViewOptions)
	{
		__embedded = window != null;
		__title = "";
		__url = "";
		__backend = __backendFactory(options != null ? options : {}, window);
		__configureCallbacks();
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
		Releases the native webview and its backing resources.

		It is safe to call this more than once.
	**/
	public function close():Void
	{
		if (__backend == null)
		{
			return;
		}

		__backend.close();
		__backend = null;
	}

	/**
		Runs JavaScript in the current page.

		The callback runs from the event loop, as `printToPDF()`'s does. A script's
		value is the one of its last statement, as JSON. `undefined` gives `null`, a
		promise is not waited for, and what a value JSON has no form for gives
		depends on the engine: a function is `{}` on WebView2 and `null` elsewhere. A
		script that throws fails with why, but Android and older WebView2 Runtimes
		give `null` instead.

		@param script JavaScript source to run.
		@param onComplete Receives `true` and the value, or `false` and an error
			message.
	**/
	public function evaluateJavaScript(script:String, ?onComplete:(success:Bool, result:String)->Void):Void
	{
		if (__backend != null)
		{
			__backend.evaluateJavaScript(script, onComplete);
		}
		else if (onComplete != null)
		{
			onComplete(false, "The webview has closed");
		}
	}

	/**
		Gives the webview the focus.

		@param direction Optional backend-specific focus direction hint. Use `0`
			when you do not need directional focus behavior.
	**/
	public function focus(direction:Int = 0):Void
	{
		if (__backend != null)
		{
			__backend.focus(direction);
		}
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
		Goes back to the previous page, if there is one.
	**/
	public function goBack():Void
	{
		if (__backend != null)
		{
			__backend.goBack();
		}
	}

	/**
		Goes forward to the next page, if there is one.
	**/
	public function goForward():Void
	{
		if (__backend != null)
		{
			__backend.goForward();
		}
	}

	/**
		Goes to a URL.

		@param url Destination URL. This may be an `https://` URL or a local
			`file://` URL.
	**/
	public function load(url:String):Void
	{
		__url = url != null ? url : "";
		__title = "";

		if (__backend != null)
		{
			__backend.load(url);
		}
	}

	/**
		Shows HTML as a page of its own.

		## Example

		```haxe
		webView.loadHTML('
			<!doctype html>
			<html>
				<body>
					<h1>Hello from Haxe</h1>
				</body>
			</html>
		');
		```

		@param html HTML markup to render.
	**/
	public function loadHTML(html:String):Void
	{
		__url = "about:blank";
		__title = "";

		if (__backend != null)
		{
			__backend.loadHTML(html);
		}
	}

	/**
		Sends a message to the page.

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
		Saves the loaded page as a PDF file.

		Printing uses the platform's own print engine: WebView2 `PrintToPdf` on
		Windows, a WebKitGTK print operation on Linux, the WebKit print path on
		macOS and iOS, and `PrintDocumentAdapter` on Android. It works for a
		webview created with `hidden`, so no window has to be visible.

		The callback runs from the event loop on the thread that calls
		`processEvents()`, never from inside the engine's own handler, so it may
		close this webview or create another. On Windows, macOS and iOS the
		host's normal event loop also delivers it.

		@param path Destination file. Relative paths resolve against the current
			working directory.
		@param options Paper size, margins and other page settings. Defaults to US
			Letter with 0.4 inch margins.
		@param onComplete Receives `true` and `null` on success, or `false` and an
			error message.
	**/
	public function printToPDF(path:String, ?options:PDFOptions, ?onComplete:(success:Bool, error:String)->Void):Void
	{
		if (__backend == null)
		{
			if (onComplete != null)
			{
				onComplete(false, "The webview has closed");
			}

			return;
		}

		#if sys
		path = sys.FileSystem.absolutePath(path);

		// Check the folder here so a missing one fails the same way everywhere, whatever the engine would do with it.
		var directory = haxe.io.Path.directory(path);
		if (directory != "" && !sys.FileSystem.exists(directory))
		{
			if (onComplete != null)
			{
				onComplete(false, "The folder does not exist: " + directory);
			}

			return;
		}
		#end

		if (options == null)
		{
			options = {};
		}

		__backend.printToPDF(path, {
			landscape: options.landscape == true,
			marginBottom: options.marginBottom != null ? options.marginBottom : 0.4,
			marginLeft: options.marginLeft != null ? options.marginLeft : 0.4,
			marginRight: options.marginRight != null ? options.marginRight : 0.4,
			marginTop: options.marginTop != null ? options.marginTop : 0.4,
			pageHeight: options.pageHeight != null ? options.pageHeight : 11,
			pageWidth: options.pageWidth != null ? options.pageWidth : 8.5,
			printBackground: options.printBackground != false,
			repeatTableHeaders: options.repeatTableHeaders != false,
			scale: options.scale != null ? options.scale : 1
		}, onComplete);
	}

	/**
		Runs pending native webview work without blocking.

		Linux (GTK) and Android deliver page events, messages, script values and
		`printToPDF()` results only when this is called, so call it once per frame
		from your main loop. The OpenFL `StageWebView` facade does this for you. On
		Windows, macOS and iOS the host's event loop already does the same work and
		this call is optional.

		@return The number of native events handled.
	**/
	public static function processEvents():Int
	{
		#if android
		return AndroidWebViewBackend.processEvents();
		#else
		return webview._internal.native.WebViewExterns.processEvents();
		#end
	}

	/**
		Loads the current page again.
	**/
	public function reload():Void
	{
		if (__backend != null)
		{
			__backend.reload();
		}
	}

	/**
		Resizes the webview.

		A webview in its own window resizes the window. One embedded in a host window
		fills what it is given: the host moves and sizes the native widget, and this
		tells the engine.

		@param width New width in pixels.
		@param height New height in pixels.
		@param hints How the size applies to a webview's own window.
	**/
	public function resize(width:Int, height:Int, hints:WebViewHint = WebViewHint.NONE):Void
	{
		if (__backend == null)
		{
			return;
		}

		if (__embedded)
		{
			__backend.setBounds(width, height);
		}
		else
		{
			__backend.setSize(width, height, hints);
		}
	}

	/**
		Runs the native event loop for a webview in its own window.

		Call this after `new WebView()` when the webview should stay alive until the
		user closes its window.
	**/
	public function run():Void
	{
		if (__backend != null)
		{
			__backend.run();
		}
	}

	/**
		Sets the title of a webview's own window.

		@param title Text to show in the native title bar.
	**/
	public function setWindowTitle(title:String):Void
	{
		if (__backend != null)
		{
			__backend.setWindowTitle(title);
		}
	}

	/**
		Stops loading the current page.
	**/
	public function stop():Void
	{
		if (__backend != null)
		{
			__backend.stop();
		}
	}

	/**
		Asks the event loop of a webview's own window to end.
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

		__backend.onError = __handleError;
		__backend.onFocusIn = __handleFocusIn;
		__backend.onFocusOut = __handleFocusOut;
		__backend.onLoad = __handleLoad;
		__backend.onMessage = __handleMessage;
		__backend.onNavigate = __handleNavigate;
		__backend.onURLChange = __handleURLChange;
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

	private function __handleLoad():Void
	{
		__title = title;

		if (onLoad != null)
		{
			onLoad();
		}
	}

	private function __handleMessage(message:String):Void
	{
		if (onMessage != null)
		{
			onMessage(message);
		}
	}

	private function __handleNavigate(url:String):Bool
	{
		return onNavigate != null ? onNavigate(url) : false;
	}

	private function __handleURLChange(url:String):Void
	{
		__url = (url != null && url != "") ? url : (__url != "" ? __url : "about:blank");
		__title = title;

		if (onURLChange != null)
		{
			onURLChange(__url);
		}
	}

	private static function __createBackend(options:WebViewOptions, window:WebViewHandle):IWebViewBackend
	{
		#if android
		return new AndroidWebViewBackend(window, options);
		#else
		return new WebViewBackend(window, options);
		#end
	}

	private static function __resetBackendFactory():Void
	{
		__backendFactory = __createBackend;
	}

	private static function __setBackendFactory(factory:WebViewOptions->WebViewHandle->IWebViewBackend):Void
	{
		__backendFactory = factory != null ? factory : __createBackend;
	}

	private function get_canGoBack():Bool
	{
		return __backend != null ? __backend.canGoBack() : false;
	}

	private function get_canGoForward():Bool
	{
		return __backend != null ? __backend.canGoForward() : false;
	}

	private inline function get_handle():WebViewHandle
	{
		return __backend != null ? __backend.handle : null;
	}

	private static function get_isSupported():Bool
	{
		#if (stagewebview_supported && android)
		return true;
		#elseif stagewebview_supported
		return webview._internal.native.WebViewExterns.isSupported();
		#else
		return false;
		#end
	}

	private function get_title():String
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

	private function get_url():String
	{
		if (__backend != null)
		{
			var value = __backend.getURL();
			if (value != null && value != "")
			{
				__url = value;
			}
		}

		return __url;
	}
}
