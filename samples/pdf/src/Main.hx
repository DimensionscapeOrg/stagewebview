package;

import demo.report.ReportDocument;
import haxe.Json;
import haxe.Timer;
import webview.WebView;

/**
	Headless PDF sample for plain Haxe (hxcpp) on Windows, Linux and macOS.

	Creates a webview with no visible window, loads the report template, fills it
	over the JavaScript bridge and prints it to a PDF. Exits 0 when the PDF was
	written, 1 otherwise.

	Usage: `Main [output.pdf]`
**/
class Main
{
	private static inline final TIMEOUT_SECONDS:Float = 60;

	public static function main():Void
	{
		var args = Sys.args();
		var output = args.length > 0 ? args[0] : "stagewebview-report.pdf";
		var finished = false;
		var exitCode = 1;

		var webView = new WebView(null, {hidden: true});

		webView.onError = function(message:String):Void
		{
			Sys.println("error: " + message);
		};

		webView.onMessage = function(message:String):Void
		{
			var data:Dynamic = Json.parse(message);

			switch (data.type)
			{
				case "ready":
					Sys.println("bridge: page ready (" + data.engine + ")");
					webView.postMessage(ReportDocument.fillMessage("Haxe " + Sys.systemName()));

				case "filled":
					Sys.println("bridge: page filled " + data.rows + " rows, document height " + data.height + "px");
					webView.printToPDF(output, {}, function(success:Bool, error:String):Void
					{
						if (success && sys.FileSystem.exists(output))
						{
							Sys.println("pdf: wrote " + sys.FileSystem.absolutePath(output) + " (" + sys.FileSystem.stat(output).size + " bytes)");
							exitCode = 0;
						}
						else
						{
							Sys.println("pdf: failed: " + error);
						}

						finished = true;
					});

				default:
					Sys.println("bridge: unexpected message " + message);
			}
		};

		webView.loadHTML(ReportDocument.html());

		var deadline = Timer.stamp() + TIMEOUT_SECONDS;
		while (!finished && Timer.stamp() < deadline)
		{
			WebView.processEvents();
			Sys.sleep(0.005);
		}

		if (!finished)
		{
			Sys.println("timed out after " + TIMEOUT_SECONDS + " seconds");
		}

		webView.close();
		Sys.exit(exitCode);
	}
}
