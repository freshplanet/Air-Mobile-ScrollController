package com.freshplanet.lib.ui.scroll.mobile.example
{
	import com.freshplanet.lib.ui.example.util.RectangleSprite;
	import com.freshplanet.lib.ui.scroll.mobile.ScrollController;
	
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.geom.Rectangle;
	
	
	public class ScrollControllerExample extends Sprite
	{
		private var _scroll:ScrollController;
		
		public function ScrollControllerExample()
		{
			super();
			
			this.addEventListener(Event.ADDED_TO_STAGE, this.onAddedToStage);
			this.addEventListener(Event.REMOVED_FROM_STAGE, this.onRemovedFromStage);
		}
		
		private function onAddedToStage(e:Event):void
		{
			this.removeEventListener(Event.ADDED_TO_STAGE, this.onAddedToStage);
			
			var container:RectangleSprite = new RectangleSprite(0x440000, 50, 50, this.stage.stageWidth - 100, this.stage.stageHeight - 100);//red background
			this.addChild(container);
			
			var content:RectangleSprite = new RectangleSprite(0x444477, 0, 0, this.stage.stageWidth - 100, this.stage.stageHeight * 2, 30);//blue foreground
			container.addChild(content);
			
			var containerViewport:Rectangle = new Rectangle(0, 0, this.stage.stageWidth - 100, this.stage.stageHeight - 100);
			
			this._scroll = new ScrollController();
			this._scroll.horizontalScrollingEnabled = false;
			this._scroll.addScrollControll(content, container, containerViewport);
		}
		
		private function onRemovedFromStage(e:Event):void
		{
			this.removeEventListener(Event.REMOVED_FROM_STAGE, this.onRemovedFromStage);
			
			this._scroll.removeScrollControll();
		}
	}
}