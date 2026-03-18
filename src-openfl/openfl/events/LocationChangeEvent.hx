package openfl.events;

/**
	OpenFL event dispatched by `openfl.media.StageWebView` during navigation.

	Listen for `LOCATION_CHANGING` to inspect and optionally cancel a navigation,
	and `LOCATION_CHANGE` to react after the active location updates.
**/
class LocationChangeEvent extends Event
{
	/** Dispatched after the current location changes. */
	public static inline var LOCATION_CHANGE:EventType<LocationChangeEvent> = "locationChange";

	/** Dispatched before the current location changes. This event is cancelable. */
	public static inline var LOCATION_CHANGING:EventType<LocationChangeEvent> = "locationChanging";

	/** The destination or current location associated with this event. */
	public var location(get, set):String;

	private var __location:String;

	/**
		Creates a new location-change event.

		@param type Event type, typically `LOCATION_CHANGE` or `LOCATION_CHANGING`.
		@param bubbles Whether the event bubbles through the display list.
		@param cancelable Whether the event can be canceled.
		@param location Location associated with this event.
	**/
	public function new(type:String, bubbles:Bool = false, cancelable:Bool = false, location:String = null)
	{
		super(type, bubbles, cancelable);
		__location = location;
	}

	public override function clone():Event
	{
		var event = new LocationChangeEvent(type, bubbles, cancelable, location);
		event.target = target;
		event.currentTarget = currentTarget;
		event.eventPhase = eventPhase;
		return event;
	}

	public override function toString():String
	{
		return __formatToString("LocationChangeEvent", ["type", "bubbles", "cancelable", "location"]);
	}

	private inline function get_location():String
	{
		return __location;
	}

	private inline function set_location(value:String):String
	{
		__location = value;
		return value;
	}
}
