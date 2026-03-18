package tests;

import tests.openfl.StageWebViewTest;
import tests.webview.WebViewTest;

class TestMain
{
	private static var __failureCount:Int = 0;

	private static function main():Void
	{
		__runCase(new WebViewTest());
		__runCase(new StageWebViewTest());

		Sys.println("");

		if (__failureCount > 0)
		{
			Sys.println("Test suite failed with " + __failureCount + " failing test(s).");
			Sys.exit(1);
		}

		Sys.println("All tests passed.");
	}

	private static function __runCase(instance:Dynamic):Void
	{
		var cls = Type.getClass(instance);
		var className = Type.getClassName(cls);
		var fields = Type.getInstanceFields(cls);

		fields.sort(Reflect.compare);

		for (field in fields)
		{
			if (StringTools.startsWith(field, "test"))
			{
				__runTest(className, instance, field);
			}
		}
	}

	private static function __runTest(className:String, instance:Dynamic, field:String):Void
	{
		try
		{
			Reflect.callMethod(instance, Reflect.field(instance, field), []);
			Sys.println("PASS " + className + "." + field);
		}
		catch (error:Dynamic)
		{
			__failureCount++;
			Sys.println("FAIL " + className + "." + field);
			Sys.println("  " + Std.string(error));
		}
	}
}
