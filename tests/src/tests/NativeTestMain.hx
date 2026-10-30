package tests;

import tests.native.NativeWebViewTest;
import utest.UTest;

/**
	Tests against the real platform webview (`haxe build/tests-native.hxml`).
	They create hidden webviews, so Linux needs a display (Xvfb in CI).
**/
class NativeTestMain
{
	private static function main():Void
	{
		UTest.run([new NativeWebViewTest()]);
	}
}
