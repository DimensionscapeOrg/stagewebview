package _internal.webview.native;

import webview.WebViewHandle;

#if cpp
import cpp.ConstCharStar;

@:keep
@:noPrivateAccess
@:buildXml("<section if=\"stagewebview_root\"><include name=\"${stagewebview_root}/build/BuildNative.xml\"/></section><section unless=\"stagewebview_root\"><include name=\"${haxelib:StageWebView}/build/BuildNative.xml\"/></section>")
@:include("lib/WebViewBindings.h")
@:native("stagewebview::HxcppWebViewBindings")
extern class WebViewExterns
{
	static function create(debug:Int, window:WebViewHandle, userAgent:ConstCharStar, mediaPlaybackRequiresUserAction:Int, enableContextMenu:Int,
		enableKeyboardShortcuts:Int, enableDevTools:Int, enableStatusBar:Int, enableZoom:Int):WebViewHandle;
	static function destroy(w:WebViewHandle):Void;
	static function setSize(w:WebViewHandle, width:Int, height:Int, hints:Int):Int;
	static function navigate(w:WebViewHandle, url:ConstCharStar):Int;
	static function setHtml(w:WebViewHandle, html:ConstCharStar):Int;
	static function addInitScript(w:WebViewHandle, script:ConstCharStar):Int;
	static function evaluateJavaScript(w:WebViewHandle, script:ConstCharStar):Int;
	static function setCallbacks(w:WebViewHandle, onLocationChanging:Dynamic, onLocationChange:Dynamic, onComplete:Dynamic, onError:Dynamic, onFocusIn:Dynamic, onFocusOut:Dynamic, onMessage:Dynamic):Void;
	static function historyBack(w:WebViewHandle):Int;
	static function historyForward(w:WebViewHandle):Int;
	static function reload(w:WebViewHandle):Int;
	static function stop(w:WebViewHandle):Int;
	static function run(w:WebViewHandle):Int;
	static function terminate(w:WebViewHandle):Int;
	static function setTitle(w:WebViewHandle, title:ConstCharStar):Int;
	static function postMessage(w:WebViewHandle, message:ConstCharStar):Int;
	static function assignFocus(w:WebViewHandle, direction:Int):Int;
	static function canGoBack(w:WebViewHandle):Int;
	static function canGoForward(w:WebViewHandle):Int;
	static function capturePreviewBase64(w:WebViewHandle, format:Int):String;
	static function getLocation(w:WebViewHandle):String;
	static function getTitle(w:WebViewHandle):String;
	static function getNativeHandle(w:WebViewHandle, kind:Int):WebViewHandle;
	static function webView2ControllerSetBounds(controller:WebViewHandle, width:Int, height:Int):Void;
}
#elseif hl
import hl.Bytes;

@:keep
@:hlNative("stagewebview", "hl_webview_")
extern class WebViewExterns
{
	static function create(debug:Int, window:WebViewHandle, userAgent:String, mediaPlaybackRequiresUserAction:Int, enableContextMenu:Int,
		enableKeyboardShortcuts:Int, enableDevTools:Int, enableStatusBar:Int, enableZoom:Int):WebViewHandle;
	static function destroy(w:WebViewHandle):Void;
	static function set_size(w:WebViewHandle, width:Int, height:Int, hints:Int):Int;
	static function navigate(w:WebViewHandle, url:String):Int;
	static function set_html(w:WebViewHandle, html:String):Int;
	static function add_init_script(w:WebViewHandle, script:String):Int;
	static function evaluate_javascript(w:WebViewHandle, script:String):Int;
	static function set_callbacks(w:WebViewHandle, onLocationChanging:Dynamic, onLocationChange:Dynamic, onComplete:Dynamic, onError:Dynamic, onFocusIn:Dynamic,
		onFocusOut:Dynamic, onMessage:Dynamic):Void;
	static function history_back(w:WebViewHandle):Int;
	static function history_forward(w:WebViewHandle):Int;
	static function reload(w:WebViewHandle):Int;
	static function stop(w:WebViewHandle):Int;
	static function run(w:WebViewHandle):Int;
	static function terminate(w:WebViewHandle):Int;
	static function set_title(w:WebViewHandle, title:String):Int;
	static function post_message(w:WebViewHandle, message:String):Int;
	static function assign_focus(w:WebViewHandle, direction:Int):Int;
	static function can_go_back(w:WebViewHandle):Int;
	static function can_go_forward(w:WebViewHandle):Int;
	static function capture_preview_base64(w:WebViewHandle, format:Int):Bytes;
	static function get_location(w:WebViewHandle):Bytes;
	static function get_title(w:WebViewHandle):Bytes;
	static function get_native_handle(w:WebViewHandle, kind:Int):WebViewHandle;
	static function webview2_controller_set_bounds(controller:WebViewHandle, width:Int, height:Int):Void;

	public static inline function setSize(w:WebViewHandle, width:Int, height:Int, hints:Int):Int
		return set_size(w, width, height, hints);

	public static inline function setHtml(w:WebViewHandle, html:String):Int
		return set_html(w, html);

	public static inline function addInitScript(w:WebViewHandle, script:String):Int
		return add_init_script(w, script);

	public static inline function evaluateJavaScript(w:WebViewHandle, script:String):Int
		return evaluate_javascript(w, script);

	public static inline function setCallbacks(w:WebViewHandle, onLocationChanging:Dynamic, onLocationChange:Dynamic, onComplete:Dynamic, onError:Dynamic, onFocusIn:Dynamic, onFocusOut:Dynamic, onMessage:Dynamic):Void
	{
		set_callbacks(w, onLocationChanging, onLocationChange, onComplete, onError, onFocusIn, onFocusOut, onMessage);
	}

	public static inline function historyBack(w:WebViewHandle):Int
		return history_back(w);

	public static inline function historyForward(w:WebViewHandle):Int
		return history_forward(w);

	public static inline function postMessage(w:WebViewHandle, message:String):Int
		return post_message(w, message);

	public static inline function assignFocus(w:WebViewHandle, direction:Int):Int
		return assign_focus(w, direction);

	public static inline function setTitle(w:WebViewHandle, title:String):Int
		return set_title(w, title);

	public static inline function canGoBack(w:WebViewHandle):Int
		return can_go_back(w);

	public static inline function canGoForward(w:WebViewHandle):Int
		return can_go_forward(w);

	public static inline function capturePreviewBase64(w:WebViewHandle, format:Int):String
		return __bytesToString(capture_preview_base64(w, format));

	public static inline function getLocation(w:WebViewHandle):String
		return __bytesToString(get_location(w));

	public static inline function getTitle(w:WebViewHandle):String
		return __bytesToString(get_title(w));

	public static inline function getNativeHandle(w:WebViewHandle, kind:Int):WebViewHandle
		return get_native_handle(w, kind);

	public static inline function webView2ControllerSetBounds(controller:WebViewHandle, width:Int, height:Int):Void
	{
		webview2_controller_set_bounds(controller, width, height);
	}

	private static inline function __bytesToString(value:Bytes):String
	{
		return value != null ? @:privateAccess String.fromUTF8(value) : null;
	}
}
#else
class WebViewExterns
{
	public static inline function create(debug:Int, window:Dynamic, userAgent:String, mediaPlaybackRequiresUserAction:Int, enableContextMenu:Int,
			enableKeyboardShortcuts:Int, enableDevTools:Int, enableStatusBar:Int, enableZoom:Int):Dynamic
		return null;

	public static inline function destroy(w:Dynamic):Void {}

	public static inline function setSize(w:Dynamic, width:Int, height:Int, hints:Int):Int
		return -1;

	public static inline function navigate(w:Dynamic, url:String):Int
		return -1;

	public static inline function setHtml(w:Dynamic, html:String):Int
		return -1;

	public static inline function addInitScript(w:Dynamic, script:String):Int
		return -1;

	public static inline function evaluateJavaScript(w:Dynamic, script:String):Int
		return -1;

	public static inline function setCallbacks(w:Dynamic, onLocationChanging:Dynamic, onLocationChange:Dynamic, onComplete:Dynamic, onError:Dynamic,
			onFocusIn:Dynamic, onFocusOut:Dynamic, onMessage:Dynamic):Void {}

	public static inline function historyBack(w:Dynamic):Int
		return -1;

	public static inline function historyForward(w:Dynamic):Int
		return -1;

	public static inline function reload(w:Dynamic):Int
		return -1;

	public static inline function stop(w:Dynamic):Int
		return -1;

	public static inline function run(w:Dynamic):Int
		return -1;

	public static inline function terminate(w:Dynamic):Int
		return -1;

	public static inline function setTitle(w:Dynamic, title:String):Int
		return -1;

	public static inline function postMessage(w:Dynamic, message:String):Int
		return -1;

	public static inline function assignFocus(w:Dynamic, direction:Int):Int
		return -1;

	public static inline function canGoBack(w:Dynamic):Int
		return 0;

	public static inline function canGoForward(w:Dynamic):Int
		return 0;

	public static inline function capturePreviewBase64(w:Dynamic, format:Int):String
		return null;

	public static inline function getLocation(w:Dynamic):String
		return null;

	public static inline function getTitle(w:Dynamic):String
		return null;

	public static inline function getNativeHandle(w:Dynamic, kind:Int):Dynamic
		return null;

	public static inline function webView2ControllerSetBounds(controller:Dynamic, width:Int, height:Int):Void {}
}
#end
