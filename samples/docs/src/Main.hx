package;

import demo.ui.DemoButton;
import demo.util.SamplePaths;
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
	private static inline final DOCS_HOME_RELATIVE_PATH:String = "../../../../../docs/api/index.html";
	private static inline final STAGE_API_RELATIVE_PATH:String = "../../../../../docs/api/openfl/media/StageWebView.html";
	private static inline final WEBVIEW_API_RELATIVE_PATH:String = "../../../../../docs/api/webview/WebView.html";
	private static inline final REPO_URL:String = "https://github.com/dimensionscape/stagewebview";

	private var __background:Shape;
	private var __chrome:Sprite;
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

		__background = new Shape();
		addChild(__background);

		__chrome = new Sprite();
		addChild(__chrome);

		__buildChrome();
		__drawBackdrop();

		__webView = new StageWebView();
		__webView.stage = stage;
		__webView.addEventListener(LocationChangeEvent.LOCATION_CHANGE, __onLocationChange);
		__webView.addEventListener(Event.COMPLETE, __onComplete);
		__webView.addEventListener(ErrorEvent.ERROR, __onError);

		stage.addEventListener(Event.RESIZE, __onResize);
		addEventListener(Event.REMOVED_FROM_STAGE, __onRemovedFromStage);

		__updateViewport();
		__openInitialView();
	}

	private function __addActionButton(label:String, x:Float, width:Int, handler:Void->Void):Void
	{
		var button = new DemoButton(label, width, 40, 0x102038, 0x173159, 0xE58142);
		button.x = x;
		button.y = 138;
		button.onTrigger = handler;
		__chrome.addChild(button);
	}

	private function __buildChrome():Void
	{
		__titleField = __createLabel(46, 34, 32, 0xF8FBFF, true, 560, "Doc Deck");
		__createLabel(46, 82, 15, 0xB8C9E6, false, 760,
			"Browse the generated API site inside a native StageWebView and keep the library docs one click away while you build.");

		__addActionButton("Docs Home", 862, 126, () -> __openDocsPage(DOCS_HOME_RELATIVE_PATH));
		__addActionButton("Stage API", 1000, 122, () -> __openDocsPage(STAGE_API_RELATIVE_PATH));
		__addActionButton("webview.WebView", 1134, 168, () -> __openDocsPage(WEBVIEW_API_RELATIVE_PATH));
		__addActionButton("GitHub", 1314, 104, () -> __navigate(REPO_URL));

		__locationField = __createLabel(50, 0, 14, 0xEDF4FF, false, 1420, "");
		__statusField = __createLabel(50, 0, 13, 0xA7B8D7, false, 1420, "Open the local docs and take a tour.");
	}

	private function __createLabel(x:Float, y:Float, size:Int, color:Int, bold:Bool, width:Float, text:String):TextField
	{
		var label = new TextField();
		label.defaultTextFormat = new TextFormat("_sans", size, color, bold);
		label.selectable = false;
		label.multiline = true;
		label.wordWrap = true;
		label.width = width;
		label.height = 110;
		label.x = x;
		label.y = y;
		label.text = text;
		__chrome.addChild(label);
		return label;
	}

	private function __drawBackdrop():Void
	{
		__background.graphics.clear();
		__background.graphics.beginFill(0x09101D);
		__background.graphics.drawRect(0, 0, stage.stageWidth, stage.stageHeight);
		__background.graphics.endFill();

		__background.graphics.beginFill(0x15345C, 0.45);
		__background.graphics.drawCircle(180, 160, 230);
		__background.graphics.endFill();

		__background.graphics.beginFill(0xE27F41, 0.18);
		__background.graphics.drawCircle(stage.stageWidth - 160, stage.stageHeight - 120, 260);
		__background.graphics.endFill();

		__background.graphics.beginFill(0x10182D, 0.96);
		__background.graphics.drawRoundRect(28, 24, stage.stageWidth - 56, 180, 28, 28);
		__background.graphics.endFill();

		__background.graphics.beginFill(0x0E1528, 0.92);
		__background.graphics.drawRoundRect(28, stage.stageHeight - 84, stage.stageWidth - 56, 54, 24, 24);
		__background.graphics.endFill();
	}

	private function __findDocsUrl(relativePath:String):String
	{
		var path = SamplePaths.resolveIfExists(relativePath);
		return path != null ? SamplePaths.toFileUrl(path) : null;
	}

	private function __navigate(url:String):Void
	{
		if (__webView == null || url == null || url == "")
		{
			return;
		}

		__statusField.text = "Opening " + url + "...";
		__webView.loadURL(url);
	}

	private function __onComplete(_:Event):Void
	{
		__statusField.text = "Doc deck is ready.";
	}

	private function __onError(event:ErrorEvent):Void
	{
		__statusField.text = "That docs hop hit a snag: " + event.text;
	}

	private function __onLocationChange(event:LocationChangeEvent):Void
	{
		__locationField.text = event.location;

		if (StringTools.startsWith(event.location, "file://"))
		{
			__titleField.text = "Doc Deck";
			__statusField.text = "Cruising through the local API site.";
		}
		else
		{
			__titleField.text = "Doc Deck";
			__statusField.text = "Taking a detour outside the local docs.";
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

	private function __openDocsPage(relativePath:String):Void
	{
		var url = __findDocsUrl(relativePath);

		if (url != null)
		{
			__navigate(url);
		}
		else
		{
			__showMissingDocsPage();
		}
	}

	private function __openInitialView():Void
	{
		var docsHome = __findDocsUrl(DOCS_HOME_RELATIVE_PATH);

		if (docsHome != null)
		{
			__navigate(docsHome);
		}
		else
		{
			__showMissingDocsPage();
		}
	}

	private function __showMissingDocsPage():Void
	{
		__statusField.text = "Local docs are missing. Build them, then reopen this sample.";
		__webView.loadString('<!doctype html>'
			+ '<html><head><meta charset="utf-8"><title>Docs Missing</title><style>'
			+ 'html,body{height:100%;margin:0;font-family:Segoe UI,Arial,sans-serif;background:linear-gradient(135deg,#fff9f1,#f4f8ff);color:#1b2233;}'
			+ 'body{display:flex;align-items:center;justify-content:center;padding:24px;box-sizing:border-box;}'
			+ '.card{max-width:760px;padding:34px;border-radius:20px;background:#ffffff;border:1px solid #d9e1ef;box-shadow:0 20px 60px rgba(16,32,51,.12);}'
			+ 'h1{margin:0 0 14px;font-size:34px;}'
			+ 'p{margin:0 0 12px;line-height:1.6;}'
			+ 'code{display:block;margin-top:14px;padding:12px 14px;border-radius:12px;background:#101b2f;color:#f3f8ff;font-family:Consolas,monospace;white-space:pre-wrap;}'
			+ '</style></head><body><div class="card">'
			+ '<h1>Docs are not built yet</h1>'
			+ '<p>This sample expects the generated Dox site under <strong>docs/api</strong>.</p>'
			+ '<p>Build the docs, then launch the sample again and it will open the local site automatically.</p>'
			+ '<code>haxe build/docs-cpp.hxml'
			+ '\n'
			+ 'haxelib run dox -i docs/xml/cpp.xml -o docs/api --title StageWebView -in "^webview$" -in "^webview[.]" -in "^openfl$" -in "^openfl[.]media$" -in "^openfl[.]media[.]StageWebView$" -in "^openfl[.]events$" -in "^openfl[.]events[.](LocationChangeEvent|WebViewDrawEvent)$"</code>'
			+ '</div></body></html>');
	}

	private function __updateViewport():Void
	{
		if (stage == null || __webView == null)
		{
			return;
		}

		__locationField.y = stage.stageHeight - 74;
		__statusField.y = stage.stageHeight - 48;
		__webView.viewPort = new Rectangle(36, 224, stage.stageWidth - 72, stage.stageHeight - 320);
	}
}
