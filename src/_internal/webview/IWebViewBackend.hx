package _internal.webview;

import webview.NativeHandleKind;
import webview.WebViewHandle;
import webview.WebViewHint;

interface IWebViewBackend
{
	var handle(get, never):WebViewHandle;
	var onComplete:Void->Void;
	var onError:String->Void;
	var onFocusIn:Void->Void;
	var onFocusOut:Void->Void;
	var onLocationChange:String->Void;
	var onLocationChanging:String->Bool;
	var onMessage:String->Void;

	function assignFocus(direction:Int):Void;
	function canGoBack():Bool;
	function canGoForward():Bool;
	function capturePreviewBase64(format:Int):String;
	function destroy():Void;
	function getLocation():String;
	function getNativeHandle(kind:NativeHandleKind):WebViewHandle;
	function getTitle():String;
	function historyBack():Void;
	function historyForward():Void;
	function navigate(url:String):Void;
	function postMessage(message:String):Void;
	function reload():Void;
	function run():Void;
	function setBounds(width:Int, height:Int):Void;
	function setHtml(html:String):Void;
	function setSize(width:Int, height:Int, hints:WebViewHint = WebViewHint.NONE):Void;
	function setTitle(title:String):Void;
	function stop():Void;
	function terminate():Void;
}
