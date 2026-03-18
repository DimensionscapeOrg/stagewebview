import openfl.events.LocationChangeEvent;
import openfl.events.WebViewDrawEvent;
import openfl.media.StageWebView;
import webview.NativeHandleKind;
import webview.WebView;
import webview.WebViewHandle;
import webview.WebViewHint;
import webview.WebViewOptions;

class DocsMain
{
	static function main():Void
	{
		var __stageWebView:StageWebView = null;
		var __locationChangeEvent:LocationChangeEvent = null;
		var __webViewDrawEvent:WebViewDrawEvent = null;
		var __webView:WebView = null;
		var __handle:WebViewHandle = null;
		var __hint:WebViewHint = WebViewHint.NONE;
		var __kind:NativeHandleKind = NativeHandleKind.UI_WINDOW;
		var __options:WebViewOptions = null;

		// Keep the public API reachable for XML generation without affecting runtime.
		if (false)
		{
			trace(__stageWebView);
			trace(__locationChangeEvent);
			trace(__webViewDrawEvent);
			trace(__webView);
			trace(__handle);
			trace(__hint);
			trace(__kind);
			trace(__options);
		}
	}
}
