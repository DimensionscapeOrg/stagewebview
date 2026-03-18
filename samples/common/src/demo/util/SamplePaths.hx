package demo.util;

import haxe.io.Path;
import sys.FileSystem;

class SamplePaths
{
	public static function resolveFromExecutable(relativePath:String):String
	{
		var executableDirectory = Path.directory(Sys.programPath());
		return Path.normalize(Path.join([executableDirectory, relativePath]));
	}

	public static function resolveIfExists(relativePath:String):String
	{
		var path = resolveFromExecutable(relativePath);
		return FileSystem.exists(path) ? path : null;
	}

	public static function toFileUrl(path:String):String
	{
		if (path == null || path == "")
		{
			return null;
		}

		var normalized = StringTools.replace(Path.normalize(path), "\\", "/");

		if (!StringTools.startsWith(normalized, "/"))
		{
			normalized = "/" + normalized;
		}

		return "file://" + normalized;
	}
}
