package;

import demo.report.ReportDocument;
import haxe.Json;
import haxe.io.Path;
import lime.app.Application;
import lime.graphics.RenderContext;
import lime.system.System;
import webview.WebView;

/**
	The PDF report flow on every platform, as a Lime app:

	1. a hidden `webview.WebView` loads the report template and fills it over
	   the JavaScript bridge;
	2. it prints the page to a PDF in the app's storage directory.

	Progress is printed with `trace`, and the last line is also written to
	`report-status.txt` beside the PDF, so automated runs can read the outcome.
	Set STAGEWEBVIEW_SAMPLE_EXIT=1 on desktop to quit once that is written.
**/
class Main extends Application
{
	private var __pdfPath:String;
	private var __renderer:WebView;

	public function new()
	{
		super();
	}

	public override function onWindowCreate():Void
	{
		var directory = System.applicationStorageDirectory;
		__pdfPath = Path.join([directory != null && directory != "" ? directory : ".", "stagewebview-report.pdf"]);

		if (!WebView.isSupported)
		{
			__finish("FAIL: no webview backend on this platform");
			return;
		}

		__report("Rendering the report off screen...");
		__renderer = new WebView(null, {hidden: true});
		__renderer.onError = function(message:String):Void __finish("FAIL: " + message);
		__renderer.onMessage = function(message:String):Void
		{
			var data:Dynamic = Json.parse(message);
			switch (data.type)
			{
				case "ready":
					__report("Bridge connected (" + data.engine + ")");
					__renderer.postMessage(ReportDocument.fillMessage(__hostName()));

				case "filled":
					__renderer.evaluateJavaScript("document.title", function(success:Bool, title:String):Void
					{
						if (!success)
						{
							__finish("FAIL: " + title);
							return;
						}

						__report(Json.parse(title) + " filled with " + data.rows + " rows; printing to " + __pdfPath);
						__renderer.printToPDF(__pdfPath, {}, __onPrinted);
					});

				default:
			}
		};
		__renderer.loadHTML(ReportDocument.html());
	}

	public override function update(deltaTime:Int):Void
	{
		// Linux and Android deliver the webview's events only when they are pumped.
		if (__renderer != null)
		{
			WebView.processEvents();
		}
	}

	public override function render(context:RenderContext):Void
	{
		switch (context.type)
		{
			case OPENGL, OPENGLES, WEBGL:
				var gl = context.webgl;
				gl.clearColor(0xF4 / 0xFF, 0xF6 / 0xFF, 0xF8 / 0xFF, 1);
				gl.clear(gl.COLOR_BUFFER_BIT);

			default:
		}
	}

	private function __onPrinted(success:Bool, error:String):Void
	{
		__renderer.close();
		__renderer = null;

		if (!success)
		{
			__finish("FAIL: " + error);
			return;
		}

		__finish("OK: " + __pdfPath + " (" + sys.FileSystem.stat(__pdfPath).size + " bytes)");
	}

	private function __finish(message:String):Void
	{
		__report(message);

		#if desktop
		if (Sys.getEnv("STAGEWEBVIEW_SAMPLE_EXIT") == "1")
		{
			System.exit(StringTools.startsWith(message, "OK:") ? 0 : 1);
		}
		#end
	}

	private function __hostName():String
	{
		return "Lime " + (System.platformName != null ? System.platformName : Sys.systemName());
	}

	private function __report(message:String):Void
	{
		trace(message);

		if (__pdfPath != null)
		{
			try
			{
				sys.io.File.saveContent(Path.join([Path.directory(__pdfPath), "report-status.txt"]), message + "\n");
			}
			catch (_:Dynamic) {}
		}
	}
}
