package openfl.media;

import haxe.Timer;
import haxe.crypto.Base64;
import haxe.io.Bytes;
import lime.ui.MouseButton;
import lime.ui.Window;
import openfl.display.BitmapData;
import openfl.display.FocusDirection;
import openfl.display.JPEGEncoderOptions;
import openfl.display.PNGEncoderOptions;
import openfl.display.Stage;
import openfl.errors.ArgumentError;
import openfl.errors.Error;
import openfl.errors.RangeError;
import openfl.events.DataEvent;
import openfl.events.ErrorEvent;
import openfl.events.Event;
import openfl.events.EventDispatcher;
import openfl.events.FocusEvent;
import openfl.events.LocationChangeEvent;
import openfl.events.WebViewDrawEvent;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.utils.ByteArray;
import stagewebview._internal.win.WinUtil;
import webview.NativeHandleKind;
import webview.WebView;
import webview.WebViewHandle;
import webview.WebViewOptions;

/**
	OpenFL-facing webview component with AIR-style `StageWebView` semantics.

	This class manages OpenFL stage integration, dispatches familiar OpenFL
	events, and delegates browser work to the library-owned `webview.WebView`
	API.

	Accepted constructor configuration fields mirror the AIR reference as closely
	as possible on Windows:

	- `mediaPlaybackRequiresUserAction`
	- `userAgent`
	- `enableContextMenu`
	- `enableKeyboardShortcuts`
	- `enableDevTools`
	- `enableStatusBar`
	- `enableZoom`

	## Example

	```haxe
	import openfl.geom.Rectangle;
	import openfl.media.StageWebView;

	var webView = new StageWebView({
		userAgent: "StageWebView demo",
		mediaPlaybackRequiresUserAction: false
	});
	webView.stage = stage;
	webView.viewPort = new Rectangle(0, 0, stage.stageWidth, stage.stageHeight);
	webView.loadURL("https://www.openfl.org");
	```
**/
final class StageWebView extends EventDispatcher
{
	/** Whether this target can host a native `StageWebView`. */
	public static var isSupported(get, never):Bool;

	/** Whether backward history navigation is currently available. */
	public var isHistoryBackEnabled(get, never):Bool;

	/** Whether forward history navigation is currently available. */
	public var isHistoryForwardEnabled(get, never):Bool;

	/** The current page location. */
	public var location(get, never):String;

	/**
		Whether media playback requires a user action.

		The value is stored for AIR parity. The current Windows backend does not
		yet enforce autoplay policy changes for this setting.
	**/
	public var mediaPlaybackRequiresUserAction(get, set):Bool;

	/** The OpenFL stage this webview is attached to. */
	public var stage(get, set):Stage;

	/** The current page title. */
	public var title(get, never):String;

	/** The stage-space viewport used to position and size the webview. */
	public var viewPort(get, set):Rectangle;

	private var __currentWindowHandle:WebViewHandle;
	private var __childWindowHandle:WebViewHandle;
	private var __location:String;
	private var __pendingHTML:String;
	private var __pendingMimeType:String;
	private var __currentWindowKey:String;
	private var __stage:Stage;
	private var __title:String;
	private var __viewport:Rectangle;
	private var __webView:WebView;
	private var __webViewOptions:WebViewOptions;
	private var __windowMouseDownListener:Float->Float->MouseButton->Void;
	private var __windowMouseDownTarget:Window;

	private static var __focusedWebView:StageWebView;
	private static inline final __CAPTURE_FORMAT_PNG:Int = 0;
	private static inline final __CAPTURE_FORMAT_JPEG:Int = 1;

	/**
		Creates a new `StageWebView`.

		The AIR reference exposes a rest-style `configuration` argument. This Haxe
		implementation supports the same call shapes:

		- `new StageWebView()`
		- `new StageWebView(useNative)`
		- `new StageWebView(useNative, mediaPlaybackRequiresUserAction)`
		- `new StageWebView({ ...configuration })`

		The legacy `useNative` flag is accepted for AIR parity and ignored on the
		current backend.

		@param configuration AIR-style rest arguments. Supported call shapes are
			`new StageWebView()`, `new StageWebView(useNative)`,
			`new StageWebView(useNative, mediaPlaybackRequiresUserAction)`, and
			`new StageWebView({ ...configuration })`.
	**/
	public function new(...configuration:Dynamic)
	{
		super();

		__location = "";
		__pendingMimeType = "text/html";
		__title = "";
		__viewport = new Rectangle();
		__webViewOptions = __createDefaultOptions();

		__applyConstructorConfiguration(configuration);
		__init();
	}

	/**
		Transfers focus into the embedded webview.

		@param direction Preferred focus direction for keyboard-style navigation.
	**/
	public function assignFocus(direction:FocusDirection = FocusDirection.NONE):Void
	{
		if (__webView != null)
		{
			__webView.assignFocus(cast direction);
		}
	}

	/**
		Releases the native webview and its backing child window.

		It is safe to call this more than once.
	**/
	public function dispose():Void
	{
		__detachWindowMouseDownListener();
		__destroyNativeView();
		__stage = null;
	}

	/**
		Draws the current webview viewport to a bitmap or encoded image target.

		Pass a `BitmapData` instance to populate bitmap pixels directly, or pass
		`PNGEncoderOptions` / `JPEGEncoderOptions` to receive encoded image data in
		the dispatched `WebViewDrawEvent`.

		@param target Capture target describing the desired output type.
		@throws ArgumentError Thrown when the target type is unsupported or the
			target bitmap dimensions do not match the current `viewPort`.
		@throws Error Thrown when the webview cannot capture the current viewport.
	**/
	public function drawViewPortAsync(target:Dynamic):Void
	{
		var capture = __resolveCaptureTarget(target);

		Timer.delay(function ():Void
		{
			try
			{
				var bytes = __capturePreviewBytes(capture.format);
				var event = new WebViewDrawEvent(WebViewDrawEvent.WEBVIEW_DRAW_COMPLETE);

				switch (capture.targetType)
				{
					case "BMP":
						var bitmap = __decodeCapturedBitmap(bytes);
						__copyCapturedBitmap(bitmap, capture.bitmapData);
						event.bitmapData = capture.bitmapData;
						bitmap.dispose();

					case "PNG":
						event.pngImage = ByteArray.fromBytes(bytes);

					case "JPEG":
						event.jpegImage = ByteArray.fromBytes(bytes);

					default:
				}

				dispatchEvent(event);
			}
			catch (error:Dynamic)
			{
				dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, false, false, Std.string(error)));
			}
		}, 1);
	}

	/**
		Draws the current webview viewport into an existing `BitmapData`.

		@param bitmap Target bitmap to receive the captured pixels.
		@throws ArgumentError Thrown when the bitmap dimensions do not match the
			current `viewPort`.
		@throws Error Thrown when the bitmap is null or the capture fails.
	**/
	public function drawViewPortToBitmapData(bitmap:BitmapData):Void
	{
		__validateBitmapCapture(bitmap);

		var capturedBitmap = __decodeCapturedBitmap(__capturePreviewBytes(__CAPTURE_FORMAT_PNG));
		__copyCapturedBitmap(capturedBitmap, bitmap);
		capturedBitmap.dispose();
	}

	/** Navigates backward in history when available. */
	public function historyBack():Void
	{
		if (__webView != null)
		{
			__webView.historyBack();
		}
	}

	/** Navigates forward in history when available. */
	public function historyForward():Void
	{
		if (__webView != null)
		{
			__webView.historyForward();
		}
	}

	/**
		Loads an HTML string into the embedded webview.

		Only `text/html` and `application/xhtml+xml` are currently supported.

		@param text HTML or XHTML markup to render.
		@param mimeType MIME type for the provided markup.
		@throws ArgumentError Thrown when `mimeType` is not one of the supported
			HTML values.
	**/
	public function loadString(text:String, mimeType:String = "text/html"):Void
	{
		if (mimeType != "text/html" && mimeType != "application/xhtml+xml")
		{
			throw new ArgumentError("StageWebView.loadString only supports text/html and application/xhtml+xml");
		}

		__pendingHTML = text;
		__pendingMimeType = mimeType;
		__location = "about:blank";
		__title = "";

		if (__webView != null)
		{
			__webView.setHtml(text);
		}
	}

	/**
		Navigates the embedded webview to a remote or local URL.

		@param url Destination URL.
	**/
	public function loadURL(url:String):Void
	{
		__pendingHTML = null;
		__pendingMimeType = "text/html";
		__location = url != null ? url : "";
		__title = "";

		if (__webView != null)
		{
			__webView.navigate(url);
		}
	}

	/**
		Posts a message into the page when the backend supports messaging.

		@param message String payload to send to the active page.
	**/
	public function postMessage(message:String):Void
	{
		if (__webView != null)
		{
			__webView.postMessage(message);
		}
	}

	/** Reloads the current page. */
	public function reload():Void
	{
		if (__webView != null)
		{
			__webView.reload();
		}
	}

	/** Stops the current navigation or load operation. */
	public function stop():Void
	{
		if (__webView != null)
		{
			__webView.stop();
		}
	}

	private function __applyConstructorConfiguration(configuration:Array<Dynamic>):Void
	{
		if (configuration == null || configuration.length == 0)
		{
			return;
		}

		var first = configuration[0];
		if (__isBool(first))
		{
			if (configuration.length > 1)
			{
				var second = configuration[1];
				if (__isBool(second))
				{
					__webViewOptions.mediaPlaybackRequiresUserAction = second;
				}
			}

			return;
		}

		if (first == null)
		{
			return;
		}

		__copyBoolOption(first, "mediaPlaybackRequiresUserAction", function(value) __webViewOptions.mediaPlaybackRequiresUserAction = value);
		__copyBoolOption(first, "enableContextMenu", function(value) __webViewOptions.enableContextMenu = value);
		__copyBoolOption(first, "enableKeyboardShortcuts", function(value) __webViewOptions.enableKeyboardShortcuts = value);
		__copyBoolOption(first, "enableDevTools", function(value)
		{
			__webViewOptions.enableDevTools = value;
			__webViewOptions.debug = value;
		});
		__copyBoolOption(first, "enableStatusBar", function(value) __webViewOptions.enableStatusBar = value);
		__copyBoolOption(first, "enableZoom", function(value) __webViewOptions.enableZoom = value);

		if (Reflect.hasField(first, "userAgent"))
		{
			__webViewOptions.userAgent = Reflect.field(first, "userAgent");
		}
	}

	private function __capturePreviewBytes(format:Int):Bytes
	{
		if (__webView == null)
		{
			throw new Error("The StageWebView must be attached to a stage before capturing the view port.");
		}

		if (__viewport == null || __viewport.width <= 0 || __viewport.height <= 0)
		{
			throw new Error("The StageWebView viewPort must have a positive width and height before capture.");
		}

		var encoded = @:privateAccess __webView.__capturePreviewBase64(format);
		if (encoded == null || encoded == "")
		{
			throw new Error("The StageWebView preview capture failed.");
		}

		return Base64.decode(encoded);
	}

	private function __configureCallbacks():Void
	{
		if (__webView == null)
		{
			return;
		}

		__webView.onLocationChanging = __handleLocationChanging;
		__webView.onLocationChange = __handleLocationChange;
		__webView.onComplete = __handleComplete;
		__webView.onError = __handleError;
		__webView.onFocusIn = __handleFocusIn;
		__webView.onFocusOut = __handleFocusOut;
		__webView.onMessage = __handleMessage;
	}

	private function __copyBoolOption(configuration:Dynamic, field:String, apply:Bool->Void):Void
	{
		if (Reflect.hasField(configuration, field))
		{
			var value = Reflect.field(configuration, field);
			if (__isBool(value))
			{
				apply(value);
			}
		}
	}

	private function __copyCapturedBitmap(source:BitmapData, target:BitmapData):Void
	{
		target.copyPixels(source, source.rect, new Point());
	}

	private function __createDefaultOptions():WebViewOptions
	{
		var options = new WebViewOptions();
		options.mediaPlaybackRequiresUserAction = true;
		options.enableContextMenu = true;
		options.enableKeyboardShortcuts = true;
		options.enableDevTools = true;
		options.enableStatusBar = true;
		options.enableZoom = true;
		options.debug = true;
		return options;
	}

	private function __createWebView():Void
	{
		if (__stage == null || __webView != null)
		{
			return;
		}

		__currentWindowHandle = WinUtil.getWindowHandle(__stage.window);
		__currentWindowKey = WinUtil.getHandleKey(__currentWindowHandle);
		__childWindowHandle = WinUtil.createChildWindow(__currentWindowHandle, 0, 0, 0, 0);
		__webView = new WebView(cast __childWindowHandle, __webViewOptions);
		__configureCallbacks();

		if (__pendingHTML != null)
		{
			__webView.setHtml(__pendingHTML);
		}
		else if (__location != "")
		{
			__webView.navigate(__location);
		}
	}

	private function __destroyNativeView():Void
	{
		if (__focusedWebView == this)
		{
			__focusedWebView = null;
		}

		if (__webView != null)
		{
			__webView.dispose();
			__webView = null;
		}

		if (__childWindowHandle != null)
		{
			WinUtil.destroyWindow(__childWindowHandle);
			__childWindowHandle = null;
		}

		__currentWindowHandle = null;
		__currentWindowKey = null;
	}

	private function __decodeCapturedBitmap(bytes:Bytes):BitmapData
	{
		var bitmap = BitmapData.fromBytes(ByteArray.fromBytes(bytes));
		if (bitmap == null)
		{
			throw new Error("The StageWebView preview could not be decoded.");
		}

		return bitmap;
	}

	private function __handleComplete():Void
	{
		dispatchEvent(new Event(Event.COMPLETE));
	}

	private function __handleError(message:String):Void
	{
		dispatchEvent(new ErrorEvent(ErrorEvent.ERROR, false, false, message));
	}

	private function __handleFocusIn():Void
	{
		__focusedWebView = this;

		if (__stage != null && __stage.focus != null)
		{
			__stage.focus = null;
		}

		dispatchEvent(new FocusEvent(FocusEvent.FOCUS_IN));
	}

	private function __handleFocusOut():Void
	{
		if (__focusedWebView == this)
		{
			__focusedWebView = null;
		}

		dispatchEvent(new FocusEvent(FocusEvent.FOCUS_OUT));
	}

	private function __handleLocationChange(location:String):Void
	{
		__location = (location != null && location != "") ? location : (__pendingHTML != null ? "about:blank" : __location);
		dispatchEvent(new LocationChangeEvent(LocationChangeEvent.LOCATION_CHANGE, false, false, __location));
	}

	private function __handleLocationChanging(location:String):Bool
	{
		var event = new LocationChangeEvent(LocationChangeEvent.LOCATION_CHANGING, false, true, location);
		dispatchEvent(event);
		return event.isDefaultPrevented();
	}

	private function __handleMessage(message:String):Void
	{
		dispatchEvent(new DataEvent("webViewMessage", false, false, message));
	}

	private static inline function __isBool(value:Dynamic):Bool
	{
		return value == true || value == false;
	}

	private function __init():Void
	{
		if (__windowMouseDownListener == null)
		{
			__windowMouseDownListener = function (_:Float, _:Float, _:MouseButton):Void
			{
				__handleParentWindowFocusEvent();
			};
		}
	}

	private function __attachWindowMouseDownListener():Void
	{
		var window = (__stage != null) ? __stage.window : null;
		if (window == __windowMouseDownTarget)
		{
			return;
		}

		__detachWindowMouseDownListener();

		if (window != null && __windowMouseDownListener != null)
		{
			window.onMouseDown.add(__windowMouseDownListener);
			__windowMouseDownTarget = window;
		}
	}

	private function __detachWindowMouseDownListener():Void
	{
		if (__windowMouseDownTarget != null && __windowMouseDownListener != null)
		{
			__windowMouseDownTarget.onMouseDown.remove(__windowMouseDownListener);
			__windowMouseDownTarget = null;
		}
	}

	private function __handleParentWindowFocusEvent():Void
	{
		if (__focusedWebView == this && __currentWindowHandle != null)
		{
			__focusedWebView = null;
			WinUtil.setFocus(__currentWindowHandle);
		}
	}

	private function __updateViewPort():Void
	{
		if (__webView == null || __viewport == null || __childWindowHandle == null)
		{
			return;
		}

		var x = Std.int(__viewport.x);
		var y = Std.int(__viewport.y);
		var width = Std.int(Math.max(0, __viewport.width));
		var height = Std.int(Math.max(0, __viewport.height));

		WinUtil.moveWindowSized(__childWindowHandle, x, y, width, height);

		if (width <= 0 || height <= 0)
		{
			WinUtil.hideWindow(__childWindowHandle);
			return;
		}

		var widgetHandle:WebViewHandle = cast __webView.getNativeHandle(NativeHandleKind.UI_WIDGET);
		if (widgetHandle != null)
		{
			WinUtil.moveWindowSized(widgetHandle, 0, 0, width, height);
		}

		__webView.setBounds(width, height);
		WinUtil.showWindow(__childWindowHandle);
	}

	private function __resolveCaptureTarget(target:Dynamic):{format:Int, targetType:String, bitmapData:BitmapData}
	{
		if (Std.isOfType(target, BitmapData))
		{
			var bitmapData:BitmapData = cast target;
			__validateBitmapCapture(bitmapData);
			return {
				format: __CAPTURE_FORMAT_PNG,
				targetType: "BMP",
				bitmapData: bitmapData
			};
		}

		if (Std.isOfType(target, PNGEncoderOptions))
		{
			return {
				format: __CAPTURE_FORMAT_PNG,
				targetType: "PNG",
				bitmapData: null
			};
		}

		if (Std.isOfType(target, JPEGEncoderOptions))
		{
			return {
				format: __CAPTURE_FORMAT_JPEG,
				targetType: "JPEG",
				bitmapData: null
			};
		}

		throw new ArgumentError("StageWebView.drawViewPortAsync requires BitmapData, PNGEncoderOptions, or JPEGEncoderOptions.");
	}

	private function __validateBitmapCapture(bitmap:BitmapData):Void
	{
		if (bitmap == null)
		{
			throw new Error("The bitmap is null.");
		}

		var expectedWidth = Std.int(__viewport != null ? __viewport.width : 0);
		var expectedHeight = Std.int(__viewport != null ? __viewport.height : 0);
		if (bitmap.width != expectedWidth || bitmap.height != expectedHeight)
		{
			throw new ArgumentError("The bitmap's width or height is different from view port's width or height.");
		}
	}

	private static inline function get_isSupported():Bool
	{
		#if (windows || stagewebview_windows)
		return true;
		#else
		return false;
		#end
	}

	private inline function get_isHistoryBackEnabled():Bool
	{
		return __webView != null ? __webView.canGoBack() : false;
	}

	private inline function get_isHistoryForwardEnabled():Bool
	{
		return __webView != null ? __webView.canGoForward() : false;
	}

	private inline function get_location():String
	{
		if (__webView != null)
		{
			var value = __webView.getLocation();
			if (value != null && value != "")
			{
				__location = value;
			}
		}

		return __location;
	}

	private inline function get_mediaPlaybackRequiresUserAction():Bool
	{
		return __webViewOptions.mediaPlaybackRequiresUserAction != null ? __webViewOptions.mediaPlaybackRequiresUserAction : true;
	}

	private inline function get_stage():Stage
	{
		return __stage;
	}

	private inline function get_title():String
	{
		if (__webView != null)
		{
			var value = __webView.getTitle();
			if (value != null)
			{
				__title = value;
			}
		}

		return __title;
	}

	private inline function get_viewPort():Rectangle
	{
		return __viewport;
	}

	private inline function set_mediaPlaybackRequiresUserAction(value:Bool):Bool
	{
		__webViewOptions.mediaPlaybackRequiresUserAction = value;
		return value;
	}

	private function set_stage(value:Stage):Stage
	{
		if (__stage == value)
		{
			if (__stage != null)
			{
				__attachWindowMouseDownListener();
				__updateViewPort();
			}

			return __stage;
		}

		__detachWindowMouseDownListener();
		__stage = value;

		if (__stage == null)
		{
			if (__focusedWebView == this)
			{
				__focusedWebView = null;
			}

			if (__childWindowHandle != null)
			{
				WinUtil.hideWindow(__childWindowHandle);
			}

			return __stage;
		}

		var nextWindowHandle = WinUtil.getWindowHandle(__stage.window);
		var nextWindowKey = WinUtil.getHandleKey(nextWindowHandle);

		if (__webView != null && __currentWindowKey != null && nextWindowKey != __currentWindowKey)
		{
			if (__pendingHTML == null)
			{
				__location = get_location();
			}

			__destroyNativeView();
		}

		__attachWindowMouseDownListener();
		__createWebView();
		__updateViewPort();
		return __stage;
	}

	private function set_viewPort(value:Rectangle):Rectangle
	{
		if (value == null || value.width < 0 || value.height < 0)
		{
			throw new RangeError("StageWebView.viewPort must be a valid Rectangle");
		}

		__viewport = value;

		if (__stage != null)
		{
			__updateViewPort();
		}

		return __viewport;
	}
}
