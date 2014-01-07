package
{
	import com.freshplanet.lib.ui.scroll.mobile.example.ScrollControllerExample;
	
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.utils.setTimeout;
	
	public class ScrollControllerExampleApp extends Sprite
	{
		public function ScrollControllerExampleApp()
		{
			super();
			
			// support autoOrients
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;
			
			setTimeout(showScrollControllerExample, 100);
		}
		
		private function showScrollControllerExample():void
		{
			this.removeChildren();
			this.addChild(new ScrollControllerExample());
		}
	}
}