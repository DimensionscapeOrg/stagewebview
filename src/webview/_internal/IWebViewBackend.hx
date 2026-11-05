package webview._internal;

import webview.NativeHandleKind;
import webview.PDFOptions;
import webview.WebViewHandle;
import webview.WebViewHint;

interface IWebViewBackend
{
	var handle(get, never):WebViewHandle;
	var onError:String->Void;
	var onFocusIn:Void->Void;
	var onFocusOut:Void->Void;
	var onLoad:Void->Void;
	var onMessage:String->Void;
	var onNavigate:String->Bool;
	var onURLChange:String->Void;

	function addInitScript(script:String):Void;
	function canGoBack():Bool;
	function canGoForward():Bool;
	function capturePreviewBase64(format:Int):String;
	function close():Void;
	function evaluateJavaScript(script:String, onComplete:Bool->String->Void):Void;
	function focus(direction:Int):Void;
	function getNativeHandle(kind:NativeHandleKind):WebViewHandle;
	function getTitle():String;
	function getURL():String;
	function goBack():Void;
	function goForward():Void;
	function load(url:String):Void;
	function loadHTML(html:String):Void;
	function postMessage(message:String):Void;
	function printToPDF(path:String, options:PDFOptions, onComplete:Bool->String->Void):Void;
	function reload():Void;
	function run():Void;
	function setBounds(width:Int, height:Int):Void;
	function setSize(width:Int, height:Int, hints:WebViewHint = WebViewHint.NONE):Void;
	function setWindowTitle(title:String):Void;
	function stop():Void;
	function terminate():Void;
}
