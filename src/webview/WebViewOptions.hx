package webview;

/**
	Optional construction settings for `webview.WebView`.

	Available fields:

	- `debug`: Enables backend debugging features when supported.
	- `mediaPlaybackRequiresUserAction`: Makes media wait for a user action before
	  it plays, on Linux, macOS, iOS and Android.
	- `userAgent`: Overrides the browser user agent on supported backends.
	- `enableContextMenu`: Enables or disables the native context menu.
	- `enableKeyboardShortcuts`: Enables or disables browser keyboard shortcuts.
	- `enableDevTools`: Enables or disables developer tools access.
	- `enableStatusBar`: Enables or disables status bar popups.
	- `enableZoom`: Enables or disables user zoom gestures and shortcuts.
	- `startHidden`: Creates the webview without any visible window, for
	  off-screen work such as `printToPDF()`. Only applies when no host window
	  is passed.

	## Example

	```haxe
	var webView = new webview.WebView(windowHandle, {
		debug: true,
		userAgent: "StageWebView demo",
		enableDevTools: true
	});
	```
**/
@:structInit
class WebViewOptions
{
	public function new() {}

	/**
		Enables backend debugging features when supported.
	**/
	public var debug:Null<Bool> = null;

	/**
		Makes media wait for a user action before it plays. Applied on Linux, macOS,
		iOS and Android. Windows stores the value, but does not apply it yet.
	**/
	public var mediaPlaybackRequiresUserAction:Null<Bool> = null;

	/**
		Overrides the browser user agent on supported backends.
	**/
	public var userAgent:String = null;

	/**
		Enables or disables the native context menu when supported.
	**/
	public var enableContextMenu:Null<Bool> = null;

	/**
		Enables or disables browser keyboard shortcuts when supported.
	**/
	public var enableKeyboardShortcuts:Null<Bool> = null;

	/**
		Enables or disables developer tools access when supported.
	**/
	public var enableDevTools:Null<Bool> = null;

	/**
		Enables or disables status bar popups when supported.
	**/
	public var enableStatusBar:Null<Bool> = null;

	/**
		Enables or disables user zoom operations when supported.
	**/
	public var enableZoom:Null<Bool> = null;

	/**
		Creates the webview without any visible window when no host window is
		passed. Use it for off-screen work such as `printToPDF()`.

		Windows parents WebView2 into a window that is never shown, Linux uses a
		GTK offscreen window, macOS an off-screen window, and iOS and Android a
		view that is never attached to the screen.
	**/
	public var startHidden:Null<Bool> = null;
}
