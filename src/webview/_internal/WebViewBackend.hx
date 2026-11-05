package webview._internal;

import webview._internal.IWebViewBackend;
import webview._internal.native.WebViewExterns;
import webview.NativeHandleKind;
import webview.PDFOptions;
import webview.WebViewHandle;
import webview.WebViewHint;
import webview.WebViewOptions;

@:build(stagewebview._internal.ExtraParamsMacro.configureBackend())
class WebViewBackend implements IWebViewBackend
{
	public var handle(get, never):WebViewHandle;
	public var onLoad:Void->Void;
	public var onError:String->Void;
	public var onFocusIn:Void->Void;
	public var onFocusOut:Void->Void;
	public var onURLChange:String->Void;
	public var onNavigate:String->Bool;
	public var onMessage:String->Void;

	private var __handle:WebViewHandle;

	public function new(?window:WebViewHandle, ?options:WebViewOptions)
	{
		var config:WebViewOptions = options != null ? options : {};
		var mediaNeedsUserAction = config.autoplay == null ? null : !config.autoplay;
		var userAgent:String = config.userAgent;
		__handle = WebViewExterns.create(config.devTools == true ? 1 : 0, window, userAgent, __boolToNative(mediaNeedsUserAction),
			__boolToNative(config.contextMenu), __boolToNative(config.keyboardShortcuts), __boolToNative(config.devTools),
			__boolToNative(config.statusBar), __boolToNative(config.zoom), __boolToNative(config.hidden));
		if (__handle == null)
		{
			throw "Failed to create a WebView";
		}

		#if hl
		WebViewExterns.setCallbacks(__handle, __onLocationChangingHL, __onLocationChangeHL, __onComplete, __onErrorHL, __onFocusIn, __onFocusOut, __onMessageHL);
		#else
		WebViewExterns.setCallbacks(__handle, __onLocationChanging, __onLocationChange, __onComplete, __onError, __onFocusIn, __onFocusOut, __onMessage);
		#end
	}

	public function close():Void
	{
		if (__handle == null)
		{
			return;
		}

		WebViewExterns.destroy(__handle);
		__handle = null;
	}

	public function capturePreviewBase64(format:Int):String
	{
		if (__handle == null)
		{
			return null;
		}

		return WebViewExterns.capturePreviewBase64(__handle, format);
	}

	public function addInitScript(script:String):Void
	{
		if (__handle == null)
		{
			return;
		}

		WebViewExterns.addInitScript(__handle, script);
	}

	public function load(url:String):Void
	{
		if (__handle == null)
		{
			return;
		}

		WebViewExterns.navigate(__handle, url);
	}

	public function loadHTML(html:String):Void
	{
		if (__handle == null)
		{
			return;
		}

		WebViewExterns.setHtml(__handle, html);
	}

	public function evaluateJavaScript(script:String, onComplete:Bool->String->Void):Void
	{
		if (__handle == null)
		{
			if (onComplete != null)
			{
				onComplete(false, "The webview has closed");
			}

			return;
		}

		var result = WebViewExterns.evaluateJavaScript(__handle, script, onComplete != null ? __resultCallback(onComplete) : null);

		if (result != 0 && onComplete != null)
		{
			onComplete(false, "The platform could not run the script (" + result + ")");
		}
	}

	public function goBack():Void
	{
		if (__handle == null)
		{
			return;
		}

		WebViewExterns.historyBack(__handle);
	}

	public function goForward():Void
	{
		if (__handle == null)
		{
			return;
		}

		WebViewExterns.historyForward(__handle);
	}

	public function reload():Void
	{
		if (__handle == null)
		{
			return;
		}

		WebViewExterns.reload(__handle);
	}

	public function stop():Void
	{
		if (__handle == null)
		{
			return;
		}

		WebViewExterns.stop(__handle);
	}

	public function run():Void
	{
		if (__handle == null)
		{
			return;
		}

		WebViewExterns.run(__handle);
	}

	public function terminate():Void
	{
		if (__handle == null)
		{
			return;
		}

		WebViewExterns.terminate(__handle);
	}

	public function setWindowTitle(title:String):Void
	{
		if (__handle == null)
		{
			return;
		}

		WebViewExterns.setTitle(__handle, title);
	}

	public function postMessage(message:String):Void
	{
		if (__handle == null)
		{
			return;
		}

		WebViewExterns.postMessage(__handle, message);
	}

	public function printToPDF(path:String, options:PDFOptions, onComplete:Bool->String->Void):Void
	{
		if (__handle == null)
		{
			if (onComplete != null)
			{
				onComplete(false, "The webview has closed");
			}

			return;
		}

		var result = WebViewExterns.printToPdf(__handle, path, options.pageWidth, options.pageHeight, options.marginTop, options.marginRight,
			options.marginBottom, options.marginLeft, options.landscape ? 1 : 0, options.printBackground ? 1 : 0, options.scale,
			options.repeatTableHeaders ? 1 : 0, onComplete != null ? __resultCallback(onComplete) : null);

		if (result != 0 && onComplete != null)
		{
			onComplete(false, "The platform could not start printing (" + result + ")");
		}
	}

	public function focus(direction:Int):Void
	{
		if (__handle == null)
		{
			return;
		}

		WebViewExterns.assignFocus(__handle, direction);
	}

	public function canGoBack():Bool
	{
		if (__handle == null)
		{
			return false;
		}

		return WebViewExterns.canGoBack(__handle) != 0;
	}

	public function canGoForward():Bool
	{
		if (__handle == null)
		{
			return false;
		}

		return WebViewExterns.canGoForward(__handle) != 0;
	}

	public function getURL():String
	{
		if (__handle == null)
		{
			return null;
		}

		return WebViewExterns.getLocation(__handle);
	}

	public function getTitle():String
	{
		if (__handle == null)
		{
			return null;
		}

		return WebViewExterns.getTitle(__handle);
	}

	public function setSize(width:Int, height:Int, hints:WebViewHint = WebViewHint.NONE):Void
	{
		if (__handle == null)
		{
			return;
		}

		WebViewExterns.setSize(__handle, width, height, hints);
	}

	public function setBounds(width:Int, height:Int):Void
	{
		#if (windows || stagewebview_windows)
		var controller = getNativeHandle(NativeHandleKind.BROWSER_CONTROLLER);
		if (controller != null)
		{
			WebViewExterns.webView2ControllerSetBounds(controller, width, height);
		}
		#end
	}

	public function getNativeHandle(kind:NativeHandleKind):WebViewHandle
	{
		if (__handle == null)
		{
			return null;
		}

		return WebViewExterns.getNativeHandle(__handle, kind);
	}

	private function __onLocationChanging(location:String):Bool
	{
		return onNavigate != null ? onNavigate(location) : false;
	}

	private function __onLocationChange(location:String):Void
	{
		if (onURLChange != null)
		{
			onURLChange(location);
		}
	}

	private function __onComplete():Void
	{
		if (onLoad != null)
		{
			onLoad();
		}
	}

	private function __onError(message:String):Void
	{
		if (onError != null)
		{
			onError(message);
		}
	}

	private function __onFocusIn():Void
	{
		if (onFocusIn != null)
		{
			onFocusIn();
		}
	}

	private function __onFocusOut():Void
	{
		if (onFocusOut != null)
		{
			onFocusOut();
		}
	}

	private function __onMessage(message:String):Void
	{
		if (onMessage != null)
		{
			onMessage(message);
		}
	}

	private function __resultCallback(onComplete:Bool->String->Void):Dynamic
	{
		return function(success:Bool, message:Dynamic):Void
		{
			#if hl
			onComplete(success, message != null ? __dynamicToString(message) : null);
			#else
			onComplete(success, message);
			#end
		};
	}

	private inline function get_handle():WebViewHandle
	{
		return __handle;
	}

	private static inline function __boolToNative(value:Null<Bool>):Int
	{
		return value == null ? -1 : (value ? 1 : 0);
	}

	#if hl
	private inline function __dynamicToString(value:Dynamic):String
	{
		return value != null ? @:privateAccess String.fromUTF8(cast value) : null;
	}

	private function __onLocationChangingHL(value:Dynamic):Bool
	{
		return __onLocationChanging(__dynamicToString(value));
	}

	private function __onLocationChangeHL(value:Dynamic):Void
	{
		__onLocationChange(__dynamicToString(value));
	}

	private function __onErrorHL(value:Dynamic):Void
	{
		__onError(__dynamicToString(value));
	}

	private function __onMessageHL(value:Dynamic):Void
	{
		__onMessage(__dynamicToString(value));
	}
	#end
}
