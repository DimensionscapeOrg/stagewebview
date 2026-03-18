package;

import demo.ui.DemoButton;
import demo.util.SamplePaths;
import haxe.Json;
import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.DataEvent;
import openfl.events.ErrorEvent;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.events.LocationChangeEvent;
import openfl.geom.Rectangle;
import openfl.media.StageWebView;
import openfl.text.TextField;
import openfl.text.TextFieldType;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import openfl.ui.Keyboard;

private typedef BrowserTab =
{
	var isLaunchpad:Bool;
	var title:String;
	var url:String;
	var host:String;
}

class Main extends Sprite
{
	private static inline final DOCS_INDEX_RELATIVE_PATH:String = "../../../../../docs/api/index.html";
	private static inline final HOME_URL:String = "stagewebview://launchpad";
	private static inline final HAXELIB_SEARCH_URL:String = "https://lib.haxe.org/search/?v=";
	private static inline final NEW_TAB_URL:String = HOME_URL;
	private static inline final MAX_TABS:Int = 5;
	private static inline final SOURCE_URL:String = "https://github.com/DimensionscapeOrg/stagewebview";

	private var __activeTabIndex:Int = -1;
	private var __addressField:TextField;
	private var __addressFieldFrame:Shape;
	private var __background:Shape;
	private var __backButton:DemoButton;
	private var __bookmarkButtons:Array<{host:String, button:DemoButton}>;
	private var __chrome:Sprite;
	private var __closeTabButton:DemoButton;
	private var __forwardButton:DemoButton;
	private var __goButton:DemoButton;
	private var __homeButton:DemoButton;
	private var __newTabButton:DemoButton;
	private var __reloadButton:DemoButton;
	private var __secureField:TextField;
	private var __statusField:TextField;
	private var __subtitleField:TextField;
	private var __tabButtons:Array<DemoButton>;
	private var __tabs:Array<BrowserTab>;
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

		__bookmarkButtons = [];
		__tabButtons = [];
		__tabs = [];

		__background = new Shape();
		addChild(__background);

		__chrome = new Sprite();
		addChild(__chrome);

		__buildChrome();
		__drawChrome();

		__webView = new StageWebView();
		__webView.stage = stage;
		__webView.addEventListener(LocationChangeEvent.LOCATION_CHANGING, __onLocationChanging);
		__webView.addEventListener(LocationChangeEvent.LOCATION_CHANGE, __onLocationChange);
		__webView.addEventListener(Event.COMPLETE, __onComplete);
		__webView.addEventListener(ErrorEvent.ERROR, __onError);
		__webView.addEventListener("webViewMessage", __onMessage);

		stage.addEventListener(Event.RESIZE, __onResize);
		addEventListener(Event.REMOVED_FROM_STAGE, __onRemovedFromStage);

		__seedTabs();
		__updateViewport();
	}

	private function __addBookmark(label:String, y:Float, host:String, url:String):Void
	{
		var button = new DemoButton(label, 92, 40, 0x10192B, 0x1A2E4C, 0xE17E40);
		button.x = 20;
		button.y = y;
		button.onTrigger = () -> __navigate(url);
		__chrome.addChild(button);
		__bookmarkButtons.push({host: host, button: button});
	}

	private function __buildChrome():Void
	{
		__createLabel(22, 24, 12, 0xA3B6D6, true, 96, "StageWebView");
		__createLabel(22, 50, 19, 0xF8FBFF, true, 96, "Browser");
		__createLabel(22, 92, 11, 0x90A6CB, false, 96, "Tabs, docs,\nand live pages.");
		__createLabel(22, 160, 11, 0x6F86AB, true, 96, "Favorites");

		__addBookmark("Home", 190, "launchpad", HOME_URL);
		__addBookmark("Haxelib", 238, "lib.haxe.org", "https://lib.haxe.org");
		__addBookmark("YouTube", 286, "youtube.com", "https://www.youtube.com");
		__addBookmark("OpenFL", 334, "openfl.org", "https://www.openfl.org");
		__addBookmark("Docs", 382, "docs/api", __getDocsIndexUrl());
		__addBookmark("Source", 430, "github.com", SOURCE_URL);

		__newTabButton = new DemoButton("+ Tab", 84, 34, 0x182843, 0x21406A, 0xE17E40);
		__newTabButton.onTrigger = () -> __openNewTab();
		__chrome.addChild(__newTabButton);

		__closeTabButton = new DemoButton("Close", 82, 34, 0x182843, 0x21406A, 0xC95C66);
		__closeTabButton.onTrigger = __closeActiveTab;
		__chrome.addChild(__closeTabButton);

		__backButton = new DemoButton("Back", 82, 38, 0x141E31, 0x203451, 0x2F8A5B);
		__backButton.onTrigger = () -> __webView.historyBack();
		__chrome.addChild(__backButton);

		__forwardButton = new DemoButton("Next", 82, 38, 0x141E31, 0x203451, 0x2F8A5B);
		__forwardButton.onTrigger = () -> __webView.historyForward();
		__chrome.addChild(__forwardButton);

		__reloadButton = new DemoButton("Reload", 92, 38, 0x141E31, 0x203451, 0xD97A3A);
		__reloadButton.onTrigger = () -> __webView.reload();
		__chrome.addChild(__reloadButton);

		__homeButton = new DemoButton("Home", 82, 38, 0x141E31, 0x203451, 0xD97A3A);
		__homeButton.onTrigger = () -> __navigate(HOME_URL);
		__chrome.addChild(__homeButton);

		__addressFieldFrame = new Shape();
		__chrome.addChild(__addressFieldFrame);

		__addressField = new TextField();
		__addressField.defaultTextFormat = new TextFormat("_sans", 17, 0xF5F8FD, false);
		__addressField.type = TextFieldType.INPUT;
		__addressField.background = false;
		__addressField.border = false;
		__addressField.multiline = false;
		__addressField.wordWrap = false;
		__addressField.height = 24;
		__addressField.text = "";
		__addressField.addEventListener(KeyboardEvent.KEY_DOWN, __onAddressKeyDown);
		__chrome.addChild(__addressField);

		__goButton = new DemoButton("Go", 72, 38, 0xE07C3E, 0xF08E49, 0xE07C3E, 0x0B1321);
		__goButton.onTrigger = () -> __navigate(__addressField.text);
		__chrome.addChild(__goButton);

		__titleField = __createLabel(168, 138, 22, 0xF7FBFF, true, 720, "Browser Demo");
		__titleField.multiline = false;
		__titleField.wordWrap = false;
		__titleField.height = 34;
		__subtitleField = __createLabel(168, 168, 12, 0x8EA3C7, false, 760, "Tabs, docs, Haxelib search, and live pages.");
		__subtitleField.multiline = false;
		__subtitleField.wordWrap = false;
		__subtitleField.height = 24;
		__secureField = __createLabel(0, 0, 12, 0x8FD1AB, true, 140, "Local page");
		__secureField.multiline = false;
		__secureField.wordWrap = false;
		__secureField.height = 24;
		var secureFormat = __secureField.defaultTextFormat;
		secureFormat.align = TextFormatAlign.RIGHT;
		__secureField.defaultTextFormat = secureFormat;
		__secureField.setTextFormat(secureFormat);
		__statusField = __createLabel(166, 0, 13, 0xB2C0D9, false, 1200, "Ready.");

		__layoutChrome();
	}

	private function __buildTabLabel(tab:BrowserTab):String
	{
		if (tab.isLaunchpad)
		{
			return "Launchpad";
		}

		var label = tab.title != null && tab.title != "" ? tab.title : __hostToLabel(tab.host);
		return __truncate(label, 18);
	}

	private function __closeActiveTab():Void
	{
		if (__tabs.length <= 1)
		{
			__tabs[0] = __createTabState("Launchpad", HOME_URL);
			__activateTab(0, true);
			return;
		}

		if (__activeTabIndex < 0 || __activeTabIndex >= __tabs.length)
		{
			return;
		}

		__tabs.splice(__activeTabIndex, 1);
		__activeTabIndex = Std.int(Math.max(0, Math.min(__activeTabIndex, __tabs.length - 1)));
		__refreshTabs();
		__activateTab(__activeTabIndex, true);
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

	private function __createTabState(title:String, url:String):BrowserTab
	{
		var resolved = url == HOME_URL ? HOME_URL : __normalizeAddress(url);
		var isLaunchpad = __isLaunchpadUrl(resolved);
		return {
			isLaunchpad: isLaunchpad,
			title: title,
			url: resolved,
			host: isLaunchpad ? "launchpad" : __hostFromUrl(resolved)
		};
	}

	private function __describeTab(tab:BrowserTab):String
	{
		return tab != null && tab.isLaunchpad ? "launchpad" : tab.host;
	}

	private function __displayAddress(tab:BrowserTab):String
	{
		return tab != null && tab.isLaunchpad ? "" : tab.url;
	}

	private function __getActiveTab():BrowserTab
	{
		return (__activeTabIndex >= 0 && __activeTabIndex < __tabs.length) ? __tabs[__activeTabIndex] : null;
	}

	private function __launchpadHtml():String
	{
		var docsUrl = StringTools.htmlEscape(__getDocsIndexUrl(), true);
		var sourceUrl = StringTools.htmlEscape(SOURCE_URL, true);
		var openflUrl = StringTools.htmlEscape("https://www.openfl.org", true);
		var haxeDocsUrl = StringTools.htmlEscape("https://haxe.org/documentation/", true);
		var youtubeUrl = StringTools.htmlEscape("https://www.youtube.com", true);
		var spotlightCards = ''
			+ '<button class="spotlight" data-url="' + docsUrl + '"><strong>API Docs</strong><span>Open the local dox site if it has been built.</span></button>'
			+ '<button class="spotlight" data-url="' + haxeDocsUrl + '"><strong>Haxe Manual</strong><span>Jump straight into language docs and recipes.</span></button>'
			+ '<button class="spotlight" data-url="' + openflUrl + '"><strong>OpenFL</strong><span>Take a quick tour through the rendering side of the stack.</span></button>'
			+ '<button class="spotlight" data-url="' + sourceUrl + '"><strong>Source</strong><span>Open the StageWebView repo and peek under the hood.</span></button>'
			+ '<button class="spotlight" data-url="' + youtubeUrl + '"><strong>Video Break</strong><span>Because every browser deserves at least one side quest button.</span></button>';

		return '<!doctype html>'
			+ '<html><head><meta charset="utf-8"><title>Haxelib Launchpad</title><meta name="viewport" content="width=device-width,initial-scale=1">'
			+ '<style>'
			+ ':root{color-scheme:dark;--glow:#ff9c56;--glow-soft:rgba(255,156,86,.18);--panel:rgba(12,18,31,.86);--line:rgba(255,255,255,.08);}'
			+ 'html,body{margin:0;min-height:100%;font-family:Segoe UI,Arial,sans-serif;background:radial-gradient(circle at top,#18233d 0,#0a0f1b 52%,#060911 100%);color:#f7fbff;}'
			+ 'body{display:flex;justify-content:center;padding:28px;box-sizing:border-box;}'
			+ '.shell{width:min(1080px,100%);display:grid;gap:18px;grid-template-columns:1.2fr .8fr;align-items:start;}'
			+ '.panel{background:var(--panel);border:1px solid var(--line);border-radius:28px;padding:26px;box-shadow:0 28px 80px rgba(0,0,0,.28);backdrop-filter:blur(12px);}'
			+ '.hero{position:relative;overflow:hidden;}'
			+ '.hero:before{content:"";position:absolute;inset:-20% auto auto -10%;width:280px;height:280px;background:radial-gradient(circle,var(--glow-soft),transparent 68%);pointer-events:none;}'
			+ '.kicker{display:inline-flex;padding:8px 12px;border-radius:999px;background:rgba(255,255,255,.07);letter-spacing:.12em;text-transform:uppercase;font-size:12px;color:#a6bddf;}'
			+ 'h1{margin:18px 0 10px;font-size:clamp(34px,5vw,58px);line-height:.96;letter-spacing:-.04em;}'
			+ 'p{margin:0;color:#c5d4ee;line-height:1.55;font-size:15px;}'
			+ 'form{display:grid;grid-template-columns:1fr auto;gap:12px;margin-top:24px;}'
			+ 'input{appearance:none;border:none;border-radius:18px;padding:18px 18px;background:#10192c;color:#f8fbff;font-size:17px;box-shadow:inset 0 0 0 1px rgba(255,255,255,.07);}'
			+ 'input:focus{outline:2px solid rgba(255,156,86,.55);outline-offset:2px;}'
			+ 'button{appearance:none;border:none;border-radius:18px;padding:16px 18px;background:#172742;color:#f8fbff;font-weight:700;cursor:pointer;transition:transform .14s ease,background .14s ease,box-shadow .14s ease;}'
			+ 'button:hover{transform:translateY(-1px);background:#20385f;box-shadow:0 16px 26px rgba(0,0,0,.18);}'
			+ '.search{background:linear-gradient(135deg,#ff9c56,#ff7047);color:#091220;min-width:150px;}'
			+ '.search:hover{background:linear-gradient(135deg,#ffab6e,#ff815c);}'
			+ '.stats{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:12px;margin-top:20px;}'
			+ '.stat{padding:14px 16px;border-radius:18px;background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.06);}'
			+ '.stat strong{display:block;font-size:24px;letter-spacing:-.04em;margin-bottom:4px;}'
			+ '.stat span{color:#9eb3d5;font-size:13px;line-height:1.4;}'
			+ '.sidebar{display:grid;gap:18px;}'
			+ '.panel h2{margin:0 0 10px;font-size:18px;letter-spacing:.02em;}'
			+ '.note{font-size:14px;color:#a9bcdd;}'
			+ '.spotlights{display:grid;gap:10px;margin-top:16px;}'
			+ '.spotlight{display:grid;gap:4px;text-align:left;background:rgba(255,255,255,.04);border:1px solid rgba(255,255,255,.06);padding:16px 18px;}'
			+ '.spotlight strong{font-size:16px;}'
			+ '.spotlight span{font-size:13px;color:#a9bcdd;line-height:1.45;}'
			+ '.hint{margin-top:18px;padding:16px 18px;border-radius:18px;background:rgba(255,156,86,.08);border:1px solid rgba(255,156,86,.18);color:#ffd9bf;font-size:14px;line-height:1.55;}'
			+ '@media (max-width: 860px){body{padding:16px;}.shell{grid-template-columns:1fr;}form{grid-template-columns:1fr;}.stats{grid-template-columns:1fr;}}'
			+ '</style></head><body>'
			+ '<div class="shell">'
			+ '<section class="panel hero">'
			+ '<div class="kicker">StageWebView launchpad</div>'
			+ '<h1>Fresh tab, full spellbook.</h1>'
			+ '<p>Search Haxelib, bounce into the local API docs, or wander off to OpenFL and Haxe resources. This tab is built into the sample so the browser starts with something fun instead of a blank stare.</p>'
			+ '<form id="searchForm">'
			+ '<input id="searchInput" type="text" autocomplete="off" placeholder="Search Haxelib packages or type a topic like webview, openfl, or hashlink">'
			+ '<button class="search" type="submit">Search Haxelib</button>'
			+ '</form>'
			+ '<div class="stats">'
			+ '<div class="stat"><strong>Local</strong><span>The tab itself is rendered from host-supplied HTML.</span></div>'
			+ '<div class="stat"><strong>Bridge</strong><span>Search and shortcut clicks hop through Haxe before navigating.</span></div>'
			+ '<div class="stat"><strong>Fast</strong><span>Great for new tabs, welcome pages, docs hubs, and internal tools.</span></div>'
			+ '</div>'
			+ '<div class="hint">Tip: the address bar also sends plain text searches to Haxelib, so the launchpad and the chrome speak the same language.</div>'
			+ '</section>'
			+ '<aside class="sidebar">'
			+ '<section class="panel">'
			+ '<h2>Jump points</h2>'
			+ '<div class="note">A handful of routes worth keeping one click away.</div>'
			+ '<div class="spotlights">' + spotlightCards + '</div>'
			+ '</section>'
			+ '</aside>'
			+ '</div>'
			+ '<script>'
			+ 'function post(type,payload){window.chrome.webview.postMessage(JSON.stringify({type:type,payload:payload}));}'
			+ 'document.getElementById("searchForm").addEventListener("submit",function(event){event.preventDefault();var input=document.getElementById("searchInput");var query=input.value.trim();if(query.length===0){input.focus();return;}post("search",{query:query});});'
			+ 'Array.prototype.forEach.call(document.querySelectorAll(".spotlight"),function(button){button.addEventListener("click",function(){post("open",{url:button.getAttribute("data-url")});});});'
			+ 'post("ready",{mode:"launchpad"});'
			+ '</script></body></html>';
	}

	private function __loadTab(tab:BrowserTab):Void
	{
		if (__webView == null || tab == null)
		{
			return;
		}

		if (tab.isLaunchpad)
		{
			__webView.loadString(__launchpadHtml());
			return;
		}

		__webView.loadURL(tab.url);
	}

	private function __drawChrome():Void
	{
		__background.graphics.clear();
		__background.graphics.beginFill(0x060A12);
		__background.graphics.drawRect(0, 0, stage.stageWidth, stage.stageHeight);
		__background.graphics.endFill();

		__background.graphics.beginFill(0x0A1020);
		__background.graphics.drawRoundRect(12, 12, 120, stage.stageHeight - 24, 26, 26);
		__background.graphics.endFill();

		__background.graphics.beginFill(0x0D1628);
		__background.graphics.drawRoundRect(144, 12, stage.stageWidth - 156, 188, 26, 26);
		__background.graphics.endFill();

		__background.graphics.beginFill(0x0B1222);
		__background.graphics.drawRoundRect(144, stage.stageHeight - 58, stage.stageWidth - 156, 46, 22, 22);
		__background.graphics.endFill();

		__background.graphics.beginFill(0x0C1526, 0.96);
		__background.graphics.drawRoundRect(144, 212, stage.stageWidth - 156, stage.stageHeight - 282, 26, 26);
		__background.graphics.endFill();
	}

	private function __hostFromUrl(url:String):String
	{
		if (url == null)
		{
			return "";
		}

		if (StringTools.startsWith(url.toLowerCase(), "file://"))
		{
			var fileUrl = StringTools.replace(url.toLowerCase(), "\\", "/");
			return fileUrl.indexOf("/docs/api/") != -1 ? "local docs" : "local file";
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

	private function __hostToLabel(host:String):String
	{
		if (host == null || host == "")
		{
			return "Fresh tab";
		}

		if (host == "launchpad")
		{
			return "Launchpad";
		}

		var label = host.split(".")[0];
		return label.charAt(0).toUpperCase() + label.substr(1);
	}

	private static inline function __isLaunchpadUrl(url:String):Bool
	{
		return url == HOME_URL;
	}

	private function __layoutChrome():Void
	{
		var toolbarY = 78.0;
		var addressX = 548.0;
		var addressRightPadding = 176.0;
		var addressHeight = 38.0;
		var topInfoLeft = 168.0;
		var topInfoRightPadding = 28.0;
		var secureWidth = 120.0;
		var secureGap = 16.0;
		var availableTopWidth = stage.stageWidth - topInfoLeft - topInfoRightPadding - secureWidth - secureGap;
		var addressWidth = Math.max(220, stage.stageWidth - addressX - addressRightPadding);

		__backButton.x = 168;
		__backButton.y = toolbarY;

		__forwardButton.x = 260;
		__forwardButton.y = toolbarY;

		__reloadButton.x = 352;
		__reloadButton.y = toolbarY;

		__homeButton.x = 454;
		__homeButton.y = toolbarY;

		__addressFieldFrame.graphics.clear();
		__addressFieldFrame.graphics.lineStyle(1, 0x2A3956, 1);
		__addressFieldFrame.graphics.beginFill(0x101A2D);
		__addressFieldFrame.graphics.drawRoundRect(addressX, toolbarY, addressWidth, addressHeight, 18, 18);
		__addressFieldFrame.graphics.endFill();

		__addressField.x = addressX + 14;
		__addressField.y = toolbarY + 7;
		__addressField.width = Math.max(192, addressWidth - 28);

		__goButton.x = stage.stageWidth - 156;
		__goButton.y = toolbarY;

		__titleField.width = Math.max(220, availableTopWidth);
		__subtitleField.width = Math.max(220, availableTopWidth);
		__secureField.width = secureWidth;
		__secureField.x = stage.stageWidth - topInfoRightPadding - secureWidth;
		__secureField.y = 140;
		__statusField.width = stage.stageWidth - 220;
		__statusField.y = stage.stageHeight - 48;

		__refreshTabs();
	}

	private function __navigate(value:String):Void
	{
		if (__webView == null)
		{
			return;
		}

		var resolved = __normalizeAddress(value);
		var isLaunchpad = __isLaunchpadUrl(resolved);
		var host = isLaunchpad ? "launchpad" : __hostFromUrl(resolved);

		if (__activeTabIndex >= 0 && __activeTabIndex < __tabs.length)
		{
			__tabs[__activeTabIndex].isLaunchpad = isLaunchpad;
			__tabs[__activeTabIndex].url = resolved;
			__tabs[__activeTabIndex].host = host;
			__tabs[__activeTabIndex].title = isLaunchpad ? "Launchpad" : __hostToLabel(host);
		}

		__addressField.text = isLaunchpad ? "" : resolved;
		__titleField.text = isLaunchpad ? "Launchpad" : __truncate(__hostToLabel(host), 32);
		__subtitleField.text = isLaunchpad
			? "Search Haxelib or open one of the saved pages."
			: "Opening " + host + ".";
		__secureField.text = isLaunchpad ? "Local page" : (StringTools.startsWith(resolved, "https://") ? "HTTPS" : "HTTP");
		__statusField.text = isLaunchpad ? "Loading launchpad." : "Loading " + host + ".";
		__refreshTabs();
		__refreshNavigationState();
		__loadTab(__getActiveTab());
	}

	private function __getDocsIndexUrl():String
	{
		var path = SamplePaths.resolveIfExists(DOCS_INDEX_RELATIVE_PATH);
		return path != null ? SamplePaths.toFileUrl(path) : SOURCE_URL;
	}

	private function __normalizeAddress(value:String):String
	{
		var trimmed = StringTools.trim(value);
		if (trimmed == "")
		{
			return HOME_URL;
		}

		var lowered = trimmed.toLowerCase();
		if (lowered == "home" || lowered == "launchpad" || lowered == "new tab")
		{
			return HOME_URL;
		}

		if (trimmed.indexOf("://") != -1)
		{
			return trimmed;
		}

		if (trimmed.indexOf(" ") != -1 || trimmed.indexOf(".") == -1)
		{
			return HAXELIB_SEARCH_URL + StringTools.urlEncode(trimmed);
		}

		return "https://" + trimmed;
	}

	private function __onAddressKeyDown(event:KeyboardEvent):Void
	{
		if (event.keyCode == Keyboard.ENTER)
		{
			__navigate(__addressField.text);
		}
	}

	private function __onComplete(_:Event):Void
	{
		var activeTab = __getActiveTab();
		if (activeTab != null && activeTab.isLaunchpad)
		{
			activeTab.title = "Launchpad";
			__addressField.text = "";
			__titleField.text = "Launchpad";
			__subtitleField.text = "Search Haxelib or open one of the saved pages.";
			__secureField.text = "Local page";
			__statusField.text = "Launchpad ready.";
			__refreshTabs();
			__refreshNavigationState();
			return;
		}

		var host = __hostFromUrl(__webView.location);
		var title = __webView.title != null && __webView.title != "" ? __webView.title : __hostToLabel(host);

		if (__activeTabIndex >= 0 && __activeTabIndex < __tabs.length)
		{
			__tabs[__activeTabIndex].title = title;
			__tabs[__activeTabIndex].url = __webView.location;
			__tabs[__activeTabIndex].host = host;
		}

		__titleField.text = __truncate(title, 32);
		__subtitleField.text = "Loaded " + host + ".";
		__statusField.text = "Ready.";
		__refreshTabs();
		__refreshNavigationState();
	}

	private function __onError(event:ErrorEvent):Void
	{
		__statusField.text = "Load failed: " + event.text;
		__subtitleField.text = "This page could not be loaded.";
		__refreshNavigationState();
	}

	private function __onLocationChange(event:LocationChangeEvent):Void
	{
		var activeTab = __getActiveTab();
		if (activeTab != null && activeTab.isLaunchpad)
		{
			__addressField.text = "";
			__titleField.text = "Launchpad";
			__subtitleField.text = "Search Haxelib or open one of the saved pages.";
			__secureField.text = "Local page";
			__statusField.text = "Launchpad ready.";
			__refreshTabs();
			__refreshNavigationState();
			return;
		}

		var host = __hostFromUrl(event.location);
		var currentTitle = __webView.title != null && __webView.title != "" ? __webView.title : __hostToLabel(host);

		if (__activeTabIndex >= 0 && __activeTabIndex < __tabs.length)
		{
			__tabs[__activeTabIndex].url = event.location;
			__tabs[__activeTabIndex].host = host;
			__tabs[__activeTabIndex].title = currentTitle;
		}

		__addressField.text = event.location;
		__titleField.text = __truncate(currentTitle, 32);
		__subtitleField.text = "Viewing " + host + ".";
		__secureField.text = StringTools.startsWith(event.location, "https://") ? "HTTPS" : "HTTP";
		__statusField.text = "Page changed.";
		__refreshTabs();
		__refreshNavigationState();
	}

	private function __onLocationChanging(event:LocationChangeEvent):Void
	{
		var activeTab = __getActiveTab();
		if (activeTab != null && activeTab.isLaunchpad && (event.location == null || event.location == "" || event.location == "about:blank"))
		{
			__statusField.text = "Loading launchpad...";
			return;
		}

		__statusField.text = "Loading " + __hostFromUrl(event.location) + "...";
	}

	private function __onMessage(event:DataEvent):Void
	{
		var payload:Dynamic = null;
		try
		{
			payload = Json.parse(event.data);
		}
		catch (_:Dynamic) {}

		if (payload == null || !Reflect.hasField(payload, "type"))
		{
			return;
		}

		var type:String = Reflect.field(payload, "type");
		var messagePayload:Dynamic = Reflect.field(payload, "payload");

		switch (type)
		{
			case "ready":
				__statusField.text = "Bridge ready.";

			case "search":
				if (messagePayload != null && Reflect.hasField(messagePayload, "query"))
				{
					__navigate(Std.string(Reflect.field(messagePayload, "query")));
				}

			case "open":
				if (messagePayload != null && Reflect.hasField(messagePayload, "url"))
				{
					__navigate(Std.string(Reflect.field(messagePayload, "url")));
				}

			default:
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
			__webView.removeEventListener("webViewMessage", __onMessage);
			__webView.stage = null;
		}
	}

	private function __onResize(_:Event):Void
	{
		__drawChrome();
		__layoutChrome();
		__updateViewport();
	}

	private function __openNewTab(?url:String = NEW_TAB_URL):Void
	{
		if (__tabs.length >= MAX_TABS)
		{
			__tabs.shift();
			if (__activeTabIndex > 0)
			{
				__activeTabIndex--;
			}
		}

		__tabs.push(__createTabState("Launchpad", url));
		__refreshTabs();
		__activateTab(__tabs.length - 1, true);
	}

	private function __refreshNavigationState():Void
	{
		if (__webView == null)
		{
			return;
		}

		var activeTab = __getActiveTab();
		var host = activeTab != null && activeTab.isLaunchpad ? "launchpad" : __hostFromUrl(__webView.location);
		__backButton.setEnabled(__webView.isHistoryBackEnabled);
		__forwardButton.setEnabled(__webView.isHistoryForwardEnabled);
		__closeTabButton.setEnabled(__tabs.length > 1);

		for (entry in __bookmarkButtons)
		{
			var location = __webView.location != null ? __webView.location.toLowerCase() : "";
			entry.button.setSelected(host.indexOf(entry.host) != -1 || location.indexOf(entry.host) != -1);
		}
	}

	private function __refreshTabs():Void
	{
		for (button in __tabButtons)
		{
			if (button.parent == __chrome)
			{
				__chrome.removeChild(button);
			}
		}

		__tabButtons = [];

		if (stage == null)
		{
			return;
		}

		var stripX = 160.0;
		var stripY = 22.0;
		var gap = 8.0;
		var actionsWidth = 190.0;
		var availableWidth = Math.max(220.0, stage.stageWidth - stripX - actionsWidth - 34);
		var count = __tabs.length > 0 ? __tabs.length : 1;
		var rawTabWidth = Std.int((availableWidth - gap * (count - 1)) / count);
		var tabWidth = Std.int(Math.max(88, Math.min(176, rawTabWidth)));

		for (i in 0...__tabs.length)
		{
			var tab = __tabs[i];
			var button = new DemoButton(__buildTabLabel(tab), tabWidth, 34, 0x13213A, 0x1E355C, 0xE17E40);
			button.x = stripX + i * (tabWidth + gap);
			button.y = stripY;
			button.setSelected(i == __activeTabIndex);
			button.onTrigger = __activateTab.bind(i, true);
			__chrome.addChild(button);
			__tabButtons.push(button);
		}

		__newTabButton.x = stage.stageWidth - 190;
		__newTabButton.y = 22;
		__closeTabButton.x = stage.stageWidth - 98;
		__closeTabButton.y = 22;
	}

	private function __seedTabs():Void
	{
		__tabs.push(__createTabState("Launchpad", HOME_URL));
		__refreshTabs();
		__activateTab(0, true);
	}

	private function __activateTab(index:Int, navigate:Bool):Void
	{
		if (index < 0 || index >= __tabs.length)
		{
			return;
		}

		__activeTabIndex = index;

		var tab = __tabs[index];
		var host = __describeTab(tab);
		__addressField.text = __displayAddress(tab);
		__titleField.text = tab.isLaunchpad ? "Launchpad" : __truncate(tab.title, 32);
		__subtitleField.text = tab.isLaunchpad
			? "Search Haxelib or open one of the saved pages."
			: "Tab " + (index + 1) + " of " + __tabs.length + ".";
		__secureField.text = tab.isLaunchpad ? "Local page" : (StringTools.startsWith(tab.url, "https://") ? "HTTPS" : "HTTP");
		__statusField.text = tab.isLaunchpad ? "Opening launchpad." : "Opening " + host + ".";
		__refreshTabs();
		__refreshNavigationState();

		if (navigate)
		{
			__loadTab(tab);
		}
	}

	private function __truncate(value:String, maxLength:Int):String
	{
		if (value == null)
		{
			return "";
		}

		return value.length > maxLength ? value.substr(0, maxLength - 3) + "..." : value;
	}

	private function __truncateLegacy(value:String, maxLength:Int):String
	{
		if (value == null)
		{
			return "";
		}

		return value.length > maxLength ? value.substr(0, maxLength - 1) + "…" : value;
	}

	private function __updateViewport():Void
	{
		if (stage == null || __webView == null)
		{
			return;
		}

		__webView.viewPort = new Rectangle(156, 224, stage.stageWidth - 180, stage.stageHeight - 298);
	}
}
