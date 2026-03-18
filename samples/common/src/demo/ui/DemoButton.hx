package demo.ui;

import openfl.display.Shape;
import openfl.display.Sprite;
import openfl.events.MouseEvent;
import openfl.filters.DropShadowFilter;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;

class DemoButton extends Sprite
{
	public var onTrigger:Void->Void;
	public var selected(default, null):Bool;

	private var __activeFill:Int;
	private var __baseFill:Int;
	private var __background:Shape;
	private var __enabled:Bool;
	private var __height:Int;
	private var __hoverFill:Int;
	private var __labelField:TextField;
	private var __width:Int;

	public function new(label:String, width:Int = 120, height:Int = 36, baseFill:Int = 0x19243C, hoverFill:Int = 0x23355B, activeFill:Int = 0xD97A3A,
		textColor:Int = 0xF7F7FA)
	{
		super();

		__width = width;
		__height = height;
		__baseFill = baseFill;
		__hoverFill = hoverFill;
		__activeFill = activeFill;
		__enabled = true;

		buttonMode = true;
		useHandCursor = true;
		mouseChildren = false;
		filters = [new DropShadowFilter(10, 90, 0x000000, 0.18, 0, 6, 1, 1)];

		__background = new Shape();
		addChild(__background);

		var labelFormat = new TextFormat("_sans", 14, textColor, true);
		labelFormat.align = TextFormatAlign.CENTER;

		__labelField = new TextField();
		__labelField.defaultTextFormat = labelFormat;
		__labelField.selectable = false;
		__labelField.mouseEnabled = false;
		__labelField.multiline = false;
		__labelField.wordWrap = false;
		__labelField.width = width;
		__labelField.height = height + 4;
		__labelField.text = label;
		__labelField.setTextFormat(labelFormat);
		addChild(__labelField);

		__redraw(__baseFill);
		__layoutLabel();

		addEventListener(MouseEvent.MOUSE_OVER, __onMouseOver);
		addEventListener(MouseEvent.MOUSE_OUT, __onMouseOut);
		addEventListener(MouseEvent.CLICK, __onClick);
	}

	public function setEnabled(value:Bool):Void
	{
		__enabled = value;
		mouseEnabled = value;
		alpha = value ? 1 : 0.45;
		__redraw(selected ? __activeFill : __baseFill);
	}

	public function setLabel(value:String):Void
	{
		__labelField.text = value;
		__labelField.setTextFormat(__labelField.defaultTextFormat);
		__layoutLabel();
	}

	public function setSelected(value:Bool):Void
	{
		selected = value;
		__redraw(value ? __activeFill : __baseFill);
	}

	private function __layoutLabel():Void
	{
		__labelField.y = Std.int((__height - (__labelField.textHeight + 4)) * 0.5) - 1;
	}

	private function __redraw(fill:Int):Void
	{
		__background.graphics.clear();
		__background.graphics.lineStyle(1, 0xFFFFFF, selected ? 0.14 : 0.08);
		__background.graphics.beginFill(fill, __enabled ? 1 : 0.9);
		__background.graphics.drawRoundRect(0, 0, __width, __height, 14, 14);
		__background.graphics.endFill();
	}

	private function __onClick(_:MouseEvent):Void
	{
		if (__enabled && onTrigger != null)
		{
			onTrigger();
		}
	}

	private function __onMouseOut(_:MouseEvent):Void
	{
		__redraw(selected ? __activeFill : __baseFill);
	}

	private function __onMouseOver(_:MouseEvent):Void
	{
		if (__enabled)
		{
			__redraw(selected ? __activeFill : __hoverFill);
		}
	}
}
