package tests.native;

import demo.report.ReportDocument;
import haxe.Json;
import haxe.Timer;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import utest.Assert;
import utest.Test;
import webview.WebView;

/**
	Drives the platform webview through hidden instances: page events, the
	JavaScript bridge in both directions, and `printToPDF()`.
**/
class NativeWebViewTest extends Test
{
	private static inline final TIMEOUT_SECONDS:Float = 30;

	private var __webView:WebView;

	public function setup():Void
	{
		__webView = new WebView(null, {hidden: true});
	}

	public function teardown():Void
	{
		__webView.close();
		__webView = null;
	}

	public function testIsSupported():Void
	{
		Assert.isTrue(WebView.isSupported);
	}

	public function testLoadHTMLCompletesWithTitle():Void
	{
		var completed = false;
		__webView.onLoad = function():Void completed = true;
		__webView.loadHTML("<!doctype html><html><head><title>Native test</title></head><body>hello</body></html>");

		Assert.isTrue(__pumpUntil(function():Bool return completed), "onComplete did not fire");
		// WebKitGTK can update the title just after the load finishes.
		Assert.isTrue(__pumpUntil(function():Bool return __webView.title == "Native test"), "title is \"" + __webView.title + "\"");
	}

	public function testAPageFromHTMLIsNotAskedAbout():Void
	{
		var asked:Array<String> = [];
		var completed = false;
		__webView.onNavigate = function(location:String):Bool
		{
			asked.push(location);
			return false;
		};
		__webView.onLoad = function():Void completed = true;
		__webView.loadHTML("<!doctype html><html><body>hello</body></html>");

		Assert.isTrue(__pumpUntil(function():Bool return completed), "onLoad did not fire");
		Assert.equals(0, asked.length, Std.string(asked));
		Assert.equals("about:blank", __webView.url);
	}

	public function testAScriptGivesItsValueAsJSON():Void
	{
		__loadAndWait("<!doctype html><html><body></body></html>");

		Assert.equals("42", __evaluate("6 * 7").result);
		Assert.equals('"héllo"', __evaluate("'h\u00E9llo'").result);
		Assert.equals("true", __evaluate("1 < 2").result);
		Assert.same({a: 1, b: "x"}, Json.parse(__evaluate("({a: 1, b: 'x'})").result));
		Assert.equals("null", __evaluate("undefined").result);
	}

	public function testAScriptThatThrowsDoesNotHangTheRequest():Void
	{
		__loadAndWait("<!doctype html><html><body></body></html>");

		var thrown = __evaluate("throw new Error('Boom')");
		Assert.isTrue(thrown.done, "the script never reported back");

		#if android
		Assert.equals("null", thrown.result);
		#else
		Assert.isFalse(thrown.success);
		Assert.notNull(thrown.result);
		#end
	}

	public function testAClosedWebViewFailsAScriptAtOnce():Void
	{
		var hidden = new WebView(null, {hidden: true});
		hidden.close();

		var failure:String = null;
		hidden.evaluateJavaScript("1", function(success:Bool, result:String):Void failure = result);
		Assert.notNull(failure);
	}

	public function testAScriptInFlightSurvivesClosingTheWebView():Void
	{
		var hidden = new WebView(null, {hidden: true});
		var reported = 0;
		hidden.evaluateJavaScript("1", function(success:Bool, result:String):Void reported++);
		hidden.close();

		var end = Sys.time() + 0.3;
		while (Sys.time() < end)
		{
			WebView.processEvents();
			Sys.sleep(0.01);
		}

		Assert.isTrue(reported <= 1);
	}

	public function testAPageCannotForgeEventsWithSeparators():Void
	{
		var messages:Array<String> = [];
		__webView.onMessage = messages.push;
		__webView.loadHTML("<!doctype html><html><body><script>
			window.chrome.webview.postMessage('a\u001E1\u001Fmessage\u001Fb');
		</script></body></html>");

		Assert.isTrue(__pumpUntil(function():Bool return messages.length > 0), "the message never arrived");
		Assert.equals(1, messages.length);
		Assert.equals("a\x1E1\x1Fmessage\x1Fb", messages[0]);
	}

	public function testCancellingANavigationIsNotAnError():Void
	{
		var completed = false;
		__webView.onLoad = function():Void completed = true;
		__webView.loadHTML("<!doctype html><html><body>hello</body></html>");
		Assert.isTrue(__pumpUntil(function():Bool return completed), "onComplete did not fire");

		var asked = 0;
		var errors:Array<String> = [];
		__webView.onError = errors.push;
		__webView.onNavigate = function(location:String):Bool
		{
			asked++;
			return true;
		};
		__webView.load("https://example.invalid/never");

		Assert.isTrue(__pumpUntil(function():Bool return asked > 0), "onNavigate did not fire");
		var end = Sys.time() + 0.5;
		while (Sys.time() < end)
		{
			WebView.processEvents();
			Sys.sleep(0.01);
		}
		Assert.equals(0, errors.length, Std.string(errors));
	}

	public function testBridgeCarriesMessagesBothWays():Void
	{
		var messages:Array<String> = [];
		__webView.onMessage = function(message:String):Void
		{
			messages.push(message);
			if (message == "ready")
			{
				__webView.postMessage("ping é \"quoted\"");
			}
		};

		__webView.loadHTML("<!doctype html><html><body><script>
			window.chrome.webview.addEventListener('message', function (event) {
				window.chrome.webview.postMessage('echo:' + event.data);
			});
			window.chrome.webview.postMessage('ready');
		</script></body></html>");

		Assert.isTrue(__pumpUntil(function():Bool return messages.length >= 2), "expected two messages, got " + messages);
		Assert.equals("ready", messages[0]);
		Assert.equals("echo:ping é \"quoted\"", messages[1]);
	}

	public function testPrintToPDFWritesTwoPages():Void
	{
		var path = Path.join([Sys.getCwd(), "native-test-report.pdf"]);
		if (FileSystem.exists(path))
		{
			FileSystem.deleteFile(path);
		}

		var result:{done:Bool, success:Bool, error:String} = {done: false, success: false, error: null};
		__webView.onMessage = function(message:String):Void
		{
			var data:Dynamic = Json.parse(message);
			if (data.type == "ready")
			{
				__webView.postMessage(ReportDocument.fillMessage("native tests"));
			}
			else if (data.type == "filled")
			{
				__webView.printToPDF(path, {}, function(success:Bool, error:String):Void
				{
					result.done = true;
					result.success = success;
					result.error = error;
				});
			}
		};
		__webView.loadHTML(ReportDocument.html());

		Assert.isTrue(__pumpUntil(function():Bool return result.done), "printToPDF did not report back");
		Assert.isTrue(result.success, result.error);
		Assert.isTrue(FileSystem.exists(path), "no file at " + path);

		if (FileSystem.exists(path))
		{
			var bytes = File.getBytes(path);
			Assert.equals("%PDF", bytes.getString(0, 4, RawNative));
			Assert.equals(2, __countPages(bytes.getString(0, bytes.length, RawNative)));
			FileSystem.deleteFile(path);
		}
	}

	public function testPrintToPDFAfterDisposeReportsAnError():Void
	{
		var error:String = null;
		__webView.close();
		__webView.printToPDF("unused.pdf", null, function(success:Bool, message:String):Void error = success ? null : message);
		Assert.notNull(error);
		__webView = new WebView(null, {hidden: true});
	}

	private function __evaluate(script:String):{done:Bool, success:Bool, result:String}
	{
		var value = {done: false, success: false, result: null};
		__webView.evaluateJavaScript(script, function(success:Bool, result:String):Void
		{
			value.done = true;
			value.success = success;
			value.result = result;
		});

		__pumpUntil(function():Bool return value.done);
		return value;
	}

	private function __loadAndWait(html:String):Void
	{
		var completed = false;
		__webView.onLoad = function():Void completed = true;
		__webView.loadHTML(html);
		Assert.isTrue(__pumpUntil(function():Bool return completed), "onLoad did not fire");
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

	// Page objects are written uncompressed by every engine tried (Skia, Quartz); /Pages is the tree root.
	private static function __countPages(pdf:String):Int
	{
		var count = 0;
		var pattern = ~/\/Type\s*\/Page(?![a-zA-Z])/;
		var rest = pdf;
		while (pattern.match(rest))
		{
			count++;
			rest = pattern.matchedRight();
		}

		return count;
	}
}
