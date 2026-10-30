package tests;

import tests.native.NativeBehaviourTest;
import tests.native.NativeWebViewTest;
import utest.Runner;
import utest.ui.Report;

/**
	Tests against the real platform webview (`haxe build/tests-native.hxml`).
	They create hidden webviews, so Linux needs a display (Xvfb in CI).
**/
class NativeTestMain
{
	private static function main():Void
	{
		var runner = new Runner();
		runner.addCase(new NativeWebViewTest());
		runner.addCase(new NativeBehaviourTest());

		// The report prints only at the end, so name each test as it starts: a test that hangs is then visible in the log.
		runner.onTestStart.add(function(handler):Void
		{
			Sys.println("running " + Type.getClassName(Type.getClass(handler.fixture.target)) + "." + handler.fixture.method);
			Sys.stdout().flush();
		});

		Report.create(runner);
		runner.run();
	}
}
