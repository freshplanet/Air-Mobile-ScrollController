package com.freshplanet.lib.ui.scroll.mobile
{
	import flash.display.DisplayObject;
	import flash.events.Event;
	
	public class ScrollListEvent extends Event
	{
		
		public static const CLICK : String = "ui.scroll.ScrollListEvent.CLICK" ;
		
		public var listElement : DisplayObject ;
		public var data : * ;
		
		public function ScrollListEvent(type:String, listElement:DisplayObject, data:*, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			
			super(type, bubbles, cancelable);
			
			this.listElement = listElement ;
			this.data = data ;
			
		}
		
	}
}