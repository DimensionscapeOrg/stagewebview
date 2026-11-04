#if macro
package stagewebview._internal;

import haxe.io.Path;
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr.Field;
import sys.FileSystem;
import sys.io.File;

class ExtraParamsMacro
{
	private static var __configuredGtk:Bool = false;
	private static var __definedRoot:Bool = false;
	private static var __definedWindowsTarget:Bool = false;
	private static var __included:Bool = false;
	private static var __preparedHashLinkOutput:String = null;
	private static var __warnedRootOutput:Bool = false;

	public static function include():Void
	{
		var libraryRoot = __libraryRoot();
		var currentWorkingDirectory = Path.normalize(StringTools.replace(Sys.getCwd(), "\\", "/"));

		if (!__definedRoot && FileSystem.exists(Path.join([currentWorkingDirectory, "include.xml"])))
		{
			Compiler.define("stagewebview_root", currentWorkingDirectory);
			__definedRoot = true;
		}

		if (!__definedWindowsTarget && __isWindowsTarget())
		{
			Compiler.define("stagewebview_windows");
			__definedWindowsTarget = true;
		}

		if (!Context.defined("stagewebview_supported") && __isSupportedTarget())
		{
			Compiler.define("stagewebview_supported");
		}

		if (Context.defined("openfl") && __hasLimeNativeHandle())
		{
			Compiler.define("stagewebview_native_handle");
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

	// What a program using the native backend needs, set up as its class is built, so that a framework that only
	// depends on this library for its native code, as Lime does, pays nothing for it.
	public static function configureBackend():Array<Field>
	{
		if (!Context.defined("display"))
		{
			if (Context.defined("cpp") && __isLinuxDesktopTarget())
			{
				__configureGtk();
			}

			if (Context.defined("hl"))
			{
				__prepareHashLinkOutput(__libraryRoot());
			}
		}

		return null;
	}

	private static function __libraryRoot():String
	{
		var macroPath = Path.normalize(Context.resolvePath("stagewebview/_internal/ExtraParamsMacro.hx"));
		var srcDirectory = Path.directory(Path.directory(Path.directory(macroPath)));
		return Path.directory(srcDirectory);
	}

	// Native targets with a backend: hxcpp on Windows, Linux, macOS, iOS and Android, and HashLink on Windows.
	private static function __isSupportedTarget():Bool
	{
		if (Context.defined("cpp"))
		{
			if (Context.defined("emscripten") || Context.defined("tvos"))
			{
				return false;
			}

			return Context.defined("android") || Context.defined("ios") || ["Windows", "Linux", "Mac"].indexOf(Sys.systemName()) >= 0;
		}

		return Context.defined("hl") && Sys.systemName() == "Windows";
	}

	// Plain hxcpp defines no platform: it builds for the machine it runs on, unless told to build for a device.
	private static function __isWindowsTarget():Bool
	{
		return __isSupportedTarget() && !Context.defined("android") && !Context.defined("ios") && Sys.systemName() == "Windows";
	}

	// By the class rather than the version: a Lime from git can call itself 8.4.0 from before Window.nativeHandle.
	private static function __hasLimeNativeHandle():Bool
	{
		try
		{
			Context.resolvePath("lime/ui/WindowHandle.hx");
			return true;
		}
		catch (error:Dynamic)
		{
			return false;
		}
	}

	private static function __isLinuxDesktopTarget():Bool
	{
		if (Context.defined("android") || Context.defined("ios") || Context.defined("windows") || Context.defined("mac"))
		{
			return false;
		}

		return Context.defined("linux") || Sys.systemName() == "Linux";
	}

	// hxcpp build files cannot call pkg-config, so the GTK and WebKitGTK flags are resolved here and
	// attached to the native backend class as build XML: compiler flags for the library's files, libraries for the link.
	private static function __configureGtk():Void
	{
		if (__configuredGtk)
		{
			return;
		}

		__configuredGtk = true;

		var packages = ["gtk+-3.0", "webkit2gtk-4.1", "x11"];
		var cflags = __pkgConfig(["--cflags"].concat(packages));
		var libs = __pkgConfig(["--libs"].concat(packages));
		if (cflags == null || libs == null)
		{
			Context.fatalError("StageWebView on Linux needs GTK 3 and WebKitGTK 4.1 development files. On Debian or Ubuntu: "
				+ "sudo apt install pkg-config libgtk-3-dev libwebkit2gtk-4.1-dev", Context.currentPos());
			return;
		}

		var xml = new StringBuf();
		xml.add("<files id='stagewebview'>");
		for (flag in cflags)
		{
			xml.add("<compilerflag value='" + __escapeXml(flag) + "'/>");
		}
		xml.add("</files><target id='haxe'>");
		for (flag in libs)
		{
			xml.add("<lib name='" + __escapeXml(flag) + "'/>");
		}
		xml.add("</target>");

		// hxcpp honours one @:buildXml per class and WebViewExterns already has one, so attach to the backend class.
		Context.getLocalClass().get().meta.add(":buildXml", [macro $v{xml.toString()}], Context.currentPos());
	}

	private static function __pkgConfig(arguments:Array<String>):Array<String>
	{
		try
		{
			var process = new sys.io.Process("pkg-config", arguments);
			var output = StringTools.trim(process.stdout.readAll().toString());
			var exitCode = process.exitCode();
			process.close();

			if (exitCode != 0)
			{
				return null;
			}

			return [for (flag in ~/\s+/g.split(output)) if (flag != "") flag];
		}
		catch (_:Dynamic)
		{
			return null;
		}
	}

	private static function __escapeXml(value:String):String
	{
		return StringTools.htmlEscape(value, true);
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

	private static function __copyHashLinkRuntime(libraryRoot:String, outputDirectory:String):Void
	{
		var packageDirectory = Path.join([libraryRoot, "ndll", "Windows64"]);
		var hdllSource = Path.join([packageDirectory, "stagewebview.hdll"]);
		if (!FileSystem.exists(hdllSource))
		{
			var buildFile = Path.join([libraryRoot, "project", "BuildHashlink.xml"]);
			Context.fatalError("Missing HashLink prebuilt: " + Path.join([packageDirectory, "stagewebview.hdll"])
				+ ". Build it with: haxelib run hxcpp " + buildFile
				+ " -DHXCPP_M64 -DOUTPUT_DIR=" + packageDirectory
				+ " -DHASHLINK_INCLUDE=<path-to-hashlink-include> -DLIBHL_PATH=<path-to-libhl-lib> -DLIBHL_DLL_DIR=<path-to-libhl-dll>",
				Context.currentPos());
			return;
		}

		__copyIfNeeded(hdllSource, Path.join([outputDirectory, "stagewebview.hdll"]));
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
