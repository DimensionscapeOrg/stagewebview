package tests;

class Assert
{
	public static function equals(expected:Dynamic, actual:Dynamic, ?message:String):Void
	{
		if (expected != actual)
		{
			fail(message != null ? message : ('Expected "' + Std.string(expected) + '" but got "' + Std.string(actual) + '"'));
		}
	}

	public static function isFalse(value:Bool, ?message:String):Void
	{
		if (value)
		{
			fail(message != null ? message : "Expected false");
		}
	}

	public static function isNull(value:Dynamic, ?message:String):Void
	{
		if (value != null)
		{
			fail(message != null ? message : ('Expected null but got "' + Std.string(value) + '"'));
		}
	}

	public static function isTrue(value:Bool, ?message:String):Void
	{
		if (!value)
		{
			fail(message != null ? message : "Expected true");
		}
	}

	public static function notNull(value:Dynamic, ?message:String):Void
	{
		if (value == null)
		{
			fail(message != null ? message : "Expected non-null value");
		}
	}

	public static function same(expected:Dynamic, actual:Dynamic, ?message:String):Void
	{
		if (expected != actual)
		{
			fail(message != null ? message : "Expected the same instance");
		}
	}

	public static function throws(callback:Void->Void, ?messageContains:String):Void
	{
		try
		{
			callback();
		}
		catch (error:Dynamic)
		{
			var text = Std.string(error);

			if (messageContains != null && text.indexOf(messageContains) == -1)
			{
				fail('Expected exception containing "' + messageContains + '" but got "' + text + '"');
			}

			return;
		}

		fail("Expected exception to be thrown");
	}

	public static function fail(message:String):Void
	{
		throw message;
	}
}
