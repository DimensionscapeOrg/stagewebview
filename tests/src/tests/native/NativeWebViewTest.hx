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
		__webView = new WebView(null, {startHidden: true});
	}

	public function teardown():Void
	{
		__webView.dispose();
		__webView = null;
	}

	public function testIsSupported():Void
	{
		Assert.isTrue(WebView.isSupported);
	}

	public function testLoadStringCompletesWithTitle():Void
	{
		var completed = false;
		__webView.onComplete = function():Void completed = true;
		__webView.loadString("<!doctype html><html><head><title>Native test</title></head><body>hello</body></html>");

		Assert.isTrue(__pumpUntil(function():Bool return completed), "onComplete did not fire");
		Assert.equals("Native test", __webView.title);
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

		__webView.loadString("<!doctype html><html><body><script>
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
		__webView.loadString(ReportDocument.html());

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
		__webView.dispose();
		__webView.printToPDF("unused.pdf", null, function(success:Bool, message:String):Void error = success ? null : message);
		Assert.notNull(error);
		__webView = new WebView(null, {startHidden: true});
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
