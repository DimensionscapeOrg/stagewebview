package;

import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.geom.Rectangle;
import openfl.media.StageWebView;
import openfl.text.TextField;
import openfl.text.TextFormat;

class Main extends Sprite
{
	private var __chrome:Sprite;
	private var __webView:StageWebView;

	public function new()
	{
		super();
		addEventListener(Event.ADDED_TO_STAGE, __onAddedToStage);
	}

	private function __onAddedToStage(event:Event):Void
	{
		removeEventListener(Event.ADDED_TO_STAGE, __onAddedToStage);
		__drawChrome();

		__webView = new StageWebView();
		__webView.stage = stage;
		__updateViewport();

		stage.addEventListener(Event.RESIZE, __onResize);
		addEventListener(Event.REMOVED_FROM_STAGE, __onRemovedFromStage);

		var html = '<!doctype html>'
			+ '<html>'
			+ '<head>'
			+ '<meta charset="utf-8">'
			+ '<title>Tiny Webview, Big Hello</title>'
			+ '<style>'
			+ ':root{color-scheme:light;}'
			+ 'html,body{height:100%;margin:0;font-family:Segoe UI,Arial,sans-serif;background:linear-gradient(135deg,#fff9f1,#f4f7ff);color:#1b1b1b;}'
			+ 'body{display:flex;align-items:center;justify-content:center;}'
			+ '.card{max-width:640px;padding:32px;border:1px solid #d9d9d9;border-radius:16px;background:#ffffff;box-shadow:0 16px 48px rgba(0,0,0,0.08);}'
			+ 'h1{margin:0 0 12px;font-size:32px;}'
			+ 'p{margin:0 0 10px;line-height:1.5;}'
			+ 'code{padding:2px 6px;border-radius:6px;background:#f0f0f0;}'
			+ '</style>'
			+ '</head>'
			+ '<body>'
			+ '<div class="card">'
			+ '<h1>Tiny portal, big hello</h1>'
			+ '<p>This sample is the smallest possible handshake between OpenFL chrome and a live native <code>StageWebView</code>.</p>'
			+ '<p>If you can read this card, the browser layer is happily nested inside the app and ready for bigger ideas.</p>'
			+ '</div>'
			+ '</body>'
			+ '</html>';

		__webView.loadString(html);
	}

	private function __onResize(event:Event):Void
	{
		__updateViewport();
	}

	private function __onRemovedFromStage(event:Event):Void
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

	private function __updateViewport():Void
	{
		if (stage == null)
		{
			return;
		}

		if (__chrome != null)
		{
			var background:Shape = cast __chrome.getChildAt(0);
			background.graphics.clear();
			background.graphics.beginFill(0x102033);
			background.graphics.drawRect(0, 0, stage.stageWidth, stage.stageHeight);
			background.graphics.endFill();

			__chrome.x = 0;
			__chrome.y = 0;
		}

		if (__webView != null)
		{
			__webView.viewPort = new Rectangle(120, 140, stage.stageWidth - 240, stage.stageHeight - 220);
		}
	}

	private function __drawChrome():Void
	{
		__chrome = new Sprite();

		var background = new Shape();
		__chrome.addChild(background);

		var heading = new TextField();
		heading.defaultTextFormat = new TextFormat("_sans", 28, 0xF6F7FB, true);
		heading.selectable = false;
		heading.text = "OpenFL chrome stays on stage";
		heading.width = 520;
		heading.height = 40;
		heading.x = 48;
		heading.y = 36;
		__chrome.addChild(heading);

		var body = new TextField();
		body.defaultTextFormat = new TextFormat("_sans", 16, 0xC9D3E3);
		body.selectable = false;
		body.multiline = true;
		body.wordWrap = true;
		body.text = "Even if the webview takes a breath before appearing, this shell keeps the app feeling alive instead of fading into the void.";
		body.width = 460;
		body.height = 72;
		body.x = 48;
		body.y = 78;
		__chrome.addChild(body);

		addChild(__chrome);
		__updateViewport();
	}
}
