package tests;

import tests.openfl.StageWebViewTest;
import tests.webview.WebViewTest;
import utest.UTest;

/**
	Unit tests that run without a native webview (`haxe build/tests.hxml`).
	The native backend is covered by `tests.NativeTestMain`.
**/
class TestMain
{
	private static function main():Void
	{
		UTest.run([new WebViewTest(), new StageWebViewTest()]);
	}
}
