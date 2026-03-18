package openfl.events;

import openfl.display.BitmapData;
import openfl.utils.ByteArray;

/**
	Event dispatched when `StageWebView` completes a viewport capture request.

	Depending on the target requested by `drawViewPortAsync()`, the event will
	populate `bitmapData`, `pngImage`, or `jpegImage`.
**/
class WebViewDrawEvent extends Event
{
	/** Reserved event name for a completed viewport draw operation. */
	public static inline var WEBVIEW_DRAW_COMPLETE:EventType<WebViewDrawEvent> = "webViewDrawComplete";

	/** Bitmap capture payload for future bitmap-based draws. */
	public var bitmapData:BitmapData;

	/** JPEG capture payload for future encoded draws. */
	public var jpegImage:ByteArray;

	/** PNG capture payload for future encoded draws. */
	public var pngImage:ByteArray;

	/** Describes which capture payload field is currently populated. */
	public var targetType(get, never):String;

	/**
		Creates a new webview-draw event.

		@param type Event type, typically `WEBVIEW_DRAW_COMPLETE`.
		@param bubbles Whether the event bubbles.
		@param cancelable Whether the event is cancelable.
	**/
	public function new(type:String, bubbles:Bool = false, cancelable:Bool = false)
	{
		super(type, bubbles, cancelable);
	}

	public override function clone():Event
	{
		var event = new WebViewDrawEvent(type, bubbles, cancelable);
		event.bitmapData = bitmapData;
		event.jpegImage = jpegImage;
		event.pngImage = pngImage;
		event.target = target;
		event.currentTarget = currentTarget;
		event.eventPhase = eventPhase;
		return event;
	}

	public override function toString():String
	{
		return __formatToString("WebViewDrawEvent", ["type", "bubbles", "cancelable", "targetType"]);
	}

	private function get_targetType():String
	{
		if (bitmapData != null)
		{
			return "BMP";
		}

		if (pngImage != null)
		{
			return "PNG";
		}

		if (jpegImage != null)
		{
			return "JPEG";
		}

		return "NONE";
	}
}
