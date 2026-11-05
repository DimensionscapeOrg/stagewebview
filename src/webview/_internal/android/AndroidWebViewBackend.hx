package webview._internal.android;

#if android
import webview._internal.IWebViewBackend;
import haxe.Json;
import webview.NativeHandleKind;
import webview.PDFOptions;
import webview.WebViewHandle;
import webview.WebViewHint;
import webview.WebViewOptions;

/**
	Android backend: `android.webkit.WebView` driven through the Java host in
	android/src. Calls go out over JNI and return at once; events come back
	through `processEvents()`, which `webview.WebView.processEvents()` calls.

	Handles are the integer ids the Java host assigns. A host window passed to
	the constructor is a container id from the OpenFL facade.
**/
@:noCompletion
class AndroidWebViewBackend implements IWebViewBackend
{
	private static inline final FIELD_SEPARATOR:String = "\x1F";
	private static inline final PART_SEPARATOR:String = "\x1D";

	private static var __views:Map<Int, AndroidWebViewBackend> = new Map();
	private static var __resultCallbacks:Map<Int, Bool->String->Void> = new Map();
	private static var __nextResultToken:Int = 1;

	public var handle(get, never):WebViewHandle;
	public var onLoad:Void->Void;
	public var onError:String->Void;
	public var onFocusIn:Void->Void;
	public var onFocusOut:Void->Void;
	public var onURLChange:String->Void;
	public var onNavigate:String->Bool;
	public var onMessage:String->Void;

	private var __id:Int = -1;
	private var __ownedContainer:Int = -1;

	public function new(?window:WebViewHandle, ?options:WebViewOptions)
	{
		var config:WebViewOptions = options != null ? options : {};
		var container:Int = window != null ? Std.int(window) : -1;

		// Android has no top-level windows; a visible webview without a host fills the activity.
		if (window == null && config.hidden != true)
		{
			__ownedContainer = AndroidHost.createContainer(0, 0, -1, -1);
			AndroidHost.setContainerVisible(__ownedContainer, true);
			container = __ownedContainer;
		}

		var mediaRequiresGesture = config.autoplay == null ? -1 : (config.autoplay ? 0 : 1);
		__id = AndroidHost.create(container, config.devTools == true, config.userAgent, mediaRequiresGesture, null);
		if (__id <= 0)
		{
			throw "Failed to create a WebView";
		}

		__views.set(__id, this);
		AndroidHost.setInterceptNavigation(__id, true);
	}

	public static function processEvents():Int
	{
		var count = 0;
		var record:String;

		while ((record = AndroidHost.pollEvent()) != null)
		{
			count++;

			var first = record.indexOf(FIELD_SEPARATOR);
			var second = first >= 0 ? record.indexOf(FIELD_SEPARATOR, first + 1) : -1;
			if (second < 0)
			{
				continue;
			}

			var id = Std.parseInt(record.substring(0, first));
			var type = record.substring(first + 1, second);
			var payload = record.substring(second + 1);

			if (type == "pdf" || type == "script")
			{
				__dispatchResult(payload);
				continue;
			}

			var backend = __views.get(id);
			if (backend != null)
			{
				backend.__dispatch(type, payload);
			}
		}

		return count;
	}

	public function addInitScript(script:String):Void
	{
		if (__id > 0)
		{
			AndroidHost.addInitScript(__id, script);
		}
	}

	public function focus(direction:Int):Void
	{
		if (__id > 0)
		{
			AndroidHost.command(__id, "focus");
		}
	}

	public function canGoBack():Bool
	{
		return __id > 0 && AndroidHost.canGoBack(__id);
	}

	public function canGoForward():Bool
	{
		return __id > 0 && AndroidHost.canGoForward(__id);
	}

	public function capturePreviewBase64(format:Int):String
	{
		return __id > 0 ? AndroidHost.capture(__id, format) : null;
	}

	public function close():Void
	{
		if (__id <= 0)
		{
			return;
		}

		AndroidHost.destroy(__id);
		__views.remove(__id);
		__id = -1;

		if (__ownedContainer > 0)
		{
			AndroidHost.destroyContainer(__ownedContainer);
			__ownedContainer = -1;
		}
	}

	public function evaluateJavaScript(script:String, onComplete:Bool->String->Void):Void
	{
		if (__id <= 0)
		{
			if (onComplete != null)
			{
				onComplete(false, "The webview has closed");
			}
		}
		else if (onComplete == null)
		{
			AndroidHost.evaluate(__id, script);
		}
		else
		{
			var token = __nextResultToken++;
			__resultCallbacks.set(token, onComplete);
			AndroidHost.evaluateWithResult(__id, token, script);
		}
	}

	public function getURL():String
	{
		return __id > 0 ? AndroidHost.getLocation(__id) : null;
	}

	public function getNativeHandle(kind:NativeHandleKind):WebViewHandle
	{
		return null;
	}

	public function getTitle():String
	{
		return __id > 0 ? AndroidHost.getTitle(__id) : null;
	}

	public function goBack():Void
	{
		if (__id > 0)
		{
			AndroidHost.command(__id, "back");
		}
	}

	public function goForward():Void
	{
		if (__id > 0)
		{
			AndroidHost.command(__id, "forward");
		}
	}

	public function load(url:String):Void
	{
		// The engine only asks about the navigations a page starts
		if (__id > 0 && (onNavigate == null || !onNavigate(url)) && __id > 0)
		{
			AndroidHost.loadUrl(__id, url != null && url != "" ? url : "about:blank");
		}
	}

	public function postMessage(message:String):Void
	{
		evaluateJavaScript("window.chrome && window.chrome.webview && window.chrome.webview.__stagewebviewDispatch && window.chrome.webview.__stagewebviewDispatch("
			+ Json.stringify(message != null ? message : "") + ");", null);
	}

	public function printToPDF(path:String, options:PDFOptions, onComplete:Bool->String->Void):Void
	{
		if (__id <= 0)
		{
			if (onComplete != null)
			{
				onComplete(false, "The webview has closed");
			}

			return;
		}

		// Chromium repeats <thead> on its own; scale and background printing are not exposed by PrintAttributes.
		var token = __nextResultToken++;
		__resultCallbacks.set(token, onComplete);
		AndroidHost.printToPdf(__id, token, path, options.pageWidth, options.pageHeight, options.marginTop, options.marginRight, options.marginBottom,
			options.marginLeft, options.landscape);
	}

	public function reload():Void
	{
		if (__id > 0)
		{
			AndroidHost.command(__id, "reload");
		}
	}

	public function run():Void {}

	public function setBounds(width:Int, height:Int):Void {}

	public function loadHTML(html:String):Void
	{
		if (__id > 0)
		{
			AndroidHost.loadHtml(__id, html != null ? html : "");
		}
	}

	public function setSize(width:Int, height:Int, hints:WebViewHint = WebViewHint.NONE):Void {}

	public function setWindowTitle(title:String):Void {}

	public function stop():Void
	{
		if (__id > 0)
		{
			AndroidHost.command(__id, "stop");
		}
	}

	public function terminate():Void {}

	private function __dispatch(type:String, payload:String):Void
	{
		switch (type)
		{
			case "message":
				if (onMessage != null) onMessage(payload);

			case "location":
				if (onURLChange != null) onURLChange(payload);

			case "complete":
				if (onLoad != null) onLoad();

			case "error":
				if (onError != null) onError(payload);

			case "focusIn":
				if (onFocusIn != null) onFocusIn();

			case "focusOut":
				if (onFocusOut != null) onFocusOut();

			case "changing":
				var separator = payload.indexOf(PART_SEPARATOR);
				var token = Std.parseInt(payload.substring(0, separator));
				var cancel = onNavigate != null ? onNavigate(payload.substring(separator + 1)) : false;
				if (token != null && token > 0)
				{
					AndroidHost.resolveNavigation(token, cancel);
				}

			default:
		}
	}

	private static function __dispatchResult(payload:String):Void
	{
		var parts = payload.split(PART_SEPARATOR);
		var token = Std.parseInt(parts[0]);
		var callback = __resultCallbacks.get(token);
		__resultCallbacks.remove(token);

		if (callback != null)
		{
			var message = parts.slice(2).join(PART_SEPARATOR);
			callback(parts[1] == "1", message != "" ? message : null);
		}
	}

	private inline function get_handle():WebViewHandle
	{
		return __id > 0 ? __id : null;
	}
}
#end
