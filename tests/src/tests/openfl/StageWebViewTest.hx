package tests.openfl;

import openfl.geom.Rectangle;
import openfl.media.StageWebView;
import tests.Assert;

class StageWebViewTest
{
	public function new() {}

	public function testCanConstructWithoutAnOpenFLApplication():Void
	{
		var webView = new StageWebView();

		Assert.isTrue(webView.mediaPlaybackRequiresUserAction);

		webView.dispose();
		webView.dispose();
	}

	public function testConstructorOptionsCanDisableMediaPlaybackRequirement():Void
	{
		var configured = new StageWebView({mediaPlaybackRequiresUserAction: false});
		var legacyUseNativeOnly = new StageWebView(false);
		var legacyTwoBoolShape = new StageWebView(false, false);

		Assert.isFalse(configured.mediaPlaybackRequiresUserAction, "Object configuration should disable mediaPlaybackRequiresUserAction");
		Assert.isTrue(legacyUseNativeOnly.mediaPlaybackRequiresUserAction, "Single legacy bool should be treated as ignored useNative");
		Assert.isFalse(legacyTwoBoolShape.mediaPlaybackRequiresUserAction, "Two legacy bools should use the second value for mediaPlaybackRequiresUserAction");

		configured.dispose();
		legacyUseNativeOnly.dispose();
		legacyTwoBoolShape.dispose();
	}

	public function testLoadStringCachesAboutBlankAndValidatesMimeType():Void
	{
		var webView = new StageWebView();
		webView.loadString("<h1>Tiny portal, big hello</h1>");

		Assert.equals("about:blank", webView.location);
		Assert.throws(function ():Void
		{
			webView.loadString("plain text", "text/plain");
		}, "text/html");

		webView.dispose();
	}

	public function testLoadURLAndViewPortStateAreStoredWithoutNativeCreation():Void
	{
		var webView = new StageWebView();
		var viewPort = new Rectangle(24, 36, 640, 360);

		webView.loadURL("https://openfl.org");
		webView.viewPort = viewPort;

		Assert.equals("https://openfl.org", webView.location);
		Assert.same(viewPort, webView.viewPort);

		webView.dispose();
	}

	public function testViewPortRejectsNullAndNegativeSizes():Void
	{
		var webView = new StageWebView();

		Assert.throws(function ():Void
		{
			webView.viewPort = null;
		}, "valid Rectangle");

		Assert.throws(function ():Void
		{
			webView.viewPort = new Rectangle(0, 0, -1, 100);
		}, "valid Rectangle");

		Assert.throws(function ():Void
		{
			webView.viewPort = new Rectangle(0, 0, 100, -1);
		}, "valid Rectangle");

		webView.dispose();
	}
}
