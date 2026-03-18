package tests.webview;

import tests.Assert;
import webview.NativeHandleKind;
import webview.WebView;
import webview.WebViewHandle;
import webview.WebViewHint;

@:access(webview.WebView)
class WebViewTest
{
	public function new() {}

	public function testCallbacksRefreshStateAndReachConsumers():Void
	{
		__withWebView(function (webView:WebView, backend:FakeBackend):Void
		{
			var completed = false;
			var errorMessage:String = null;
			var focusEvents:Array<String> = [];
			var lastLocation:String = null;
			var lastMessage:String = null;

			webView.onComplete = function ():Void
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

			webView.onLocationChange = function (location:String):Void
			{
				lastLocation = location;
			};

			webView.onLocationChanging = function (location:String):Bool
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

			Assert.equals("https://haxe.org", webView.location);
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
			Assert.isTrue(backend.createdWithDebug);
			Assert.equals(windowHandle, backend.createdWithWindow);
			Assert.isFalse(webView.mediaPlaybackRequiresUserAction);
			Assert.equals("StageWebView demo", backend.createdWithOptions.userAgent);
			Assert.isFalse(backend.createdWithOptions.mediaPlaybackRequiresUserAction);
			Assert.isFalse(backend.createdWithOptions.enableContextMenu);
			Assert.equals("fake-handle", cast webView.handle);
		}, {debug: true, userAgent: "StageWebView demo", mediaPlaybackRequiresUserAction: false, enableContextMenu: false}, windowHandle);
	}

	public function testDisposeAndDestroyAreSafe():Void
	{
		__withWebView(function (webView:WebView, backend:FakeBackend):Void
		{
			Assert.notNull(webView.handle);

			webView.dispose();

			Assert.isTrue(backend.destroyed);
			Assert.isNull(webView.handle);
			Assert.isFalse(webView.canGoBack());
			Assert.isFalse(webView.canGoForward());

			webView.dispose();
			webView.destroy();
		});
	}

	public function testLoadStringValidatesMimeAndCachesBlankLocation():Void
	{
		__withWebView(function (webView:WebView, backend:FakeBackend):Void
		{
			webView.loadString("<h1>Bridge Party</h1>");

			Assert.equals("<h1>Bridge Party</h1>", backend.lastHtml);
			Assert.equals("about:blank", webView.location);
			Assert.equals("", webView.title);

			Assert.throws(function ():Void
			{
				webView.loadString("<p>Plain text no thank you</p>", "text/plain");
			}, "text/html");
		});
	}

	public function testNavigationAndCommandsDelegateToBackend():Void
	{
		__withWebView(function (webView:WebView, backend:FakeBackend):Void
		{
			backend.canGoBackValue = true;
			backend.canGoForwardValue = true;
			backend.registerNativeHandle(NativeHandleKind.UI_WIDGET, cast "widget-handle");

			webView.loadURL("https://openfl.org");
			webView.postMessage("hello from haxe");
			webView.assignFocus(7);
			webView.setSize(1280, 720, WebViewHint.FIXED);
			webView.setBounds(900, 540);
			webView.historyBack();
			webView.historyForward();
			webView.reload();
			webView.stop();

			Assert.equals("https://openfl.org", backend.lastNavigate);
			Assert.equals("https://openfl.org", webView.location);
			Assert.equals("hello from haxe", backend.lastMessage);
			Assert.equals(7, backend.lastFocusDirection);
			Assert.equals(1280, backend.lastSizeWidth);
			Assert.equals(720, backend.lastSizeHeight);
			Assert.equals(WebViewHint.FIXED, backend.lastSizeHints);
			Assert.equals(900, backend.lastBoundsWidth);
			Assert.equals(540, backend.lastBoundsHeight);
			Assert.equals(1, backend.historyBackCount);
			Assert.equals(1, backend.historyForwardCount);
			Assert.equals(1, backend.reloadCount);
			Assert.equals(1, backend.stopCount);
			Assert.isTrue(webView.canGoBack());
			Assert.isTrue(webView.canGoForward());
			Assert.isTrue(webView.isHistoryBackEnabled);
			Assert.isTrue(webView.isHistoryForwardEnabled);
			Assert.equals("widget-handle", cast webView.getNativeHandle(NativeHandleKind.UI_WIDGET));
		});
	}

	public function testTopLevelWindowControlsDelegateToBackend():Void
	{
		__withWebView(function (webView:WebView, backend:FakeBackend):Void
		{
			webView.setTitle("Solo Deck");
			webView.run();
			webView.terminate();

			Assert.equals("Solo Deck", backend.lastWindowTitle);
			Assert.equals(1, backend.runCount);
			Assert.equals(1, backend.terminateCount);
		});
	}

	private function __withWebView(run:WebView->FakeBackend->Void, ?options:Dynamic, ?window:WebViewHandle):Void
	{
		var backend = new FakeBackend();
		var error:Dynamic = null;

		try
		{
			WebView.__setBackendFactory(function (backendOptions:webview.WebViewOptions, backendWindow:WebViewHandle)
			{
				backend.createdWithOptions = backendOptions;
				backend.createdWithDebug = backendOptions != null && backendOptions.debug == true;
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
