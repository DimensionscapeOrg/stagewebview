package webview;

/**
	Selects which native object handle should be returned by
	`webview.WebView.getNativeHandle`.

	Use this when you need a lower-level platform object for interop work, such
	as moving the native widget or querying a backend controller.
**/
enum abstract NativeHandleKind(Int) from Int to Int
{
	/** The top-level host window used by the backend. */
	var UI_WINDOW = 0;

	/** The platform widget or child window that owns the rendered web content. */
	var UI_WIDGET = 1;

	/** The browser controller object, when the backend exposes one. */
	var BROWSER_CONTROLLER = 2;
}
