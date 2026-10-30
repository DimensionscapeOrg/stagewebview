package _internal.webview.android;

#if android
import lime.system.JNI;

/**
	JNI entry points into `org.dimensionscape.stagewebview.StageWebViewHost`
	(android/src in this library), created on first use.
**/
@:noCompletion
class AndroidHost
{
	private static inline final CLASS_NAME:String = "org/dimensionscape/stagewebview/StageWebViewHost";

	private static var __methods:Map<String, Dynamic> = new Map();

	public static function create(containerId:Int, debug:Bool, userAgent:String, mediaRequiresGesture:Int, bridgeScript:String):Int
		return __method("create", "(IZLjava/lang/String;ILjava/lang/String;)I")(containerId, debug, userAgent, mediaRequiresGesture, bridgeScript);

	public static function destroy(id:Int):Void
		__method("destroy", "(I)V")(id);

	public static function setInterceptNavigation(id:Int, intercept:Bool):Void
		__method("setInterceptNavigation", "(IZ)V")(id, intercept);

	public static function loadUrl(id:Int, url:String):Void
		__method("loadUrl", "(ILjava/lang/String;)V")(id, url);

	public static function loadHtml(id:Int, html:String):Void
		__method("loadHtml", "(ILjava/lang/String;)V")(id, html);

	public static function addInitScript(id:Int, script:String):Void
		__method("addInitScript", "(ILjava/lang/String;)V")(id, script);

	public static function evaluate(id:Int, script:String):Void
		__method("evaluate", "(ILjava/lang/String;)V")(id, script);

	public static function command(id:Int, command:String):Void
		__method("command", "(ILjava/lang/String;)V")(id, command);

	public static function getLocation(id:Int):String
		return __method("getLocation", "(I)Ljava/lang/String;")(id);

	public static function getTitle(id:Int):String
		return __method("getTitle", "(I)Ljava/lang/String;")(id);

	public static function canGoBack(id:Int):Bool
		return __method("canGoBack", "(I)Z")(id);

	public static function canGoForward(id:Int):Bool
		return __method("canGoForward", "(I)Z")(id);

	public static function capture(id:Int, format:Int):String
		return __method("capture", "(II)Ljava/lang/String;")(id, format);

	public static function printToPdf(id:Int, token:Int, path:String, pageWidth:Float, pageHeight:Float, marginTop:Float, marginRight:Float,
			marginBottom:Float, marginLeft:Float, landscape:Bool):Void
		__method("printToPdf", "(IILjava/lang/String;DDDDDDZ)V")(id, token, path, pageWidth, pageHeight, marginTop, marginRight, marginBottom, marginLeft,
			landscape);

	public static function pollEvents():String
		return __method("pollEvents", "()Ljava/lang/String;")();

	public static function resolveNavigation(token:Int, cancel:Bool):Void
		__method("resolveNavigation", "(IZ)V")(token, cancel);

	public static function createContainer(x:Int, y:Int, width:Int, height:Int):Int
		return __method("createContainer", "(IIII)I")(x, y, width, height);

	public static function moveContainer(id:Int, x:Int, y:Int, width:Int, height:Int):Void
		__method("moveContainer", "(IIIII)V")(id, x, y, width, height);

	public static function setContainerVisible(id:Int, visible:Bool):Void
		__method("setContainerVisible", "(IZ)V")(id, visible);

	public static function destroyContainer(id:Int):Void
		__method("destroyContainer", "(I)V")(id);

	public static function focusHost():Void
		__method("focusHost", "()V")();

	private static function __method(name:String, signature:String):Dynamic
	{
		var method = __methods.get(name);
		if (method == null)
		{
			method = JNI.createStaticMethod(CLASS_NAME, name, signature);
			__methods.set(name, method);
		}

		return method;
	}
}
#end
