package;

import demo.ui.DemoButton;
import haxe.Json;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.DataEvent;
import openfl.events.Event;
import openfl.geom.Rectangle;
import openfl.media.StageWebView;
import openfl.text.TextField;
import openfl.text.TextFormat;

class Main extends Sprite
{
	private var __background:Shape;
	private var __logField:TextField;
	private var __messageCount:Int = 0;
	private var __statusField:TextField;
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
		__drawChrome();

		__createLabel(48, 46, 30, 0xF7FAFF, true, 320, "Bridge Party");
		__createLabel(48, 92, 15, 0xB7C8E8, false, 328,
			"Press a button, toss a signal across the bridge, and watch both sides answer in real time.");

		__addCommandButton("Shuffle Accent", 48, 176, 164, __sendAccent);
		__addCommandButton("Spin Headline", 226, 176, 164, __sendHeadline);
		__addCommandButton("Ask for Snapshot", 48, 228, 342, () -> __sendCommand("snapshot", {request:true}));
		__addCommandButton("Send Pep Talk", 48, 280, 342, () -> __sendCommand("announce", {text:"Haxe just sent a tiny pep talk at " + Date.now().toString()}));

		__statusField = __createLabel(48, 346, 14, 0xECF2FD, true, 342, "Waiting for the bridge to light up.");
		__logField = __createLabel(48, 382, 13, 0xAFBEDA, false, 342, "Signal log\n----------\n");
		__logField.height = stage.stageHeight - 424;
		__logField.background = true;
		__logField.backgroundColor = 0x0C1323;
		__logField.border = true;
		__logField.borderColor = 0x1E2A46;

		__webView = new StageWebView();
		__webView.stage = stage;
		__webView.addEventListener(Event.COMPLETE, __onComplete);
		__webView.addEventListener("webViewMessage", __onMessage);
		__webView.loadString(__bridgeHtml());

		stage.addEventListener(Event.RESIZE, __onResize);
		addEventListener(Event.REMOVED_FROM_STAGE, __onRemovedFromStage);

		__updateViewport();
	}

	private function __addCommandButton(label:String, x:Float, y:Float, width:Int, handler:Void->Void):Void
	{
		var button = new DemoButton(label, width, 40, 0x131D31, 0x1B3559, 0xD66D3C);
		button.x = x;
		button.y = y;
		button.onTrigger = handler;
		addChild(button);
	}

	private function __appendLog(value:String):Void
	{
		__logField.appendText(value + "\n");
		__logField.scrollV = __logField.maxScrollV;
	}

	private function __bridgeHtml():String
	{
		return '<!doctype html>'
			+ '<html><head><meta charset="utf-8"><title>Bridge Party</title><style>'
			+ 'html,body{margin:0;height:100%;font-family:Segoe UI,Arial,sans-serif;background:radial-gradient(circle at top,#1f3763,#0c1220 58%);color:#f5f7fb;}'
			+ 'body{padding:24px;box-sizing:border-box;overflow:hidden;}'
			+ '.shell{width:min(920px,100%);height:calc(100vh - 48px);margin:0 auto;display:grid;grid-template-columns:1.2fr .8fr;gap:18px;align-items:stretch;}'
			+ '.panel{background:rgba(9,14,24,.82);border:1px solid rgba(255,255,255,.08);border-radius:22px;box-shadow:0 24px 70px rgba(0,0,0,.28);padding:24px;min-height:0;}'
			+ '.panel-main{overflow:auto;}'
			+ '.panel-feed{display:flex;flex-direction:column;overflow:hidden;}'
			+ 'h1{margin:0 0 10px;font-size:34px;}'
			+ 'p{margin:0 0 14px;line-height:1.5;color:#c9d6ee;}'
			+ '.hero{background:linear-gradient(135deg,var(--accent,#e27d3c),#d34f7b);padding:18px;border-radius:18px;color:white;font-weight:700;letter-spacing:.04em;text-transform:uppercase;}'
			+ '.stack{display:grid;gap:12px;margin-top:18px;}'
			+ 'button,input[type=range]{width:100%;}'
			+ 'button{appearance:none;border:none;border-radius:14px;padding:14px 16px;background:#14233d;color:#f8fbff;font-weight:700;cursor:pointer;}'
			+ 'button:hover{background:#1c3459;}'
			+ '.meter{height:12px;border-radius:99px;background:#18233a;overflow:hidden;}'
			+ '.meter>span{display:block;height:100%;width:42%;background:linear-gradient(90deg,var(--accent,#e27d3c),#5ec8ff);}'
			+ '.feed-title{margin:0 0 14px;font-size:14px;letter-spacing:.12em;text-transform:uppercase;color:#9fb3d6;}'
			+ '.feed{display:grid;gap:10px;font-size:14px;color:#d2dcf3;overflow:auto;min-height:0;padding-right:6px;align-content:start;}'
			+ '.feed-item{padding:10px 12px;border-radius:14px;background:rgba(255,255,255,.05);border:1px solid rgba(255,255,255,.05);line-height:1.45;}'
			+ '.feed::-webkit-scrollbar{width:10px;}'
			+ '.feed::-webkit-scrollbar-thumb{background:rgba(255,255,255,.14);border-radius:999px;}'
			+ '.badge{display:inline-flex;padding:6px 10px;border-radius:999px;background:rgba(255,255,255,.08);font-size:12px;letter-spacing:.08em;text-transform:uppercase;}'
			+ '@media (max-width: 760px){body{padding:16px;overflow:auto;}.shell{height:auto;min-height:calc(100vh - 32px);grid-template-columns:1fr;}.panel-feed{min-height:240px;}}'
			+ '</style></head><body>'
			+ '<div class="shell">'
			+ '<div class="panel panel-main">'
			+ '<div class="badge">JS <-> Haxe Jam Session</div>'
			+ '<h1 id="headline">Two runtimes, one conversation</h1>'
			+ '<p id="copy">JavaScript riffs, Haxe answers, and the page restyles itself like it is in on the joke.</p>'
			+ '<div class="hero" id="hero">Waiting for the first high-five</div>'
			+ '<div class="stack">'
			+ '<button id="hello">Wave at Haxe</button>'
			+ '<button id="snapshot">Ask for a snapshot</button>'
			+ '<label>Accent intensity <input id="accentRange" type="range" min="10" max="100" value="42"></label>'
			+ '<div class="meter"><span id="meter"></span></div>'
			+ '</div>'
			+ '</div>'
			+ '<div class="panel panel-feed"><div class="feed-title">Signal lounge</div><div class="feed" id="feed"></div></div>'
			+ '</div>'
			+ '<script>'
			+ 'const feed=document.getElementById("feed");'
			+ 'const hero=document.getElementById("hero");'
			+ 'const meter=document.getElementById("meter");'
			+ 'const headline=document.getElementById("headline");'
			+ 'const copy=document.getElementById("copy");'
			+ 'function post(type,payload){window.chrome.webview.postMessage(JSON.stringify({type:type,payload:payload}));}'
			+ 'function log(line){const item=document.createElement("div");item.className="feed-item";item.textContent=line;feed.prepend(item);}'
			+ 'document.getElementById("hello").addEventListener("click",()=>post("hello",{stamp:new Date().toISOString()}));'
			+ 'document.getElementById("snapshot").addEventListener("click",()=>post("snapshot",{headline:headline.textContent}));'
			+ 'document.getElementById("accentRange").addEventListener("input",(event)=>{const value=event.target.value;meter.style.width=value+"%";post("range",{value:Number(value)});});'
			+ 'window.chrome.webview.addEventListener("message",(event)=>{'
			+ 'const message=JSON.parse(event.data);'
			+ 'if(message.type==="setAccent"){document.documentElement.style.setProperty("--accent",message.payload.color);hero.textContent="Fresh paint from Haxe";log("Haxe splashed the page with "+message.payload.color);}'
			+ 'if(message.type==="setHeadline"){headline.textContent=message.payload.text;copy.textContent=message.payload.caption;log("Haxe remixed the headline");}'
			+ 'if(message.type==="announce"){log(message.payload.text);}'
			+ 'if(message.type==="snapshot"){hero.textContent="Snapshot request received";post("snapshotReply",{headline:headline.textContent,width:window.innerWidth,height:window.innerHeight});}'
			+ '});'
			+ 'post("ready",{userAgent:navigator.userAgent});'
			+ 'log("Bridge party booted");'
			+ '</script></body></html>';
	}

	private function __createLabel(x:Float, y:Float, size:Int, color:Int, bold:Bool, width:Float, text:String):TextField
	{
		var label = new TextField();
		label.defaultTextFormat = new TextFormat("_sans", size, color, bold);
		label.selectable = false;
		label.multiline = true;
		label.wordWrap = true;
		label.width = width;
		label.height = 120;
		label.x = x;
		label.y = y;
		label.text = text;
		addChild(label);
		return label;
	}

	private function __drawChrome():Void
	{
		__background.graphics.clear();
		__background.graphics.beginFill(0x080E18);
		__background.graphics.drawRect(0, 0, stage.stageWidth, stage.stageHeight);
		__background.graphics.endFill();

		__background.graphics.beginFill(0x0F1830);
		__background.graphics.drawRoundRect(24, 24, 410, stage.stageHeight - 48, 28, 28);
		__background.graphics.endFill();

		__background.graphics.beginFill(0x0E1530, 0.72);
		__background.graphics.drawRoundRect(458, 24, stage.stageWidth - 482, stage.stageHeight - 48, 28, 28);
		__background.graphics.endFill();
	}

	private function __onComplete(_:Event):Void
	{
		__statusField.text = "Bridge lounge loaded.";
	}

	private function __onMessage(event:DataEvent):Void
	{
		__messageCount++;

		var payload:Dynamic = null;
		try
		{
			payload = Json.parse(event.data);
		}
		catch (_:Dynamic) {}

		if (payload != null && Reflect.hasField(payload, "type"))
		{
			var type:String = Reflect.field(payload, "type");
			__appendLog("[" + __messageCount + "] JS -> Haxe: " + type + " " + Json.stringify(Reflect.field(payload, "payload")));

			switch (type)
			{
				case "ready":
					__statusField.text = "Bridge is live. Signals are flowing.";
					__sendAccent();
					__sendHeadline();

				case "hello":
					__sendCommand("announce", {text:"Haxe caught your wave and waved back."});

				case "snapshot":
					__sendCommand("snapshot", {request:true});

				case "snapshotReply":
					__statusField.text = "Snapshot: " + Reflect.field(Reflect.field(payload, "payload"), "width") + "x"
						+ Reflect.field(Reflect.field(payload, "payload"), "height");

				case "range":
					__statusField.text = "Accent dial set to " + Reflect.field(Reflect.field(payload, "payload"), "value") + "%.";

				default:
			}
		}
		else
		{
			__appendLog("[" + __messageCount + "] Raw message: " + event.data);
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
		__drawChrome();
		__logField.height = stage.stageHeight - 424;
		__updateViewport();
	}

	private function __sendAccent():Void
	{
		var palette = [0xE07A3D, 0x5EC8FF, 0x8C79FF, 0x35D39A, 0xF05C86];
		__sendCommand("setAccent", {color:"#"+StringTools.hex(palette[Std.random(palette.length)], 6)});
	}

	private function __sendCommand(type:String, payload:Dynamic):Void
	{
		__webView.postMessage(Json.stringify({type:type, payload:payload}));
	}

	private function __sendHeadline():Void
	{
		var options = [
			{text:"Signal fireworks online", caption:"Messages are hopping between Haxe and JavaScript fast enough to make the page dance."},
			{text:"Haxe at the helm", caption:"The host app can nudge the page, repaint the mood, and answer back instantly."},
			{text:"Bridge energy: immaculate", caption:"This page is reacting to native-side commands with zero awkward silence."}
		];
		__sendCommand("setHeadline", options[Std.random(options.length)]);
	}

	private function __updateViewport():Void
	{
		if (stage == null || __webView == null)
		{
			return;
		}

		__webView.viewPort = new Rectangle(470, 36, stage.stageWidth - 506, stage.stageHeight - 72);
	}
}
