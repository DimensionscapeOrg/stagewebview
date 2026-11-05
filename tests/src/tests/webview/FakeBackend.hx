package tests.webview;

import webview._internal.IWebViewBackend;
import webview.NativeHandleKind;
import webview.PDFOptions;
import webview.WebViewHandle;
import webview.WebViewHint;

class FakeBackend implements IWebViewBackend
{
	public var createdWithOptions:webview.WebViewOptions;
	public var createdWithWindow:WebViewHandle;
	public var destroyed:Bool;
	public var historyBackCount:Int;
	public var historyForwardCount:Int;
	public var lastBoundsHeight:Int;
	public var lastBoundsWidth:Int;
	public var lastFocusDirection:Int;
	public var lastHtml:String;
	public var lastMessage:String;
	public var lastNavigate:String;
	public var lastSizeHeight:Int;
	public var lastSizeHints:WebViewHint;
	public var lastSizeWidth:Int;
	public var lastWindowTitle:String;
	public var location:String;
	public var onLoad:Void->Void;
	public var onError:String->Void;
	public var onFocusIn:Void->Void;
	public var onFocusOut:Void->Void;
	public var onURLChange:String->Void;
	public var onNavigate:String->Bool;
	public var onMessage:String->Void;
	public var reloadCount:Int;
	public var runCount:Int;
	public var stopCount:Int;
	public var terminateCount:Int;
	public var title:String;
	public var canGoBackValue:Bool;
	public var canGoForwardValue:Bool;
	public var lastCaptureFormat:Int;
	public var previewBase64:String;
	public var initScripts:Array<String> = [];
	public var evaluatedScripts:Array<String> = [];
	public var lastPdfPath:String;
	public var lastPdfOptions:PDFOptions;
	public var pdfResult:{success:Bool, error:String} = {success: true, error: null};
	public var scriptResult:{success:Bool, result:String} = {success: true, result: "null"};

	private var __handle:WebViewHandle;
	private var __nativeHandles:Map<Int, WebViewHandle>;

	public function new(?handle:WebViewHandle)
	{
		__handle = handle != null ? handle : cast "fake-handle";
		__nativeHandles = new Map();
		historyBackCount = 0;
		historyForwardCount = 0;
		lastBoundsHeight = 0;
		lastBoundsWidth = 0;
		lastFocusDirection = 0;
		lastSizeHeight = 0;
		lastSizeHints = WebViewHint.NONE;
		lastSizeWidth = 0;
		lastWindowTitle = "";
		reloadCount = 0;
		runCount = 0;
		stopCount = 0;
		terminateCount = 0;
		location = "";
		title = "";
	}

	public function addInitScript(script:String):Void
	{
		initScripts.push(script);
	}

	public function evaluateJavaScript(script:String, onComplete:Bool->String->Void):Void
	{
		evaluatedScripts.push(script);

		if (onComplete != null)
		{
			onComplete(scriptResult.success, scriptResult.result);
		}
	}

	public function printToPDF(path:String, options:PDFOptions, onComplete:Bool->String->Void):Void
	{
		lastPdfPath = path;
		lastPdfOptions = options;

		if (onComplete != null)
		{
			onComplete(pdfResult.success, pdfResult.error);
		}
	}

	public function focus(direction:Int):Void
	{
		lastFocusDirection = direction;
	}

	public function canGoBack():Bool
	{
		return canGoBackValue;
	}

	public function canGoForward():Bool
	{
		return canGoForwardValue;
	}

	public function capturePreviewBase64(format:Int):String
	{
		lastCaptureFormat = format;
		return previewBase64;
	}

	public function close():Void
	{
		destroyed = true;
		__handle = null;
	}

	public function emitComplete():Void
	{
		if (onLoad != null)
		{
			onLoad();
		}
	}

	public function emitError(message:String):Void
	{
		if (onError != null)
		{
			onError(message);
		}
	}

	public function emitFocusIn():Void
	{
		if (onFocusIn != null)
		{
			onFocusIn();
		}
	}

	public function emitFocusOut():Void
	{
		if (onFocusOut != null)
		{
			onFocusOut();
		}
	}

	public function emitLocationChange(nextLocation:String):Void
	{
		location = nextLocation;

		if (onURLChange != null)
		{
			onURLChange(nextLocation);
		}
	}

	public function emitLocationChanging(nextLocation:String):Bool
	{
		location = nextLocation;
		return onNavigate != null ? onNavigate(nextLocation) : false;
	}

	public function emitMessage(message:String):Void
	{
		if (onMessage != null)
		{
			onMessage(message);
		}
	}

	public function getURL():String
	{
		return location;
	}

	public function getNativeHandle(kind:NativeHandleKind):WebViewHandle
	{
		return __nativeHandles.get(kind);
	}

	public function getTitle():String
	{
		return title;
	}

	public function goBack():Void
	{
		historyBackCount++;
	}

	public function goForward():Void
	{
		historyForwardCount++;
	}

	public function load(url:String):Void
	{
		lastNavigate = url;
		location = url != null ? url : "";
	}

	public function postMessage(message:String):Void
	{
		lastMessage = message;
	}

	public function registerNativeHandle(kind:NativeHandleKind, handle:WebViewHandle):Void
	{
		__nativeHandles.set(kind, handle);
	}

	public function reload():Void
	{
		reloadCount++;
	}

	public function run():Void
	{
		runCount++;
	}

	public function setBounds(width:Int, height:Int):Void
	{
		lastBoundsWidth = width;
		lastBoundsHeight = height;
	}

	public function loadHTML(html:String):Void
	{
		lastHtml = html;
		location = "about:blank";
	}

	public function setSize(width:Int, height:Int, hints:WebViewHint = WebViewHint.NONE):Void
	{
		lastSizeWidth = width;
		lastSizeHeight = height;
		lastSizeHints = hints;
	}

	public function setWindowTitle(title:String):Void
	{
		lastWindowTitle = title != null ? title : "";
	}

	public function stop():Void
	{
		stopCount++;
	}

	public function terminate():Void
	{
		terminateCount++;
	}

	private inline function get_handle():WebViewHandle
	{
		return __handle;
	}

	public var handle(get, never):WebViewHandle;
}
