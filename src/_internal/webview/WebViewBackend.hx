package _internal.webview;

import _internal.webview.IWebViewBackend;
import _internal.webview.native.WebViewExterns;
import webview.NativeHandleKind;
import webview.WebViewHandle;
import webview.WebViewHint;
import webview.WebViewOptions;

class WebViewBackend implements IWebViewBackend
{
	public var handle(get, never):WebViewHandle;
	public var onComplete:Void->Void;
	public var onError:String->Void;
	public var onFocusIn:Void->Void;
	public var onFocusOut:Void->Void;
	public var onLocationChange:String->Void;
	public var onLocationChanging:String->Bool;
	public var onMessage:String->Void;

	private var __handle:WebViewHandle;

	public function new(?window:WebViewHandle, ?options:WebViewOptions)
	{
		var config = options != null ? options : new WebViewOptions();
		var debug = config.debug == true;
		__handle = WebViewExterns.create(debug ? 1 : 0, window, config.userAgent, __boolToNative(config.mediaPlaybackRequiresUserAction),
			__boolToNative(config.enableContextMenu), __boolToNative(config.enableKeyboardShortcuts), __boolToNative(config.enableDevTools),
			__boolToNative(config.enableStatusBar), __boolToNative(config.enableZoom));
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

	public function destroy():Void
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

	public function navigate(url:String):Void
	{
		if (__handle == null)
		{
			return;
		}

		WebViewExterns.navigate(__handle, url);
	}

	public function setHtml(html:String):Void
	{
		if (__handle == null)
		{
			return;
		}

		WebViewExterns.setHtml(__handle, html);
	}

	public function historyBack():Void
	{
		if (__handle == null)
		{
			return;
		}

		WebViewExterns.historyBack(__handle);
	}

	public function historyForward():Void
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

	public function setTitle(title:String):Void
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

	public function assignFocus(direction:Int):Void
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

	public function getLocation():String
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
		return onLocationChanging != null ? onLocationChanging(location) : false;
	}

	private function __onLocationChange(location:String):Void
	{
		if (onLocationChange != null)
		{
			onLocationChange(location);
		}
	}

	private function __onComplete():Void
	{
		if (onComplete != null)
		{
			onComplete();
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
