import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import webview.WebView;
import webview.WebViewHint;

private typedef WindowPreset =
{
	var label:String;
	var width:Int;
	var height:Int;
}

class Main
{
	private static inline final DOCS_INDEX_RELATIVE_PATH:String = "../../../../docs/api/index.html";
	private static inline final HAXELIB_SEARCH_URL:String = "https://lib.haxe.org/search/?q=";
	private static inline final HAXE_DOCS_URL:String = "https://haxe.org/documentation/";
	private static inline final OPENFL_URL:String = "https://www.openfl.org";
	private static inline final SOURCE_URL:String = "https://github.com/DimensionscapeOrg/stagewebview";
	private static inline final WINDOW_TITLE:String = "StageWebView Solo Deck";
	private static inline final YOUTUBE_URL:String = "https://www.youtube.com";

	private static final __accentPalette:Array<{color:String, tagline:String}> = [
		{color: "#ff8f5a", tagline: "Fresh glow loaded from Haxe."},
		{color: "#6fe0c2", tagline: "Mint pulse engaged."},
		{color: "#74a7ff", tagline: "Blue arc steady and humming."},
		{color: "#ffd166", tagline: "Golden hour mode unlocked."},
		{color: "#ff6fa8", tagline: "Pink spark says keep building."}
	];

	private static final __windowPresets:Array<WindowPreset> = [
		{label: "Wide", width: 1380, height: 920},
		{label: "Tall", width: 1120, height: 980},
		{label: "Compact", width: 980, height: 760}
	];

	private static var __currentPage:String = "home";
	private static var __messageCount:Int = 0;
	private static var __sizeIndex:Int = 0;
	private static var __webView:WebView;

	private static function main():Void
	{
		if (!WebView.isSupported)
		{
			Sys.println("StageWebView Solo Deck currently needs the Windows native target.");
			return;
		}

		__webView = new WebView(null, {
			debug: true,
			enableDevTools: true,
			enableContextMenu: true,
			enableKeyboardShortcuts: true,
			enableZoom: true,
			userAgent: "StageWebView Solo Deck"
		});

		__webView.onComplete = __onComplete;
		__webView.onError = __onError;
		__webView.onLocationChange = __onLocationChange;
		__webView.onLocationChanging = __onLocationChanging;
		__webView.onMessage = __onMessage;

		__applyWindowPreset(0, false);
		__webView.setTitle(WINDOW_TITLE);
		__loadHome("Window online. The solo deck is warming its thrusters.");
		__webView.run();
		__webView.dispose();
	}

	private static function __applyWindowPreset(index:Int, announce:Bool = true):Void
	{
		__sizeIndex = (index + __windowPresets.length) % __windowPresets.length;

		var preset = __windowPresets[__sizeIndex];
		__webView.setSize(preset.width, preset.height, WebViewHint.NONE);
		__webView.setTitle(WINDOW_TITLE + " - " + preset.label);

		if (announce)
		{
			__sendStatus("Window snapped to " + preset.label + " mode at " + preset.width + "x" + preset.height + ".");
			__sendToPage("size", {
				label: preset.label,
				width: preset.width,
				height: preset.height
			});
			__sendToPage("title", {text: WINDOW_TITLE + " - " + preset.label});
		}
	}

	private static function __currentPageLabel():String
	{
		return switch (__currentPage)
		{
			case "story": "Afterglow";
			case "remote": "Wild tab";
			default: "Solo Deck";
		};
	}

	private static function __homeHtml(?status:String):String
	{
		var docsUrl = StringTools.htmlEscape(__resolveDocsUrl(), true);
		var sourceUrl = StringTools.htmlEscape(SOURCE_URL, true);
		var openflUrl = StringTools.htmlEscape(OPENFL_URL, true);
		var haxeDocsUrl = StringTools.htmlEscape(HAXE_DOCS_URL, true);
		var statusText = StringTools.htmlEscape(status != null ? status : "Fresh deck ready.", true);
		var preset = __windowPresets[__sizeIndex];

		return '<!doctype html>'
			+ '<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Solo Deck</title><style>'
			+ ':root{color-scheme:dark;--accent:#ff8f5a;--accent-soft:rgba(255,143,90,.16);--panel:rgba(11,17,31,.84);--line:rgba(255,255,255,.08);}'
			+ 'html,body{margin:0;min-height:100%;font-family:Segoe UI,Arial,sans-serif;background:radial-gradient(circle at top,#1b2947 0,#0b101b 48%,#060910 100%);color:#f7fbff;}'
			+ 'body{padding:24px;box-sizing:border-box;}'
			+ '.shell{width:min(1160px,100%);margin:0 auto;display:grid;grid-template-columns:1.18fr .82fr;gap:18px;}'
			+ '.panel{background:var(--panel);border:1px solid var(--line);border-radius:28px;padding:26px;box-shadow:0 30px 80px rgba(0,0,0,.26);backdrop-filter:blur(10px);}'
			+ '.hero{position:relative;overflow:hidden;}'
			+ '.hero:before{content:"";position:absolute;inset:-22% auto auto -10%;width:280px;height:280px;background:radial-gradient(circle,var(--accent-soft),transparent 70%);pointer-events:none;}'
			+ '.kicker{display:inline-flex;padding:8px 12px;border-radius:999px;background:rgba(255,255,255,.06);letter-spacing:.12em;text-transform:uppercase;font-size:12px;color:#a8bddf;}'
			+ 'h1{margin:18px 0 8px;font-size:clamp(34px,5vw,58px);line-height:.95;letter-spacing:-.05em;}'
			+ 'p{margin:0;color:#c7d6ef;line-height:1.55;font-size:15px;}'
			+ '.chips{display:flex;flex-wrap:wrap;gap:10px;margin-top:18px;}'
			+ '.chip{display:inline-flex;align-items:center;padding:8px 12px;border-radius:999px;background:rgba(255,255,255,.05);font-size:13px;color:#cfe0ff;}'
			+ 'form{display:grid;grid-template-columns:1fr auto;gap:12px;margin-top:22px;}'
			+ 'input{appearance:none;border:none;border-radius:18px;padding:18px 18px;background:#10192c;color:#f8fbff;font-size:17px;box-shadow:inset 0 0 0 1px rgba(255,255,255,.07);}'
			+ 'input:focus{outline:2px solid rgba(255,143,90,.5);outline-offset:2px;}'
			+ 'button{appearance:none;border:none;border-radius:18px;padding:15px 18px;background:#172742;color:#f8fbff;font-weight:700;cursor:pointer;transition:transform .14s ease,background .14s ease,box-shadow .14s ease;}'
			+ 'button:hover{transform:translateY(-1px);background:#223963;box-shadow:0 16px 26px rgba(0,0,0,.18);}'
			+ '.search{background:linear-gradient(135deg,var(--accent),#ff6a63);color:#091220;min-width:168px;}'
			+ '.search:hover{background:linear-gradient(135deg,#ff9d70,#ff7e74);}'
			+ '.actions{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px;margin-top:18px;}'
			+ '.action-card{padding:16px 18px;text-align:left;background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.06);}'
			+ '.action-card strong,.jump strong{display:block;font-size:16px;margin-bottom:4px;}'
			+ '.action-card span,.jump span{display:block;font-size:13px;color:#a9bcdd;line-height:1.45;}'
			+ '.sidebar{display:grid;gap:18px;}'
			+ '.panel h2{margin:0 0 10px;font-size:19px;letter-spacing:.02em;}'
			+ '.note{font-size:14px;color:#a9bcdd;line-height:1.55;}'
			+ '.jump-grid{display:grid;gap:10px;margin-top:16px;}'
			+ '.jump{text-align:left;background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.06);padding:16px 18px;}'
			+ '.status{margin-top:16px;padding:15px 18px;border-radius:20px;background:rgba(255,143,90,.08);border:1px solid rgba(255,143,90,.18);color:#ffd7bf;font-size:14px;line-height:1.55;}'
			+ '.log{display:grid;gap:10px;max-height:270px;overflow:auto;padding-right:6px;margin-top:16px;}'
			+ '.log-item{padding:12px 14px;border-radius:16px;background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.05);font-size:13px;color:#d5e1f5;line-height:1.45;}'
			+ '.log::-webkit-scrollbar{width:10px;}'
			+ '.log::-webkit-scrollbar-thumb{background:rgba(255,255,255,.15);border-radius:999px;}'
			+ '@media (max-width: 900px){body{padding:16px;}.shell{grid-template-columns:1fr;}form{grid-template-columns:1fr;}.actions{grid-template-columns:1fr;}}'
			+ '</style></head><body data-page="home">'
			+ '<div class="shell">'
			+ '<section class="panel hero">'
			+ '<div class="kicker">Pure Haxe + webview.WebView</div>'
			+ '<h1>One window, plenty of tricks.</h1>'
			+ '<p>This sample is running without OpenFL. The page itself is supplied from Haxe, the bridge is live, the window can resize itself, and the search box routes straight into Haxelib when you want to leave the deck.</p>'
			+ '<div class="chips">'
			+ '<div class="chip" id="titleChip">' + StringTools.htmlEscape(WINDOW_TITLE + " - " + preset.label, true) + '</div>'
			+ '<div class="chip" id="sizeChip">' + preset.label + " • " + preset.width + "x" + preset.height + '</div>'
			+ '<div class="chip">Page • Solo Deck</div>'
			+ '</div>'
			+ '<form id="searchForm">'
			+ '<input id="searchInput" type="text" autocomplete="off" placeholder="Search Haxelib for openfl, hashlink, webview, or anything else">'
			+ '<button class="search" type="submit">Search Haxelib</button>'
			+ '</form>'
			+ '<div class="actions">'
			+ '<button class="action-card" data-action="pulse"><strong>Shuffle Accent</strong><span>Ask Haxe to repaint the deck and send back a fresh status pulse.</span></button>'
			+ '<button class="action-card" data-action="resize"><strong>Cycle Window Size</strong><span>Run through a few top-level window presets without leaving the page.</span></button>'
			+ '<button class="action-card" data-action="story"><strong>Swap the Scene</strong><span>Replace the current HTML with another local page to show off host-driven page swaps.</span></button>'
			+ '<button class="action-card" data-action="block"><strong>Try a Blocked Route</strong><span>Send a YouTube navigation request and watch Haxe politely refuse the rabbit hole.</span></button>'
			+ '</div>'
			+ '</section>'
			+ '<aside class="sidebar">'
			+ '<section class="panel">'
			+ '<h2>Jump points</h2>'
			+ '<div class="note">These buttons navigate the current window for real, so think of them as launch rails out of the deck.</div>'
			+ '<div class="jump-grid">'
			+ '<button class="jump" data-action="open" data-url="' + docsUrl + '"><strong>Local API Docs</strong><span>Open the generated dox site if it exists, otherwise fall back to the repo.</span></button>'
			+ '<button class="jump" data-action="open" data-url="' + sourceUrl + '"><strong>Source Repo</strong><span>Jump to the GitHub project page.</span></button>'
			+ '<button class="jump" data-action="open" data-url="' + openflUrl + '"><strong>OpenFL</strong><span>Take a field trip through the OpenFL side of the ecosystem.</span></button>'
			+ '<button class="jump" data-action="open" data-url="' + haxeDocsUrl + '"><strong>Haxe Docs</strong><span>Open the Haxe documentation site in this same window.</span></button>'
			+ '</div>'
			+ '<div class="status" id="status">' + statusText + '</div>'
			+ '</section>'
			+ '<section class="panel">'
			+ '<h2>Signal log</h2>'
			+ '<div class="note">Messages from Haxe land here so you can see what the host is doing.</div>'
			+ '<div class="log" id="eventLog"></div>'
			+ '</section>'
			+ '</aside>'
			+ '</div>'
			+ __bridgeScript()
			+ '</body></html>';
	}

	private static function __storyHtml():String
	{
		var docsUrl = StringTools.htmlEscape(__resolveDocsUrl(), true);
		return '<!doctype html>'
			+ '<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Afterglow</title><style>'
			+ ':root{color-scheme:dark;--accent:#6fe0c2;--accent-soft:rgba(111,224,194,.14);}'
			+ 'html,body{margin:0;min-height:100%;font-family:Segoe UI,Arial,sans-serif;background:radial-gradient(circle at top,#12263c 0,#0a101c 56%,#060910 100%);color:#f8fbff;}'
			+ 'body{padding:26px;box-sizing:border-box;}'
			+ '.shell{width:min(980px,100%);margin:0 auto;display:grid;gap:18px;}'
			+ '.panel{background:rgba(10,16,29,.84);border:1px solid rgba(255,255,255,.08);border-radius:28px;padding:28px;box-shadow:0 30px 80px rgba(0,0,0,.26);}'
			+ '.badge{display:inline-flex;padding:8px 12px;border-radius:999px;background:rgba(255,255,255,.07);letter-spacing:.12em;text-transform:uppercase;font-size:12px;color:#b0c7e5;}'
			+ 'h1{margin:18px 0 10px;font-size:clamp(34px,5vw,56px);line-height:.96;letter-spacing:-.05em;}'
			+ 'p{margin:0;color:#c7d6ef;line-height:1.58;font-size:15px;}'
			+ '.grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;margin-top:20px;}'
			+ 'button{appearance:none;border:none;border-radius:18px;padding:16px 18px;background:#172742;color:#f8fbff;font-weight:700;cursor:pointer;transition:transform .14s ease,background .14s ease;}'
			+ 'button:hover{transform:translateY(-1px);background:#244166;}'
			+ '.status{margin-top:18px;padding:16px 18px;border-radius:20px;background:rgba(111,224,194,.09);border:1px solid rgba(111,224,194,.18);color:#d8fff3;font-size:14px;line-height:1.55;}'
			+ '.log{display:grid;gap:10px;max-height:260px;overflow:auto;padding-right:6px;margin-top:16px;}'
			+ '.log-item{padding:12px 14px;border-radius:16px;background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.05);font-size:13px;color:#d5e1f5;line-height:1.45;}'
			+ '@media (max-width: 820px){body{padding:16px;}.grid{grid-template-columns:1fr;}}'
			+ '</style></head><body data-page="story">'
			+ '<div class="shell">'
			+ '<section class="panel">'
			+ '<div class="badge">Host swapped this page in</div>'
			+ '<h1>Afterglow mode.</h1>'
			+ '<p>This page is also coming from Haxe. It is a nice way to show that `webview.WebView` can act as a lightweight app shell, not just a blank browser surface.</p>'
			+ '<div class="grid">'
			+ '<button data-action="home">Return Home</button>'
			+ '<button data-action="pulse">Shuffle Accent</button>'
			+ '<button data-action="resize">Cycle Window Size</button>'
			+ '<button data-action="open" data-url="' + docsUrl + '">Open Local Docs</button>'
			+ '<button data-action="block">Try Blocked Route</button>'
			+ '<button data-action="open" data-url="' + StringTools.htmlEscape(SOURCE_URL, true) + '">Open Source</button>'
			+ '</div>'
			+ '<div class="status" id="status">Afterglow is live. The bridge is still listening.</div>'
			+ '<div class="log" id="eventLog"></div>'
			+ '</section>'
			+ '</div>'
			+ __bridgeScript()
			+ '</body></html>';
	}

	private static function __bridgeScript():String
	{
		return '<script>'
			+ 'const statusField=document.getElementById("status");'
			+ 'const logField=document.getElementById("eventLog");'
			+ 'const sizeChip=document.getElementById("sizeChip");'
			+ 'const titleChip=document.getElementById("titleChip");'
			+ 'function post(type,payload){window.chrome.webview.postMessage(JSON.stringify({type:type,payload:payload||{}}));}'
			+ 'function log(text){if(!logField)return;const item=document.createElement("div");item.className="log-item";item.textContent=text;logField.prepend(item);}'
			+ 'const searchForm=document.getElementById("searchForm");'
			+ 'if(searchForm){searchForm.addEventListener("submit",function(event){event.preventDefault();const input=document.getElementById("searchInput");const query=input.value.trim();if(query.length===0){input.focus();return;}post("search",{query:query});});}'
			+ 'Array.prototype.forEach.call(document.querySelectorAll("[data-action]"),function(button){button.addEventListener("click",function(){const payload={};if(button.dataset.url){payload.url=button.dataset.url;}post(button.dataset.action,payload);});});'
			+ 'window.chrome.webview.addEventListener("message",function(event){'
			+ 'const message=JSON.parse(event.data);'
			+ 'if(message.type==="status"&&statusField){statusField.textContent=message.payload.text;}'
			+ 'if(message.type==="accent"){document.documentElement.style.setProperty("--accent",message.payload.color);document.documentElement.style.setProperty("--accent-soft",message.payload.softColor);log(message.payload.tagline);}'
			+ 'if(message.type==="size"&&sizeChip){sizeChip.textContent=message.payload.label+" • "+message.payload.width+"x"+message.payload.height;}'
			+ 'if(message.type==="title"&&titleChip){titleChip.textContent=message.payload.text;}'
			+ 'if(message.type==="log"){log(message.payload.text);}'
			+ 'if(message.type==="blocked"){log("Blocked route: "+message.payload.url+" — "+message.payload.reason);}'
			+ '});'
			+ 'post("ready",{page:document.body.dataset.page});'
			+ '</script>';
	}

	private static function __isLocalPage():Bool
	{
		return __currentPage == "home" || __currentPage == "story";
	}

	private static function __loadHome(?status:String):Void
	{
		__currentPage = "home";
		__webView.setTitle(WINDOW_TITLE + " - " + __windowPresets[__sizeIndex].label);
		__webView.loadString(__homeHtml(status));
	}

	private static function __loadStoryPage():Void
	{
		__currentPage = "story";
		__webView.setTitle(WINDOW_TITLE + " - Afterglow");
		__webView.loadString(__storyHtml());
	}

	private static function __navigateTo(url:String, ?label:String):Void
	{
		__currentPage = "remote";
		__webView.setTitle(label != null && label != "" ? WINDOW_TITLE + " - " + label : WINDOW_TITLE + " - Wild tab");
		__webView.navigate(url);
	}

	private static function __onComplete():Void
	{
		if (__isLocalPage())
		{
			__sendStatus(__currentPage == "story" ? "Afterglow is loaded and listening." : "Solo deck loaded. Pick a move.");
			__syncWindowState();
			return;
		}

		var title = __webView.title;
		var host = __hostFromUrl(__webView.location);
		var label = title != null && title != "" ? title : host;
		__webView.setTitle(WINDOW_TITLE + " - " + __truncate(label, 40));
	}

	private static function __onError(message:String):Void
	{
		if (__isLocalPage())
		{
			__sendStatus("Navigation snag: " + message);
			__sendToPage("log", {text: "Host error: " + message});
		}
		else
		{
			Sys.println("Navigation error: " + message);
		}
	}

	private static function __onLocationChange(location:String):Void
	{
		if (__isLocalPage())
		{
			return;
		}

		var host = __hostFromUrl(location);
		Sys.println("Now visiting " + host + " -> " + location);
	}

	private static function __onLocationChanging(location:String):Bool
	{
		var normalized = location != null ? location.toLowerCase() : "";
		if (normalized.indexOf("youtube.com") != -1)
		{
			if (__isLocalPage())
			{
				__sendStatus("Blocked a rabbit hole before it escaped the lab.");
				__sendToPage("blocked", {
					url: location,
					reason: "The solo deck keeps YouTube behind the velvet rope."
				});
			}
			return true;
		}

		if (__isLocalPage())
		{
			__sendStatus("Charting a route to " + __hostFromUrl(location) + "...");
		}

		return false;
	}

	private static function __onMessage(message:String):Void
	{
		var payload:Dynamic = null;
		try
		{
			payload = Json.parse(message);
		}
		catch (_:Dynamic)
		{
			return;
		}

		if (payload == null || !Reflect.hasField(payload, "type"))
		{
			return;
		}

		__messageCount++;

		var type:String = Reflect.field(payload, "type");
		var messagePayload:Dynamic = Reflect.field(payload, "payload");

		switch (type)
		{
			case "ready":
				__sendToPage("log", {text: "Bridge live for " + __currentPageLabel() + "."});
				__sendStatus("Bridge lit. Host and page are in sync.");
				__pulseAccent();
				__syncWindowState();

			case "pulse":
				__pulseAccent();

			case "resize":
				__applyWindowPreset(__sizeIndex + 1);

			case "story":
				__loadStoryPage();

			case "home":
				__loadHome("Home deck restored. Nice landing.");

			case "block":
				__navigateTo(YOUTUBE_URL, "Blocked route");

			case "search":
				if (messagePayload != null && Reflect.hasField(messagePayload, "query"))
				{
					var query = StringTools.trim(Std.string(Reflect.field(messagePayload, "query")));
					if (query != "")
					{
						__navigateTo(HAXELIB_SEARCH_URL + StringTools.urlEncode(query), "Haxelib search");
					}
				}

			case "open":
				if (messagePayload != null && Reflect.hasField(messagePayload, "url"))
				{
					var url = Std.string(Reflect.field(messagePayload, "url"));
					__navigateTo(url, __hostToLabel(__hostFromUrl(url)));
				}

			default:
		}
	}

	private static function __pulseAccent():Void
	{
		var choice = __accentPalette[Std.random(__accentPalette.length)];
		__sendStatus(choice.tagline);
		__sendToPage("accent", {
			color: choice.color,
			softColor: __toSoftColor(choice.color, 0.17),
			tagline: choice.tagline
		});
		__sendToPage("log", {text: "Accent pulse " + (__messageCount + 1) + ": " + choice.color});
	}

	private static function __resolveDocsUrl():String
	{
		var docsPath = Path.normalize(Path.join([Path.directory(Sys.programPath()), DOCS_INDEX_RELATIVE_PATH]));
		if (FileSystem.exists(docsPath))
		{
			return __toFileUrl(docsPath);
		}

		return SOURCE_URL;
	}

	private static function __sendStatus(text:String):Void
	{
		__sendToPage("status", {text: text});
	}

	private static function __sendToPage(type:String, payload:Dynamic):Void
	{
		if (__webView == null || !__isLocalPage())
		{
			return;
		}

		__webView.postMessage(Json.stringify({
			type: type,
			payload: payload
		}));
	}

	private static function __syncWindowState():Void
	{
		var preset = __windowPresets[__sizeIndex];
		__sendToPage("title", {text: WINDOW_TITLE + " - " + preset.label});
		__sendToPage("size", {
			label: preset.label,
			width: preset.width,
			height: preset.height
		});
	}

	private static function __hostFromUrl(url:String):String
	{
		if (url == null || url == "")
		{
			return "local";
		}

		var normalized = url.toLowerCase();
		if (StringTools.startsWith(normalized, "file://"))
		{
			return normalized.indexOf("/docs/api/") != -1 ? "local docs" : "local file";
		}

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

	private static function __hostToLabel(host:String):String
	{
		if (host == null || host == "")
		{
			return "Wild tab";
		}

		var label = host.split(".")[0];
		return label.charAt(0).toUpperCase() + label.substr(1);
	}

	private static function __toFileUrl(path:String):String
	{
		var normalized = StringTools.replace(path, "\\", "/");
		return StringTools.startsWith(normalized, "/") ? "file://" + normalized : "file:///" + normalized;
	}

	private static function __toSoftColor(hex:String, alpha:Float):String
	{
		var value = StringTools.replace(hex, "#", "");
		var red = Std.parseInt("0x" + value.substr(0, 2));
		var green = Std.parseInt("0x" + value.substr(2, 2));
		var blue = Std.parseInt("0x" + value.substr(4, 2));
		return "rgba(" + red + "," + green + "," + blue + "," + alpha + ")";
	}

	private static function __truncate(value:String, maxLength:Int):String
	{
		if (value == null || value.length <= maxLength)
		{
			return value;
		}

		return value.substr(0, maxLength - 3) + "...";
	}
}
