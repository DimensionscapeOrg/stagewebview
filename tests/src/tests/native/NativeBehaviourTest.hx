package tests.native;

import haxe.Timer;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import utest.Assert;
import utest.Test;
import webview.PdfOptions;
import webview.WebView;

/**
	Native behaviour beyond the basics in `NativeWebViewTest`: scripts, file
	navigation and history, page geometry, the page left after printing,
	callbacks that dispose their webview, and print failures.
**/
class NativeBehaviourTest extends Test
{
	private static inline final TIMEOUT_SECONDS:Float = 30;

	private var __directory:String;
	private var __messages:Array<String>;
	private var __webView:WebView;

	public function setup():Void
	{
		__directory = Path.join([Sys.getCwd(), "native-test-files"]);
		if (!FileSystem.exists(__directory))
		{
			FileSystem.createDirectory(__directory);
		}

		__messages = [];
		__webView = __create();
	}

	public function teardown():Void
	{
		if (__webView != null)
		{
			__webView.dispose();
			__webView = null;
		}

		for (name in FileSystem.readDirectory(__directory))
		{
			FileSystem.deleteFile(Path.join([__directory, name]));
		}

		FileSystem.deleteDirectory(__directory);
	}

	public function testInitScriptRunsBeforePageScripts():Void
	{
		__webView.addInitScript("window.__fromInitScript = 'set';");
		__webView.loadString("<!doctype html><html><body><script>
			window.chrome.webview.postMessage('init:' + window.__fromInitScript);
		</script></body></html>");

		Assert.isTrue(__waitForMessage("init:"), "no message from the page");
		Assert.equals("init:set", __lastMessage("init:"));
	}

	public function testEvaluateJavaScriptRunsInThePage():Void
	{
		__loadAndWait("<!doctype html><html><body><p id='value'>41</p></body></html>");

		__webView.evaluateJavaScript("window.chrome.webview.postMessage('value:' + (Number(document.getElementById('value').textContent) + 1));");

		Assert.isTrue(__waitForMessage("value:"), "the script did not run");
		Assert.equals("value:42", __lastMessage("value:"));
	}

	public function testNavigationReportsLocationAndHistory():Void
	{
		var first = __writeFile("first page.html", "<!doctype html><html><head><title>First</title></head><body>1</body></html>");
		var second = __writeFile("second.html", "<!doctype html><html><head><title>Second</title></head><body>2</body></html>");
		var changes:Array<String> = [];
		__webView.onLocationChange = function(location:String):Void changes.push(location);

		__navigateAndWait(__fileUrl(first));
		Assert.isTrue(__waitForTitle("First"), "title is " + __webView.title);
		Assert.isTrue(__webView.location.indexOf("first%20page.html") >= 0, "location is " + __webView.location);

		__navigateAndWait(__fileUrl(second));
		Assert.isTrue(__waitForTitle("Second"), "title is " + __webView.title);
		Assert.isTrue(StringTools.endsWith(__webView.location, "second.html"), "location is " + __webView.location);
		Assert.isTrue(changes.length >= 2, "location changes: " + changes);
		Assert.isTrue(__pumpUntil(function():Bool return __webView.canGoBack()), "canGoBack stayed false");

		var completed = false;
		__webView.onComplete = function():Void completed = true;
		__webView.historyBack();
		Assert.isTrue(__pumpUntil(function():Bool return completed && __webView.title == "First"), "historyBack did not return to the first page");
		Assert.isTrue(__pumpUntil(function():Bool return __webView.canGoForward()), "canGoForward stayed false");
	}

	public function testPrintToPDFUsesThePageSize():Void
	{
		__loadAndWait("<!doctype html><html><body><h1>A4 landscape</h1></body></html>");

		var path = Path.join([__directory, "a4-landscape.pdf"]);
		var result = __print(path, {pageWidth: 8.27, pageHeight: 11.69, landscape: true});
		Assert.isTrue(result.success, result.error);

		var box = __mediaBox(path);
		Assert.notNull(box, "no MediaBox in the PDF");
		if (box != null)
		{
			// A4 is 595.3 x 841.9 points; engines round to whole points.
			Assert.floatEquals(841.9, box.width, 2.5, "width " + box.width);
			Assert.floatEquals(595.3, box.height, 2.5, "height " + box.height);
		}
	}

	public function testPrintingLeavesThePageAsItWas():Void
	{
		var rows = new StringBuf();
		for (index in 0...90)
		{
			rows.add("<tr><td>" + index + "</td><td>Row " + index + "</td></tr>");
		}

		__loadAndWait("<!doctype html><html><body><table><thead><tr><th>#</th><th>Name</th></tr></thead><tbody>"
			+ rows.toString() + "</tbody></table></body></html>");

		var snapshot = "window.chrome.webview.postMessage('page:' + document.querySelectorAll('table').length + ','"
			+ " + document.querySelectorAll('tbody tr').length + ',' + document.body.innerHTML.length);";
		__webView.evaluateJavaScript(snapshot);
		Assert.isTrue(__waitForMessage("page:"), "no snapshot before printing");
		var before = __lastMessage("page:");
		Assert.equals("page:1,90,", before.substr(0, 10));

		var result = __print(Path.join([__directory, "table.pdf"]), {});
		Assert.isTrue(result.success, result.error);
		Assert.isTrue(__countPages(Path.join([__directory, "table.pdf"])) >= 2, "the table should span pages");

		__messages = [];
		__webView.evaluateJavaScript(snapshot);
		Assert.isTrue(__waitForMessage("page:"), "no snapshot after printing");
		Assert.equals(before, __lastMessage("page:"));
	}

	public function testPrintCallbackMayDisposeAndReplaceTheWebView():Void
	{
		__loadAndWait("<!doctype html><html><body>first</body></html>");

		var replacementLoaded = false;
		__webView.printToPDF(Path.join([__directory, "callback.pdf"]), null, function(success:Bool, error:String):Void
		{
			__webView.dispose();
			__webView = __create();
			__webView.onComplete = function():Void replacementLoaded = true;
			__webView.loadString("<!doctype html><html><body>second</body></html>");
		});

		Assert.isTrue(__pumpUntil(function():Bool return replacementLoaded), "the replacement webview never loaded");
		Assert.isTrue(FileSystem.exists(Path.join([__directory, "callback.pdf"])));
	}

	public function testPrintToAMissingDirectoryReportsFailure():Void
	{
		__loadAndWait("<!doctype html><html><body>nowhere</body></html>");

		var result = __print(Path.join([__directory, "missing", "nested", "report.pdf"]), {});
		Assert.isTrue(result.done, "printToPDF never reported back");
		Assert.isFalse(result.success);
		Assert.notNull(result.error);
	}

	private function __create():WebView
	{
		var webView = new WebView(null, {startHidden: true});
		webView.onMessage = function(message:String):Void __messages.push(message);
		return webView;
	}

	private function __loadAndWait(html:String):Void
	{
		var completed = false;
		__webView.onComplete = function():Void completed = true;
		__webView.loadString(html);
		Assert.isTrue(__pumpUntil(function():Bool return completed), "the page did not load");
	}

	private function __navigateAndWait(url:String):Void
	{
		var completed = false;
		__webView.onComplete = function():Void completed = true;
		__webView.navigate(url);
		Assert.isTrue(__pumpUntil(function():Bool return completed), "navigation to " + url + " did not complete");
	}

	private function __print(path:String, options:PdfOptions):{done:Bool, success:Bool, error:String}
	{
		var result = {done: false, success: false, error: null};
		__webView.printToPDF(path, options, function(success:Bool, error:String):Void
		{
			result.done = true;
			result.success = success;
			result.error = error;
		});

		__pumpUntil(function():Bool return result.done);
		return result;
	}

	// WebKitGTK can update the title just after the load finishes.
	private function __waitForTitle(title:String):Bool
	{
		return __pumpUntil(function():Bool return __webView.title == title);
	}

	private function __waitForMessage(prefix:String):Bool
	{
		return __pumpUntil(function():Bool return __lastMessage(prefix) != null);
	}

	private function __lastMessage(prefix:String):String
	{
		var index = __messages.length;
		while (--index >= 0)
		{
			if (StringTools.startsWith(__messages[index], prefix))
			{
				return __messages[index];
			}
		}

		return null;
	}

	private function __writeFile(name:String, content:String):String
	{
		var path = Path.join([__directory, name]);
		File.saveContent(path, content);
		return path;
	}

	private static function __fileUrl(path:String):String
	{
		var segments = [for (segment in StringTools.replace(path, "\\", "/").split("/")) StringTools.urlEncode(segment)];
		if (segments.length > 0 && ~/^[A-Za-z]%3A$/.match(segments[0]))
		{
			segments[0] = segments[0].charAt(0) + ":";
		}

		var joined = segments.join("/");
		return StringTools.startsWith(joined, "/") ? "file://" + joined : "file:///" + joined;
	}

	private static function __pumpUntil(condition:Void->Bool):Bool
	{
		var deadline = Timer.stamp() + TIMEOUT_SECONDS;
		while (!condition() && Timer.stamp() < deadline)
		{
			WebView.processEvents();
			Sys.sleep(0.005);
		}

		return condition();
	}

	private static function __pdfText(path:String):String
	{
		var bytes = File.getBytes(path);
		return bytes.getString(0, bytes.length, RawNative);
	}

	private static function __countPages(path:String):Int
	{
		var count = 0;
		var pattern = ~/\/Type\s*\/Page(?![a-zA-Z])/;
		var rest = __pdfText(path);
		while (pattern.match(rest))
		{
			count++;
			rest = pattern.matchedRight();
		}

		return count;
	}

	private static function __mediaBox(path:String):{width:Float, height:Float}
	{
		var pattern = ~/\/MediaBox\s*\[\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\]/;
		if (!pattern.match(__pdfText(path)))
		{
			return null;
		}

		return {
			width: Std.parseFloat(pattern.matched(3)) - Std.parseFloat(pattern.matched(1)),
			height: Std.parseFloat(pattern.matched(4)) - Std.parseFloat(pattern.matched(2))
		};
	}
}
