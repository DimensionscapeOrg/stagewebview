package tests.webview;

import utest.Assert;
import utest.Test;
import webview.NativeHandleKind;
import webview.WebView;
import webview.WebViewHandle;
import webview.WebViewHint;

@:access(webview.WebView)
class WebViewTest extends Test
{

	public function testIsNotSupportedWithoutABackend():Void
	{
		// The interpreter has no backend, whatever machine it runs on
		Assert.isFalse(WebView.isSupported);
	}

	public function testCallbacksRefreshStateAndReachConsumers():Void
	{
		__withWebView(function (webView:WebView, backend:FakeBackend):Void
		{
			var completed = false;
			var errorMessage:String = null;
			var focusEvents:Array<String> = [];
			var lastLocation:String = null;
			var lastMessage:String = null;

			webView.onLoad = function ():Void
			{
				completed = true;
			};

			webView.onError = function (message:String):Void
			{
				errorMessage = message;
			};

			webView.onFocusIn = function ():Void
			{
				focusEvents.push("in");
			};

			webView.onFocusOut = function ():Void
			{
				focusEvents.push("out");
			};

			webView.onURLChange = function (location:String):Void
			{
				lastLocation = location;
			};

			webView.onNavigate = function (location:String):Bool
			{
				return location.indexOf("blocked") != -1;
			};

			webView.onMessage = function (message:String):Void
			{
				lastMessage = message;
			};

			backend.title = "Haxe Home";

			Assert.isTrue(backend.emitLocationChanging("https://blocked.example"));
			Assert.isFalse(backend.emitLocationChanging("https://haxe.org"));

			backend.emitLocationChange("https://haxe.org");
			backend.emitMessage("bridge-party");
			backend.emitError("Kaboom");
			backend.emitFocusIn();
			backend.emitFocusOut();
			backend.title = "Haxe Title";
			backend.emitComplete();

			Assert.equals("https://haxe.org", webView.url);
			Assert.equals("Haxe Title", webView.title);
			Assert.equals("https://haxe.org", lastLocation);
			Assert.equals("bridge-party", lastMessage);
			Assert.equals("Kaboom", errorMessage);
			Assert.equals("in", focusEvents[0]);
			Assert.equals("out", focusEvents[1]);
			Assert.isTrue(completed);
		});
	}

	public function testConstructorUsesFactoryAndOptions():Void
	{
		var windowHandle:WebViewHandle = cast "host-window";

		__withWebView(function (webView:WebView, backend:FakeBackend):Void
		{
			Assert.equals(windowHandle, backend.createdWithWindow);
			Assert.isTrue(backend.createdWithOptions.devTools);
			Assert.equals("StageWebView demo", backend.createdWithOptions.userAgent);
			Assert.isTrue(backend.createdWithOptions.autoplay);
			Assert.isFalse(backend.createdWithOptions.contextMenu);
			Assert.equals("fake-handle", cast webView.handle);
		}, {devTools: true, userAgent: "StageWebView demo", autoplay: true, contextMenu: false}, windowHandle);
	}

	public function testHiddenReachesBackend():Void
	{
		__withWebView(function (webView:WebView, backend:FakeBackend):Void
		{
			Assert.isTrue(backend.createdWithOptions.hidden);
		}, {hidden: true});
	}

	public function testPrintToPDFUsesDefaultsAndReportsResult():Void
	{
		__withWebView(function (webView:WebView, backend:FakeBackend):Void
		{
			var results = [];
			webView.printToPDF("report.pdf", null, function (success:Bool, error:String):Void
			{
				results.push(success);
			});

			Assert.equals(1, results.length);
			Assert.isTrue(results[0]);
			Assert.isTrue(StringTools.endsWith(backend.lastPdfPath, "report.pdf"));
			Assert.isTrue(haxe.io.Path.isAbsolute(backend.lastPdfPath));
			Assert.equals(8.5, backend.lastPdfOptions.pageWidth);
			Assert.equals(11.0, backend.lastPdfOptions.pageHeight);
			Assert.equals(0.4, backend.lastPdfOptions.marginLeft);
			Assert.isTrue(backend.lastPdfOptions.printBackground);
			Assert.isTrue(backend.lastPdfOptions.repeatTableHeaders);

			backend.pdfResult = {success: false, error: "disk full"};
			var message:String = null;
			webView.printToPDF("report.pdf", {landscape: true, pageWidth: 8.27, pageHeight: 11.69}, function (success:Bool, error:String):Void
			{
				message = error;
			});

			Assert.equals("disk full", message);
			Assert.isTrue(backend.lastPdfOptions.landscape);
			Assert.equals(8.27, backend.lastPdfOptions.pageWidth);
			Assert.equals(0.4, backend.lastPdfOptions.marginTop);

			webView.close();
			var disposedMessage:String = null;
			webView.printToPDF("report.pdf", null, function (success:Bool, error:String):Void
			{
				disposedMessage = error;
			});
			Assert.notNull(disposedMessage);
		});
	}

	public function testCloseIsSafe():Void
	{
		__withWebView(function (webView:WebView, backend:FakeBackend):Void
		{
			Assert.notNull(webView.handle);

			webView.close();

			Assert.isTrue(backend.destroyed);
			Assert.isNull(webView.handle);
			Assert.isFalse(webView.canGoBack);
			Assert.isFalse(webView.canGoForward);

			webView.close();
		});
	}

	public function testLoadHTMLCachesABlankURL():Void
	{
		__withWebView(function (webView:WebView, backend:FakeBackend):Void
		{
			webView.loadHTML("<h1>Bridge Party</h1>");

			Assert.equals("<h1>Bridge Party</h1>", backend.lastHtml);
			Assert.equals("about:blank", webView.url);
			Assert.equals("", webView.title);
		});
	}

	public function testNavigationAndCommandsDelegateToBackend():Void
	{
		__withWebView(function (webView:WebView, backend:FakeBackend):Void
		{
			backend.canGoBackValue = true;
			backend.canGoForwardValue = true;
			backend.registerNativeHandle(NativeHandleKind.UI_WIDGET, cast "widget-handle");

			webView.load("https://openfl.org");
			webView.postMessage("hello from haxe");
			webView.focus(7);
			webView.resize(1280, 720, WebViewHint.FIXED);
			webView.goBack();
			webView.goForward();
			webView.reload();
			webView.stop();

			Assert.equals("https://openfl.org", backend.lastNavigate);
			Assert.equals("https://openfl.org", webView.url);
			Assert.equals("hello from haxe", backend.lastMessage);
			Assert.equals(7, backend.lastFocusDirection);
			Assert.equals(1280, backend.lastSizeWidth);
			Assert.equals(720, backend.lastSizeHeight);
			Assert.equals(WebViewHint.FIXED, backend.lastSizeHints);
			Assert.equals(0, backend.lastBoundsWidth);
			Assert.equals(1, backend.historyBackCount);
			Assert.equals(1, backend.historyForwardCount);
			Assert.equals(1, backend.reloadCount);
			Assert.equals(1, backend.stopCount);
			Assert.isTrue(webView.canGoBack);
			Assert.isTrue(webView.canGoForward);
			Assert.equals("widget-handle", cast webView.getNativeHandle(NativeHandleKind.UI_WIDGET));
		});
	}

	public function testAnEmbeddedWebViewResizesItsContent():Void
	{
		__withWebView(function (webView:WebView, backend:FakeBackend):Void
		{
			webView.resize(900, 540);

			Assert.equals(900, backend.lastBoundsWidth);
			Assert.equals(540, backend.lastBoundsHeight);
			Assert.equals(0, backend.lastSizeWidth);
		}, null, cast "host-window");
	}

	public function testScriptsDelegateToBackend():Void
	{
		__withWebView(function (webView:WebView, backend:FakeBackend):Void
		{
			webView.addInitScript("window.a = 1;");
			webView.evaluateJavaScript("window.b = 2;");

			Assert.same(["window.a = 1;"], backend.initScripts);
			Assert.same(["window.b = 2;"], backend.evaluatedScripts);

			webView.close();
			webView.addInitScript("ignored");
			webView.evaluateJavaScript("ignored");
			Assert.equals(1, backend.initScripts.length);
			Assert.equals(1, backend.evaluatedScripts.length);
		});
	}

	public function testAScriptReportsItsValue():Void
	{
		__withWebView(function (webView:WebView, backend:FakeBackend):Void
		{
			var results:Array<String> = [];
			var report = function (success:Bool, result:String):Void results.push(success + ":" + result);

			backend.scriptResult = {success: true, result: "42"};
			webView.evaluateJavaScript("6 * 7", report);

			backend.scriptResult = {success: false, result: "Boom"};
			webView.evaluateJavaScript("throw 'Boom'", report);

			webView.close();
			webView.evaluateJavaScript("ignored", report);

			Assert.equals("true:42", results[0]);
			Assert.equals("false:Boom", results[1]);
			Assert.equals("false:The webview has closed", results[2]);
		});
	}

	public function testTopLevelWindowControlsDelegateToBackend():Void
	{
		__withWebView(function (webView:WebView, backend:FakeBackend):Void
		{
			webView.setWindowTitle("Solo Deck");
			webView.run();
			webView.terminate();

			Assert.equals("Solo Deck", backend.lastWindowTitle);
			Assert.equals(1, backend.runCount);
			Assert.equals(1, backend.terminateCount);
		});
	}

	private function __withWebView(run:WebView->FakeBackend->Void, ?options:webview.WebViewOptions, ?window:WebViewHandle):Void
	{
		var backend = new FakeBackend();
		var error:Dynamic = null;

		try
		{
			WebView.__setBackendFactory(function (backendOptions:webview.WebViewOptions, backendWindow:WebViewHandle)
			{
				backend.createdWithOptions = backendOptions;
				backend.createdWithWindow = backendWindow;
				return backend;
			});

			var webView = new WebView(window, options);
			run(webView, backend);
		}
		catch (caught:Dynamic)
		{
			error = caught;
		}

		WebView.__resetBackendFactory();

		if (error != null)
		{
			throw error;
		}
	}
}
