package stagewebview._internal.win.ext;

import lime.ui.Window;
import webview.WebViewHandle;

@:keep
class WindowUtil
{
	@:noCompletion private static inline final __handleTitle:String = "__0x0323526241231234123123-hwnd__";

	@:noCompletion private static inline function _getWindowHandle(window:Window):WebViewHandle
	{
		var tempTitle = window.title;
		window.title = __handleTitle;
		var handle = WindowBindings.getWindowHandle(__handleTitle);
		window.title = tempTitle;
		return handle;
	}

	@:noCompletion private static inline function _createChildWindow(parentHandle:WebViewHandle, x:Int, y:Int, width:Int, height:Int):WebViewHandle
	{
		if (parentHandle == null)
		{
			throw "Parent Window handle can not be null";
		}

		return WindowBindings.createChildWindow(parentHandle, x, y, width, height);
	}

	@:noCompletion private static inline function _showWindow(handle:WebViewHandle):Void
	{
		if (handle == null)
		{
			throw "Window handle can not be null";
		}

		WindowBindings.showWindow(handle);
	}

	@:noCompletion private static inline function _hideWindow(handle:WebViewHandle):Void
	{
		if (handle == null)
		{
			throw "Window handle can not be null";
		}

		WindowBindings.hideWindow(handle);
	}

	@:noCompletion private static inline function _destroyWindow(handle:WebViewHandle):Void
	{
		if (handle == null)
		{
			return;
		}

		WindowBindings.destroyWindow(handle);
	}

	@:noCompletion private static inline function _moveWindow(handle:WebViewHandle, x:Int, y:Int, width:Int, height:Int):Void
	{
		if (handle == null)
		{
			throw "Window handle can not be null";
		}

		WindowBindings.moveWindow(handle, x, y, width, height);
	}

	@:noCompletion private static inline function _setFocus(handle:WebViewHandle):Void
	{
		if (handle == null)
		{
			throw "Window handle can not be null";
		}

		WindowBindings.setFocus(handle);
	}

	@:noCompletion private static inline function _getHandleKey(handle:WebViewHandle):String
	{
		return handle != null ? WindowBindings.getHandleKey(handle) : null;
	}
}

#if cpp
@:noPrivateAccess
@:buildXml("<section if=\"stagewebview_root\"><include name=\"${stagewebview_root}/build/BuildNative.xml\"/></section><section unless=\"stagewebview_root\"><include name=\"${haxelib:StageWebView}/build/BuildNative.xml\"/></section>")
@:include("lib/WindowBindings.h")
@:native("stagewebview::HxcppWindowBindings")
private extern class WindowBindings
{
	static function getWindowHandle(name:String):WebViewHandle;
	static function createChildWindow(windowHandle:WebViewHandle, x:Int, y:Int, width:Int, height:Int):WebViewHandle;
	static function showWindow(handle:WebViewHandle):Void;
	static function hideWindow(handle:WebViewHandle):Void;
	static function destroyWindow(handle:WebViewHandle):Void;
	static function moveWindow(handle:WebViewHandle, x:Int, y:Int, width:Int, height:Int):Void;
	static function setFocus(handle:WebViewHandle):Void;
	static function getHandleKey(handle:WebViewHandle):String;
}
#elseif hl
@:hlNative("stagewebview", "hl_window_")
private extern class WindowBindings
{
	static function get_window_handle(name:String):WebViewHandle;
	static function create_child_window(windowHandle:WebViewHandle, x:Int, y:Int, width:Int, height:Int):WebViewHandle;
	static function show_window(handle:WebViewHandle):Void;
	static function hide_window(handle:WebViewHandle):Void;
	static function destroy_window(handle:WebViewHandle):Void;
	static function move_window(handle:WebViewHandle, x:Int, y:Int, width:Int, height:Int):Void;
	static function set_focus(handle:WebViewHandle):Void;
	static function get_handle_key(handle:WebViewHandle):String;

	public static inline function getWindowHandle(name:String):WebViewHandle
		return get_window_handle(name);

	public static inline function createChildWindow(windowHandle:WebViewHandle, x:Int, y:Int, width:Int, height:Int):WebViewHandle
		return create_child_window(windowHandle, x, y, width, height);

	public static inline function showWindow(handle:WebViewHandle):Void
	{
		show_window(handle);
	}

	public static inline function hideWindow(handle:WebViewHandle):Void
	{
		hide_window(handle);
	}

	public static inline function destroyWindow(handle:WebViewHandle):Void
	{
		destroy_window(handle);
	}

	public static inline function moveWindow(handle:WebViewHandle, x:Int, y:Int, width:Int, height:Int):Void
	{
		move_window(handle, x, y, width, height);
	}

	public static inline function setFocus(handle:WebViewHandle):Void
	{
		set_focus(handle);
	}

	public static inline function getHandleKey(handle:WebViewHandle):String
	{
		return get_handle_key(handle);
	}
}
#else
private class WindowBindings
{
	public static inline function getWindowHandle(name:String):WebViewHandle
		return null;

	public static inline function createChildWindow(windowHandle:WebViewHandle, x:Int, y:Int, width:Int, height:Int):WebViewHandle
		return null;

	public static inline function showWindow(handle:WebViewHandle):Void {}

	public static inline function hideWindow(handle:WebViewHandle):Void {}

	public static inline function destroyWindow(handle:WebViewHandle):Void {}

	public static inline function moveWindow(handle:WebViewHandle, x:Int, y:Int, width:Int, height:Int):Void {}

	public static inline function setFocus(handle:WebViewHandle):Void {}

	public static inline function getHandleKey(handle:WebViewHandle):String
		return null;
}
#end
