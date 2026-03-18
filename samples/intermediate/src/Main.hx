package;

import demo.ui.DemoButton;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.ErrorEvent;
import openfl.events.Event;
import openfl.events.LocationChangeEvent;
import openfl.geom.Rectangle;
import openfl.media.StageWebView;
import openfl.text.TextField;
import openfl.text.TextFormat;

class Main extends Sprite
{
	private var __background:Shape;
	private var __chrome:Sprite;
	private var __hostButtons:Array<{host:String, button:DemoButton}>;
	private var __locationField:TextField;
	private var __statusField:TextField;
	private var __titleField:TextField;
	private var __webView:StageWebView;

	public function new()
	{
		super();
		addEventListener(Event.ADDED_TO_STAGE, __onAddedToStage);
	}

	private function __onAddedToStage(_:Event):Void
	{
		removeEventListener(Event.ADDED_TO_STAGE, __onAddedToStage);

		__hostButtons = [];
		__drawChrome();

		__webView = new StageWebView();
		__webView.stage = stage;
		__webView.addEventListener(LocationChangeEvent.LOCATION_CHANGE, __onLocationChange);
		__webView.addEventListener(Event.COMPLETE, __onComplete);
		__webView.addEventListener(ErrorEvent.ERROR, __onError);

		stage.addEventListener(Event.RESIZE, __onResize);
		addEventListener(Event.REMOVED_FROM_STAGE, __onRemovedFromStage);

		__updateViewport();
		__openUrl("https://www.google.com");
	}

	private function __addShortcut(label:String, x:Float, host:String, url:String):Void
	{
		var button = new DemoButton(label, 112, 38, 0x121D32, 0x193055, 0xE78543);
		button.x = x;
		button.y = 56;
		button.onTrigger = () -> __openUrl(url);
		__chrome.addChild(button);
		__hostButtons.push({host: host, button: button});
	}

	private function __createLabel(x:Float, y:Float, size:Int, color:Int, bold:Bool, width:Float, text:String):TextField
	{
		var label = new TextField();
		label.defaultTextFormat = new TextFormat("_sans", size, color, bold);
		label.selectable = false;
		label.multiline = true;
		label.wordWrap = true;
		label.width = width;
		label.height = 96;
		label.x = x;
		label.y = y;
		label.text = text;
		__chrome.addChild(label);
		return label;
	}

	private function __drawChrome():Void
	{
		__background = new Shape();
		addChild(__background);

		__chrome = new Sprite();
		addChild(__chrome);

		__titleField = __createLabel(42, 32, 34, 0xF7FBFF, true, 560, "Live Site Safari");
		__createLabel(44, 80, 15, 0xB8CAE8, false, 640,
			"Pick a destination, crack open a real site, and keep the OpenFL frame looking sharp around it.");

		__addShortcut("Google", 804, "google.com", "https://www.google.com");
		__addShortcut("YouTube", 926, "youtube.com", "https://www.youtube.com");
		__addShortcut("Haxe", 1048, "haxe.org", "https://haxe.org");
		__addShortcut("OpenFL", 1170, "openfl.org", "https://www.openfl.org");

		var card = new Shape();
		card.graphics.beginFill(0x0F1A2E, 0.94);
		card.graphics.lineStyle(1, 0xFFFFFF, 0.08);
		card.graphics.drawRoundRect(42, 148, 360, 94, 22, 22);
		card.graphics.endFill();
		__chrome.addChild(card);

		__createLabel(62, 166, 18, 0xFFFFFF, true, 300, "Pick a portal");
		__createLabel(62, 194, 14, 0xB5C5DE, false, 300,
			"Bounce from search to video to docs and watch the app shell keep everything feeling intentional.");

		__locationField = __createLabel(58, 0, 15, 0xF3F7FC, false, 1320, "");
		__statusField = __createLabel(58, 0, 13, 0xA6B8D7, false, 1320, "Choose a destination and take it for a spin.");

		__drawBackdrop();
	}

	private function __drawBackdrop():Void
	{
		__background.graphics.clear();
		__background.graphics.beginFill(0x09111F);
		__background.graphics.drawRect(0, 0, stage.stageWidth, stage.stageHeight);
		__background.graphics.endFill();

		__background.graphics.beginFill(0x143763, 0.56);
		__background.graphics.drawCircle(180, 160, 220);
		__background.graphics.endFill();

		__background.graphics.beginFill(0xEB7E3F, 0.22);
		__background.graphics.drawCircle(stage.stageWidth - 180, stage.stageHeight - 110, 250);
		__background.graphics.endFill();

		__background.graphics.beginFill(0x16243F, 0.95);
		__background.graphics.drawRoundRect(30, 24, stage.stageWidth - 60, 110, 28, 28);
		__background.graphics.endFill();

		__background.graphics.beginFill(0x111A2C, 0.9);
		__background.graphics.drawRoundRect(30, stage.stageHeight - 84, stage.stageWidth - 60, 54, 24, 24);
		__background.graphics.endFill();
	}

	private function __hostFromUrl(url:String):String
	{
		if (url == null)
		{
			return "";
		}

		var normalized = url.toLowerCase();
		var schemeIndex = normalized.indexOf("://");
		if (schemeIndex != -1)
		{
			normalized = normalized.substr(schemeIndex + 3);
		}

		var slashIndex = normalized.indexOf("/");
		if (slashIndex != -1)
		{
			normalized = normalized.substr(0, slashIndex);
		}

		if (StringTools.startsWith(normalized, "www."))
		{
			normalized = normalized.substr(4);
		}

		return normalized;
	}

	private function __onComplete(_:Event):Void
	{
		__statusField.text = "Fresh page landed successfully.";
	}

	private function __onError(event:ErrorEvent):Void
	{
		__statusField.text = "That hop hit a snag: " + event.text;
	}

	private function __onLocationChange(event:LocationChangeEvent):Void
	{
		var host = __hostFromUrl(event.location);

		__locationField.text = event.location;
		__statusField.text = "Cruising through " + host + ".";
		__titleField.text = host != "" ? host.toUpperCase() + " FIELD TRIP" : "Live Site Safari";

		for (entry in __hostButtons)
		{
			entry.button.setSelected(host.indexOf(entry.host) != -1);
		}
	}

	private function __onRemovedFromStage(_:Event):Void
	{
		if (stage != null)
		{
			stage.removeEventListener(Event.RESIZE, __onResize);
		}

		if (__webView != null)
		{
			__webView.stage = null;
		}
	}

	private function __onResize(_:Event):Void
	{
		__drawBackdrop();
		__updateViewport();
	}

	private function __openUrl(url:String):Void
	{
		__statusField.text = "Teleporting to " + __hostFromUrl(url) + "...";
		__webView.loadURL(url);
	}

	private function __updateViewport():Void
	{
		if (stage == null || __webView == null)
		{
			return;
		}

		__locationField.y = stage.stageHeight - 74;
		__statusField.y = stage.stageHeight - 48;
		__webView.viewPort = new Rectangle(42, 252, stage.stageWidth - 84, stage.stageHeight - 356);
		__drawBackdrop();
	}
}
