package com.freshplanet.lib.ui.example.util
{
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.text.TextField;
	
	public class RectangleSprite extends Sprite
	{
		public function RectangleSprite(color:uint, rsX:int, rsY:int, rsWidth:int, rsHeight:int, segmentHeight:int = -1)
		{
			super();
			
			this.x = rsX;
			this.y = rsY;
			
			var shape:Shape;
			if(segmentHeight > 0)
			{
				var segmentCount:int = rsHeight / segmentHeight;
				segmentHeight = rsHeight / segmentCount;
				for (var i:int = 0; i < segmentCount; i++)
				{
					shape = new Shape();
					shape.y = i*segmentHeight;
					shape.graphics.beginFill(i % 2 == 0 ? color : color * 2);
					shape.graphics.drawRect(0, 0, rsWidth, segmentHeight);
					shape.graphics.endFill();
					this.addChild(shape);
					
					var textfield:TextField = new TextField();
					textfield.textColor = 0xffffff;
					textfield.y = i*segmentHeight;
					textfield.height = segmentHeight - 1;
					textfield.text = String(i);
					this.addChild(textfield);
				}
			}
			else
			{
				shape = new Shape();
				shape.graphics.beginFill(color);
				shape.graphics.drawRect(0, 0, rsWidth, rsHeight);
				shape.graphics.endFill();
				this.addChild(shape);
			}
			
		}
	}
}