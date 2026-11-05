package;

import demo.report.ReportDocument;
import haxe.Json;
import haxe.io.Path;
import lime.system.System;
import openfl.display.PNGEncoderOptions;
import openfl.display.Sprite;
import openfl.events.DataEvent;
import openfl.events.ErrorEvent;
import openfl.events.Event;
import openfl.events.WebViewDrawEvent;
import openfl.geom.Rectangle;
import openfl.media.StageWebView;
import openfl.text.TextField;
import openfl.text.TextFormat;
import webview.WebView;

/**
	The PDF report flow on every platform, as an OpenFL app:

	1. a hidden `webview.WebView` loads the report template and fills it over
	   the JavaScript bridge;
	2. it prints the page to a PDF in the app's storage directory;
	3. a `StageWebView` shows the same report on stage, filled the same way.

	Progress is shown on stage and printed with `trace`, and the last line is
	also written to `report-status.txt` beside the PDF, so automated runs can
	read the outcome; a capture of the preview is saved as `report-preview.png`.
	Set STAGEWEBVIEW_SAMPLE_EXIT=1 on desktop to quit once that is written.
**/
class Main extends Sprite
{
	private static inline final PREVIEW_TOP:Int = 64;

	private var __pdfPath:String;
	private var __preview:StageWebView;
	private var __previewFailed:Bool = false;
	private var __renderer:WebView;
	private var __status:TextField;

	public function new()
	{
		super();
		addEventListener(Event.ADDED_TO_STAGE, __onAddedToStage);
	}

	private function __onAddedToStage(_:Event):Void
	{
		removeEventListener(Event.ADDED_TO_STAGE, __onAddedToStage);

		__status = new TextField();
		__status.defaultTextFormat = new TextFormat("_sans", 16, 0x1B2733);
		__status.x = 16;
		__status.y = 16;
		__status.width = stage.stageWidth - 32;
		__status.height = PREVIEW_TOP - 16;
		addChild(__status);

		var directory = System.applicationStorageDirectory;
		__pdfPath = Path.join([directory != null && directory != "" ? directory : ".", "stagewebview-report.pdf"]);

		if (!WebView.isSupported)
		{
			__report("FAIL: no webview backend on this platform");
			return;
		}

		stage.addEventListener(Event.ENTER_FRAME, __onEnterFrame);
		stage.addEventListener(Event.RESIZE, __onResize);
		__render();
	}

	private function __render():Void
	{
		__report("Rendering the report off screen...");
		__renderer = new WebView(null, {hidden: true});
		__renderer.onError = function(message:String):Void __report("FAIL: " + message);
		__renderer.onMessage = function(message:String):Void
		{
			var data:Dynamic = Json.parse(message);
			switch (data.type)
			{
				case "ready":
					__report("Bridge connected (" + data.engine + ")");
					__renderer.postMessage(ReportDocument.fillMessage(__hostName()));

				case "filled":
					__report("Template filled with " + data.rows + " rows; printing to " + __pdfPath);
					__renderer.printToPDF(__pdfPath, {}, __onPrinted);

				default:
			}
		};
		__renderer.loadHTML(ReportDocument.html());
	}

	private function __onPrinted(success:Bool, error:String):Void
	{
		__renderer.close();
		__renderer = null;

		if (!success)
		{
			__report("FAIL: " + error);
			return;
		}

		var size = sys.FileSystem.exists(__pdfPath) ? sys.FileSystem.stat(__pdfPath).size : 0;
		__report("PDF written (" + size + " bytes). Showing the report on stage...");

		__preview = new StageWebView();
		__preview.addEventListener("webViewMessage", __onPreviewMessage);
		__preview.addEventListener(ErrorEvent.ERROR, __onPreviewError);
		__preview.stage = stage;
		if (__previewFailed)
		{
			return;
		}

		__onResize(null);
		__preview.loadString(ReportDocument.html());
	}

	private function __onPreviewMessage(event:DataEvent):Void
	{
		var data:Dynamic = Json.parse(event.data);
		switch (data.type)
		{
			case "ready":
				__preview.postMessage(ReportDocument.fillMessage(__hostName()));

			case "filled":
				__onPreviewFilled();

			default:
		}
	}

	private function __onPreviewError(event:ErrorEvent):Void
	{
		__previewFailed = true;
		__report("FAIL: preview: " + event.text);

		#if desktop
		if (Sys.getEnv("STAGEWEBVIEW_SAMPLE_EXIT") == "1")
		{
			lime.system.System.exit(1);
		}
		#end
	}

	private function __onPreviewFilled():Void
	{
		__preview.removeEventListener("webViewMessage", __onPreviewMessage);
		__report("OK: " + __pdfPath + " (" + sys.FileSystem.stat(__pdfPath).size + " bytes)");

		// Give the page a moment to paint, then keep a picture of the preview beside the PDF.
		haxe.Timer.delay(function():Void
		{
			__preview.addEventListener(WebViewDrawEvent.WEBVIEW_DRAW_COMPLETE, __onPreviewCaptured);
			__preview.addEventListener(ErrorEvent.ERROR, __onPreviewCaptured);
			__preview.drawViewPortAsync(new PNGEncoderOptions());
		}, 2000);
	}

	private function __onPreviewCaptured(event:Event):Void
	{
		if (Std.isOfType(event, WebViewDrawEvent) && (cast event : WebViewDrawEvent).pngImage != null)
		{
			var png = (cast event : WebViewDrawEvent).pngImage;
			sys.io.File.saveBytes(Path.join([Path.directory(__pdfPath), "report-preview.png"]), png);
			trace("Preview captured to report-preview.png");
		}
		else
		{
			trace("Preview capture failed: " + (Std.isOfType(event, ErrorEvent) ? (cast event : ErrorEvent).text : "no image"));
		}

		#if desktop
		if (Sys.getEnv("STAGEWEBVIEW_SAMPLE_EXIT") == "1")
		{
			// STAGEWEBVIEW_SAMPLE_HOLD keeps the window up for that many seconds, for screenshots.
			var hold = Std.parseFloat(Sys.getEnv("STAGEWEBVIEW_SAMPLE_HOLD"));
			haxe.Timer.delay(function():Void lime.system.System.exit(0), Math.isNaN(hold) ? 0 : Std.int(hold * 1000));
		}
		#end
	}

	private function __onEnterFrame(_:Event):Void
	{
		// The hidden renderer is not a StageWebView, so pump its events here (needed on Linux and Android).
		if (__renderer != null)
		{
			WebView.processEvents();
		}
	}

	private function __onResize(_:Event):Void
	{
		__status.width = stage.stageWidth - 32;

		if (__preview != null)
		{
			__preview.viewPort = new Rectangle(0, PREVIEW_TOP, stage.stageWidth, Math.max(0, stage.stageHeight - PREVIEW_TOP));
		}
	}

	private function __hostName():String
	{
		return "OpenFL " + (System.platformName != null ? System.platformName : Sys.systemName());
	}

	private function __report(message:String):Void
	{
		trace(message);
		__status.text = message;

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
