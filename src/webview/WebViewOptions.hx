package webview;

/**
	Optional construction settings for `webview.WebView`.

	Available fields:

	- `debug`: Enables backend debugging features when supported.
	- `mediaPlaybackRequiresUserAction`: Reserved AIR-style parity flag kept for
	  constructor compatibility and future backend behavior.
	- `userAgent`: Overrides the browser user agent on supported backends.
	- `enableContextMenu`: Enables or disables the native context menu.
	- `enableKeyboardShortcuts`: Enables or disables browser keyboard shortcuts.
	- `enableDevTools`: Enables or disables developer tools access.
	- `enableStatusBar`: Enables or disables status bar popups.
	- `enableZoom`: Enables or disables user zoom gestures and shortcuts.

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
		Reserved for AIR-style parity and future backend configuration.

		The current Windows backend stores this value for API parity, but does not
		change runtime behavior based on it yet.
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
}
