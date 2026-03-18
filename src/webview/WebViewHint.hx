package webview;

/**
	Hints used when asking the backend to resize a webview.

	These values mirror the native webview sizing hints exposed by the vendored
	backend.

	Pass one of these values to `webview.WebView.setSize` when the backend should
	interpret the requested width and height with additional layout intent.
**/
enum abstract WebViewHint(Int) from Int to Int
{
	/** No special sizing behavior. */
	var NONE = 0;

	/** The requested size should be treated as a minimum. */
	var MIN = 1;

	/** The requested size should be treated as a maximum. */
	var MAX = 2;

	/** The requested size should be treated as fixed. */
	var FIXED = 3;
}
