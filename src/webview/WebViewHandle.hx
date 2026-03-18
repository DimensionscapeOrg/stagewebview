package webview;

#if cpp
import cpp.Pointer;
import cpp.Void as CVoid;

/**
	A native handle used by the library to reference an operating-system window,
	webview instance, or other backend-owned object.

	Most applications do not need to construct these values directly. They are
	primarily used when embedding a `webview.WebView` inside an existing host
	window or when requesting a native handle from the backend.

	Use this type when you need to pass a host window into `webview.WebView` or
	when you need to retrieve a backend-owned native object for advanced platform
	integration.
**/
typedef WebViewHandle = Pointer<CVoid>;
#elseif hl
/**
	A native handle used by the library to reference an operating-system window,
	webview instance, or other backend-owned object.

	On HashLink this is represented as an opaque dynamic handle from the hdll.

	Use this type when you need to pass a host window into `webview.WebView` or
	when you need to retrieve a backend-owned native object for advanced platform
	integration.
**/
abstract WebViewHandle(Dynamic) from Dynamic to Dynamic {}
#else
/**
	A native handle used by the library to reference an operating-system window,
	webview instance, or other backend-owned object.

	On non-native documentation and fallback targets this resolves to a dynamic
	value so the public API remains type-complete.
**/
typedef WebViewHandle = Dynamic;
#end
