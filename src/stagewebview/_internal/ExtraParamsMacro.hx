#if macro
package stagewebview._internal;

import haxe.io.Path;
import haxe.macro.Compiler;
import haxe.macro.Context;
import sys.FileSystem;
import sys.io.File;

class ExtraParamsMacro
{
	private static var __definedRoot:Bool = false;
	private static var __definedWindowsTarget:Bool = false;
	private static var __included:Bool = false;
	private static var __preparedHashLinkOutput:String = null;

	public static function include():Void
	{
		var macroPath = Path.normalize(Context.resolvePath("stagewebview/_internal/ExtraParamsMacro.hx"));
		var srcDirectory = Path.directory(Path.directory(Path.directory(macroPath)));
		var libraryRoot = Path.directory(srcDirectory);
		var currentWorkingDirectory = Path.normalize(StringTools.replace(Sys.getCwd(), "\\", "/"));

		if (!__definedRoot && FileSystem.exists(Path.join([currentWorkingDirectory, "include.xml"])))
		{
			Compiler.define("stagewebview_root", currentWorkingDirectory);
			__definedRoot = true;
		}

		if (!__definedWindowsTarget && Sys.systemName() == "Windows")
		{
			Compiler.define("stagewebview_windows");
			__definedWindowsTarget = true;
		}

		if (Context.defined("hl") && !Context.defined("display"))
		{
			__prepareHashLinkOutput(libraryRoot);
		}

		if (__included || !Context.defined("openfl"))
		{
			return;
		}

		var openflSourcePath = Path.join([libraryRoot, "src-openfl"]);

		if (FileSystem.exists(openflSourcePath))
		{
			Compiler.addClassPath(openflSourcePath);
			__included = true;
		}
	}

	private static function __prepareHashLinkOutput(libraryRoot:String):Void
	{
		var output = Compiler.getOutput();
		if (output == null || output == "")
		{
			return;
		}

		var outputDirectory = Path.normalize(Path.directory(output));
		if (outputDirectory == "")
		{
			outputDirectory = Path.normalize(StringTools.replace(Sys.getCwd(), "\\", "/"));
		}

		if (__preparedHashLinkOutput == outputDirectory)
		{
			return;
		}

		__preparedHashLinkOutput = outputDirectory;

		var packageDirectory = Path.join([libraryRoot, "ndll", "Windows64"]);
		var hdllSource = Path.join([packageDirectory, "stagewebview.hdll"]);
		if (!FileSystem.exists(hdllSource))
		{
			var buildFile = Path.join([libraryRoot, "build", "BuildHashlink.xml"]);
			Context.fatalError("Missing HashLink prebuilt: " + Path.join([packageDirectory, "stagewebview.hdll"])
				+ ". Build it with: haxelib run hxcpp " + buildFile
				+ " -DHXCPP_M64 -DOUTPUT_DIR=" + packageDirectory
				+ " -DHASHLINK_INCLUDE=<path-to-hashlink-include> -DLIBHL_PATH=<path-to-libhl-lib> -DLIBHL_DLL_DIR=<path-to-libhl-dll>",
				Context.currentPos());
			return;
		}

		__copyIfNeeded(hdllSource, Path.join([outputDirectory, "stagewebview.hdll"]));

		var loaderSource = Path.join([libraryRoot, "lib", "windows", "x64", "WebView2Loader.dll"]);
		if (FileSystem.exists(loaderSource))
		{
			__copyIfNeeded(loaderSource, Path.join([outputDirectory, "WebView2Loader.dll"]));
		}
	}

	private static function __copyIfNeeded(source:String, destination:String):Void
	{
		source = Path.normalize(source);
		destination = Path.normalize(destination);

		if (source == destination)
		{
			return;
		}

		var destinationDirectory = Path.directory(destination);
		if (destinationDirectory != "" && !FileSystem.exists(destinationDirectory))
		{
			FileSystem.createDirectory(destinationDirectory);
		}

		if (!FileSystem.exists(destination) || FileSystem.stat(source).mtime.getTime() != FileSystem.stat(destination).mtime.getTime()
			|| FileSystem.stat(source).size != FileSystem.stat(destination).size)
		{
			File.copy(source, destination);
		}
	}
}
#end
