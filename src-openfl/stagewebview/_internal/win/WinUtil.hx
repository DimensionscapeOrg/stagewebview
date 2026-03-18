package stagewebview._internal.win;

import lime.ui.Window;
import stagewebview._internal.win.ext.WindowUtil;
import webview.WebViewHandle;

@:access(stagewebview._internal.win.ext.WindowUtil)
class WinUtil
{
	public static function getWindowHandle(window:Window):WebViewHandle
	{
		return WindowUtil._getWindowHandle(window);
	}

	public static function createChildWindow(parentHandle:WebViewHandle, x:Int, y:Int, width:Int, height:Int):WebViewHandle
	{
		return WindowUtil._createChildWindow(parentHandle, x, y, width, height);
	}

	public static function showWindow(handle:WebViewHandle):Void
	{
		WindowUtil._showWindow(handle);
	}

	public static function hideWindow(handle:WebViewHandle):Void
	{
		WindowUtil._hideWindow(handle);
	}

	public static function destroyWindow(handle:WebViewHandle):Void
	{
		WindowUtil._destroyWindow(handle);
	}

	public static function moveWindow(handle:WebViewHandle, x:Int, y:Int):Void
	{
		WindowUtil._moveWindow(handle, x, y, -1, -1);
	}

	public static function moveWindowSized(handle:WebViewHandle, x:Int, y:Int, width:Int, height:Int):Void
	{
		WindowUtil._moveWindow(handle, x, y, width, height);
	}

	public static function setFocus(handle:WebViewHandle):Void
	{
		WindowUtil._setFocus(handle);
	}

	public static function getHandleKey(handle:WebViewHandle):String
	{
		return WindowUtil._getHandleKey(handle);
	}
}
