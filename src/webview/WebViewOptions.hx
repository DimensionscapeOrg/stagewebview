package webview;

/**
	What a `webview.WebView` is created with. Everything is optional.

	## Example

	```haxe
	var webView = new webview.WebView(windowHandle, {
		devTools: true,
		userAgent: "StageWebView demo"
	});
	```
**/
typedef WebViewOptions =
{
	/**
		Whether media plays without waiting for a user action. `false` by default.
		Applied on Linux, macOS, iOS and Android.
	**/
	@:optional var autoplay:Bool;

	/**
		Whether the user can open the page's context menu. `true` by default.
	**/
	@:optional var contextMenu:Bool;

	/**
		Whether the engine's developer tools are available. `false` by default.
	**/
	@:optional var devTools:Bool;

	/**
		Whether the webview has no visible window, for off-screen work such as
		`printToPDF()`. `false` by default, and only for a webview without a host
		window.

		Windows parents WebView2 into a window that is never shown, Linux uses a
		GTK offscreen window, macOS an off-screen window, and iOS and Android a
		view that is never attached to the screen.
	**/
	@:optional var hidden:Bool;

	/**
		Whether browser shortcuts, such as the one to print, work. `true` by default.
	**/
	@:optional var keyboardShortcuts:Bool;

	/**
		Whether the status bar shows, as it does over a link. `true` by default.
	**/
	@:optional var statusBar:Bool;

	/**
		What the webview says it is, in place of the engine's own user agent.
	**/
	@:optional var userAgent:String;

	/**
		Whether the user can zoom the page. `true` by default.
	**/
	@:optional var zoom:Bool;
}
