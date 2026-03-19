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
	private static var __preparedCppOutput:String = null;
	private static var __warnedRootOutput:Bool = false;

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

		if (!Context.defined("display"))
		{
			if (Context.defined("hl"))
			{
				__prepareHashLinkOutput(libraryRoot);
			}
			else if (Context.defined("cpp") && !Context.defined("openfl"))
			{
				__prepareCppOutput(libraryRoot);
			}
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

		var outputDirectory = __normalizeOutputDirectory(output);
		if (outputDirectory == null)
		{
			return;
		}

		var runtimeDirectory = __resolveHashLinkRuntimeDirectory(output, outputDirectory);

		if (__preparedHashLinkOutput == runtimeDirectory)
		{
			return;
		}

		__preparedHashLinkOutput = runtimeDirectory;
		__copyHashLinkRuntime(libraryRoot, runtimeDirectory);
	}

	private static function __prepareCppOutput(libraryRoot:String):Void
	{
		var output = Compiler.getOutput();
		if (output == null || output == "")
		{
			return;
		}

		var outputDirectory = __normalizeOutputDirectory(output);
		if (outputDirectory == null)
		{
			return;
		}

		if (__preparedCppOutput == outputDirectory)
		{
			return;
		}

		__preparedCppOutput = outputDirectory;
		__copyWindowsRuntime(libraryRoot, outputDirectory);
	}

	private static function __copyHashLinkRuntime(libraryRoot:String, outputDirectory:String):Void
	{
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
		__copyWindowsRuntime(libraryRoot, outputDirectory);
	}

	private static function __copyWindowsRuntime(libraryRoot:String, outputDirectory:String):Void
	{
		var loaderSource = Path.join([libraryRoot, "lib", "windows", "x64", "WebView2Loader.dll"]);
		if (FileSystem.exists(loaderSource))
		{
			__copyIfNeeded(loaderSource, Path.join([outputDirectory, "WebView2Loader.dll"]));
		}

		var embeddedBrowserSource = Path.join([libraryRoot, "lib", "windows", "EBWebView", "x64", "EmbeddedBrowserWebView.dll"]);
		if (FileSystem.exists(embeddedBrowserSource))
		{
			__copyIfNeeded(embeddedBrowserSource, Path.join([outputDirectory, "EBWebView", "x64", "EmbeddedBrowserWebView.dll"]));
		}
	}

	private static function __normalizeOutputDirectory(output:String):String
	{
		var normalizedOutput = Path.normalize(output);
		var outputDirectory = Path.extension(normalizedOutput) != "" ? Path.directory(normalizedOutput) : normalizedOutput;
		var currentWorkingDirectory = Path.normalize(StringTools.replace(Sys.getCwd(), "\\", "/"));

		if (outputDirectory == "" || outputDirectory == "." || outputDirectory == currentWorkingDirectory)
		{
			if (!Context.defined("stagewebview_allow_root_output"))
			{
				if (!__warnedRootOutput)
				{
					Context.warning("StageWebView skipped auto-copying runtime files because the build output resolves to the project root. Use an explicit output directory such as -cpp bin/cpp or -hl bin/hl/hlboot.dat, or define -Dstagewebview_allow_root_output to keep root copies.", Context.currentPos());
					__warnedRootOutput = true;
				}

				return null;
			}

			outputDirectory = currentWorkingDirectory;
		}

		return outputDirectory != "" ? outputDirectory : null;
	}

	private static function __resolveHashLinkRuntimeDirectory(output:String, outputDirectory:String):String
	{
		if (Context.defined("openfl") && Path.withoutDirectory(Path.withoutExtension(output)) == "ApplicationMain"
			&& Path.withoutDirectory(outputDirectory) == "obj")
		{
			return Path.normalize(Path.join([Path.directory(outputDirectory), "bin"]));
		}

		return outputDirectory;
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
