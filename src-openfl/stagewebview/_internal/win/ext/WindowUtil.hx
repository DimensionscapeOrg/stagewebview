package stagewebview._internal.win.ext;

import lime.ui.Window;
import webview.WebViewHandle;

@:keep
class WindowUtil
{
	@:noCompletion private static inline final __handleTitle:String = "__0x0323526241231234123123-hwnd__";

	@:noCompletion private static function _getWindowHandle(window:Window):WebViewHandle
	{
		#if (stagewebview_native_handle && !android)
		var handle = window.nativeHandle;
		if (handle == null #if linux || handle.type != lime.ui.WindowHandleType.X11 #end)
		{
			return null;
		}

		return WindowBindings.fromAddress(handle.window.high, handle.window.low);
		#else
		// Lime has no way to give the window out before 8.4.0, so it is found by a title nothing else has.
		var tempTitle = window.title;
		window.title = __handleTitle;
		var handle = WindowBindings.getWindowHandle(__handleTitle);
		window.title = tempTitle;
		return handle;
		#end
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

#if android
// Android: the "window" is the activity and children are FrameLayouts over SDL's surface, managed by the
// Java host. Handles are the integer ids it hands out; ACTIVITY stands for the activity itself.
private class WindowBindings
{
	private static inline final ACTIVITY:Int = -1;

	public static inline function getWindowHandle(name:String):WebViewHandle
		return ACTIVITY;

	public static inline function createChildWindow(windowHandle:WebViewHandle, x:Int, y:Int, width:Int, height:Int):WebViewHandle
		return webview._internal.android.AndroidHost.createContainer(x, y, width, height);

	public static inline function showWindow(handle:WebViewHandle):Void
	{
		if (handle != ACTIVITY) webview._internal.android.AndroidHost.setContainerVisible(handle, true);
	}

	public static inline function hideWindow(handle:WebViewHandle):Void
	{
		if (handle != ACTIVITY) webview._internal.android.AndroidHost.setContainerVisible(handle, false);
	}

	public static inline function destroyWindow(handle:WebViewHandle):Void
	{
		if (handle != ACTIVITY) webview._internal.android.AndroidHost.destroyContainer(handle);
	}

	public static inline function moveWindow(handle:WebViewHandle, x:Int, y:Int, width:Int, height:Int):Void
	{
		if (handle != ACTIVITY) webview._internal.android.AndroidHost.moveContainer(handle, x, y, width, height);
	}

	public static inline function setFocus(handle:WebViewHandle):Void
	{
		if (handle == ACTIVITY) webview._internal.android.AndroidHost.focusHost();
	}

	public static inline function getHandleKey(handle:WebViewHandle):String
		return Std.string(handle);
}
#elseif cpp
@:noPrivateAccess
@:buildXml("<section if=\"stagewebview_root\"><include name=\"${stagewebview_root}/build/BuildNative.xml\"/></section><section unless=\"stagewebview_root\"><include name=\"${haxelib:StageWebView}/build/BuildNative.xml\"/></section>")
@:include("lib/WindowBindings.h")
@:native("stagewebview::HxcppWindowBindings")
private extern class WindowBindings
{
	static function getWindowHandle(name:String):WebViewHandle;
	static function fromAddress(high:Int, low:Int):WebViewHandle;
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
	static function from_address(high:Int, low:Int):WebViewHandle;
	static function create_child_window(windowHandle:WebViewHandle, x:Int, y:Int, width:Int, height:Int):WebViewHandle;
	static function show_window(handle:WebViewHandle):Void;
	static function hide_window(handle:WebViewHandle):Void;
	static function destroy_window(handle:WebViewHandle):Void;
	static function move_window(handle:WebViewHandle, x:Int, y:Int, width:Int, height:Int):Void;
	static function set_focus(handle:WebViewHandle):Void;
	static function get_handle_key(handle:WebViewHandle):String;

	public static inline function getWindowHandle(name:String):WebViewHandle
		return get_window_handle(name);

	public static inline function fromAddress(high:Int, low:Int):WebViewHandle
		return from_address(high, low);

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

	public static inline function fromAddress(high:Int, low:Int):WebViewHandle
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
