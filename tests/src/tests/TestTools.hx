package tests;

import haxe.PosInfos;
import utest.Assert;

class TestTools
{
	/**
		Asserts that `callback` throws, and that the error text contains
		`messageContains` when given. `utest.Assert.raises` checks the error type
		only, and this library throws strings.
	**/
	public static function throwsContaining(callback:Void->Void, ?messageContains:String, ?pos:PosInfos):Void
	{
		try
		{
			callback();
		}
		catch (error:Dynamic)
		{
			var text = Std.string(error);
			if (messageContains != null)
			{
				Assert.isTrue(text.indexOf(messageContains) >= 0, 'Expected an error containing "' + messageContains + '" but got "' + text + '"', pos);
			}
			else
			{
				Assert.pass(null, pos);
			}

			return;
		}

		Assert.fail("Expected an error to be thrown", pos);
	}
}
