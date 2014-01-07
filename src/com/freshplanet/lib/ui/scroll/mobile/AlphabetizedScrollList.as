package com.freshplanet.lib.ui.scroll.mobile
{
	import com.freshplanet.lib.util.pool.IPool;
	
	import flash.display.DisplayObject;
	import flash.display.Shape;
	import flash.display.Sprite;
	import flash.events.MouseEvent;
	import flash.geom.Rectangle;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.text.TextFormatAlign;
	
	public class AlphabetizedScrollList extends Sprite
	{
		
		private static var SYMBOLS : String = 'AlphabetizedScrollList.SYMBOLS' ;
		
		private static var ALPHABET : Array = [ 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', { label : '1', data : '123456789' } ];
		
		// this array of Strings determine how keys will be grouped,
		// by default it's letter by letter
		// but you could also define it as ABC - DEF - HIJ ...
		// it also defines in wich order the keys will be presented, so you can define numbers first or last
		// any element that cannot be affiliated to one of those key will be displayed at the end
		// it is case insensitive
		private var _groupBy:Array = ALPHABET;
		
		private var _dataProvider:Vector.<*> ;
		
		private var _alphaIndex:Function ; // returns a string on wich the alphabetical sort will be based
		
		private var _alphaHash:Object ;
		
		private var _scrollList:ScrollList ;
		private var _scrollListData:Vector.<*> ;
		
		private var _anchorPool:IPool ;
		private var _initAnchor:Function ; // function(DisplayObject, String):void
		private var _elementPool:IPool ;
		private var _initElement:Function ; // function(DisplayObject, elementData):void
		
		private var _anchors:Vector.<DisplayObject> ;
		
		private var _alphabetSelector:Sprite ;
		private var _alphabetSelectorBackground:Shape ;
		private var _alphabetSelectorScrollController:ScrollController ;
		
		private var _getListItemBounds:Function ;
		
		public function AlphabetizedScrollList(
								dataProvider:Vector.<*>,
								viewport:Rectangle,
								alphaIndex:Function, // function(elementData):String
								elementPool:IPool,
								initElementFct:Function, // function(DisplayObject, elementData):void
								anchorPool:IPool,
								initAnchorFct:Function // function(DisplayObject, String):void
							)
		{
			
			super() ;
			
			_alphaIndex = alphaIndex ;
			
			_elementPool = elementPool ;
			_initElement = initElementFct ;
			
			_anchorPool = anchorPool ;
			_initAnchor = initAnchorFct ;
			
			_getListItemBounds = defaultGetBounds ;
			_anchors = new Vector.<DisplayObject>() ;
			
			_scrollList = new ScrollList(
									ScrollList.SCROLL_LIST_ORIENTATION_VERTICAL,
									new <*>[],
									viewport,
									getElementBounds,
									createListElement,
									disposeListElement
								) ;
			
			_scrollList.addEventListener( ScrollListEvent.CLICK, onElementClicked ) ;
			
			addChild( _scrollList ) ;
			
			this.dataProvider = dataProvider ;
			
		}
		
		// ---------------------------------------
		//  PUBLIC
		// ---------------------------------------
		
		public function refresh():void
		{
			
			// reinit current list with the same data
			dataProvider = dataProvider ;
			
		}
		
		public function dispose():void
		{
			
			_scrollList.dispose() ;
			this.removeChild( _alphabetSelector ) ;
			
		}
		
		// ---------------------------------------
		//  PRIVATE
		// ---------------------------------------
		
		private function onElementClicked( e:ScrollListEvent ):void
		{
			
			dispatchEvent( new ScrollListEvent( e.type, e.listElement, e.data ) ) ;
			
		}
		
		private function getElementBounds( data:* ):Rectangle
		{
			
			var el:DisplayObject = createListElement( data ) ;
			var bounds:Rectangle = _getListItemBounds(el) ;
			disposeListElement( el ) ;
			return bounds ;
			
		}
		
		private function defaultGetBounds(el:DisplayObject):Rectangle
		{
			
			return el.getBounds( el ) ;
			
		}		
		
		private function createListElement( data:* ):DisplayObject
		{
			
			if( !data.hasOwnProperty( "type" ) )
				throw "unexpected data" ;
			
			if( data['type'] == "anchor" )
			{
				var a:DisplayObject = _anchorPool.pop() ;
				_anchors.push(a) ;
				var anchorName:String = data.data ;
				if ( anchorName == SYMBOLS )
					anchorName = '' ;
				_initAnchor( a, anchorName ) ;
				return a ;
			}else{
				var el:DisplayObject = _elementPool.pop() ; 
				_initElement( el, data.data ) ;
				return el ;
			}
			
		}
		
		private function disposeListElement( element:DisplayObject ):void
		{
			
			var anchorIndex:int = _anchors.indexOf( element )
			if ( anchorIndex > -1 )
			{
				
				_anchors.splice( anchorIndex, 1 ) ;
				_anchorPool.push( element ) ;
				
			}
			else
			{
				
				_elementPool.push( element ) ;
				
			}
			
		}
		
		private function createAlphabetSelector( _bounds:Rectangle ):void
		{
			
			if ( _alphabetSelector )
				this.removeChild( _alphabetSelector ) ;
			
			_alphabetSelector = new Sprite();
			_alphabetSelectorBackground = new Shape();
			_alphabetSelectorBackground.graphics.beginFill(0x000000, 1.0);
			_alphabetSelectorBackground.graphics.drawRoundRect(0, 0, 37, _bounds.height - 16, 37);
			_alphabetSelectorBackground.graphics.endFill();
			_alphabetSelectorBackground.y = 8 ;
			_alphabetSelector.addChild(_alphabetSelectorBackground);
			_alphabetSelectorBackground.alpha = 0.1;
			
			_alphabetSelector.x = _bounds.width - _alphabetSelector.width - 5 ;
			
			var letterHeight:Number = (_bounds.height - 32) / _groupBy.length ;
			var letterContainer:Sprite = new Sprite() ;
			var textfield:TextField;
			var currentY:Number = 16;
			var defaultFormat:TextFormat = new TextFormat();
			defaultFormat.align = flash.text.TextFormatAlign.CENTER;
			defaultFormat.size = 20;
			defaultFormat.font = "Futura Medium";
			defaultFormat.color = 0x4c626d;
			for each (var key:* in _groupBy)
			{
				var letter:String = ''
				if ( key is String )
					letter = key ;
				else
					letter = key.label ;
				
				textfield = new TextField;
				textfield.defaultTextFormat = defaultFormat;
				textfield.text = letter ;
				textfield.height = 25 ;
				textfield.width = 37;
				textfield.y = currentY;
				textfield.x = 0;
				textfield.selectable = false;
				letterContainer.addChild(textfield);
				textfield.addEventListener(MouseEvent.ROLL_OVER, onLetterOver, false, 0, true);
				textfield.addEventListener(MouseEvent.ROLL_OUT, onLetterOut, false, 0, true);
				currentY += letterHeight ;
			}
			_alphabetSelector.addChild( letterContainer ) ;
			
			_alphabetSelector.addEventListener(MouseEvent.ROLL_OVER, onAlphabetOver, false, 0, true);
			_alphabetSelector.addEventListener(MouseEvent.ROLL_OUT, onAlphabetOut, false, 0, true);
			
			this.addChild(_alphabetSelector);
			
		}
		
		private function onAlphabetOver(event:MouseEvent):void
		{
			_alphabetSelectorBackground.alpha = 0.3;
		}
		
		private function onAlphabetOut(event:MouseEvent):void
		{
			_alphabetSelectorBackground.alpha = 0.1;
		}
		
		private function onLetterClicked(event:MouseEvent):void
		{
			var textfield:TextField = event.target as TextField;
			gotoAnchor(textfield.text);
		}
		
		private function onLetterOver(event:MouseEvent):void
		{
			var textfield:TextField = event.target as TextField;
			textfield.textColor = 0xffffff;
			gotoAnchor(textfield.text);
		}
		
		private function onLetterOut(event:MouseEvent):void
		{
			var textfield:TextField = event.target as TextField;
			textfield.textColor = 0x4c626d ;
		}
		
		private function gotoAnchor( anchorName:String ):void
		{
			
			_scrollList.scrollTo( _alphaHash[ anchorName ].anchor ) ;
			
		}
		
		// ---------------------------------------
		//  GETTERS AND SETTERS
		// ---------------------------------------
		
		public function get dataProvider():Vector.<*>
		{
			
			return _dataProvider ;
			
		}
		
		public function set dataProvider(value:Vector.<*>):void
		{
			
			_dataProvider = value ;
			
			_alphaHash = new Object() ;
			
			// construct the hash wich consist in a dictionary of
			//	groupingKey ->	{
			//						data : dictionary of
			//								elementHash ->	element
			//						anchor : reference to the scrollList data associated with this grouping Key
			//					}
			for ( var i:int=0 ; i<_dataProvider.length ; ++i )
			{
				
				var elementHash:String = _alphaIndex(_dataProvider[i]) ;
				
				var hashKey:String = SYMBOLS ; // default key, means the element will be displayed at the end if no other key can be found in the grouping funciton
				
				// look for the first letter of the hash in the grouping function and determine the hashKey for that element
				for ( var j:int=0 ; j < _groupBy.length ; ++j )
				{	
					
					var keyLabel : String = '' ;
					var keyData : String = '' ;
					if ( _groupBy[j] is String )
					{
						keyLabel = _groupBy[j] ;
						keyData = _groupBy[j] ;
					} else {
						keyLabel = _groupBy[j].label ;
						keyData = _groupBy[j].data ;
					}
					
					// use case incensitive keys
					if ( keyData.toUpperCase().indexOf( elementHash.substr(0,1).toUpperCase() ) > -1 )
					{
						
						hashKey = keyLabel ;
						
						break ;
					}
				}
				
				if ( !_alphaHash.hasOwnProperty( hashKey ) )
				{
					_alphaHash[ hashKey ] = {
								data : new Object(),
								anchor : { type : "anchor", data : hashKey }
							} ;
				}
				
				_alphaHash[ hashKey ].data[ elementHash ] = _dataProvider[i] ;
				
			}
			
			// construct the dataProvider that will be passed to the scrollList
			_scrollListData = new Vector.<*>() ;
			var keys:Array = _groupBy.concat( [ SYMBOLS ] ) ;
			for ( j=0 ; j < keys.length ; ++j )
			{
				
				var label:String = '';
				if ( keys[j] is String )
					label = keys[j] ;
				else
					label = keys[j].label ;
				
				if ( !_alphaHash.hasOwnProperty( label ) )
				{
					_alphaHash[ label ] = {
						data : new Object(),
						anchor : { type : "anchor", data : label }
					} ;
				}
				
				_scrollListData.push( _alphaHash[label].anchor ) ;
				
				var sortedElements : Vector.<*> = new <*>[] ;
				for ( var key : * in _alphaHash[label].data )
					sortedElements.push(key) ;
				sortedElements.sort( Array.CASEINSENSITIVE ) ;
				
				for ( var k:int = 0 ; k < sortedElements.length ; ++k )
				{
					
					_scrollListData.push(
						{
							type : "element",
							data : _alphaHash[label].data[ sortedElements[k] ]
						} ) ;
					
				}
				
			}
			
			if( _alphaHash[ SYMBOLS ].data.length == 0 )
				_scrollListData.splice( _alphaHash[SYMBOLS].anchor, 1 ) ;
			
			_scrollList.dataProvider = _scrollListData ;
			
			createAlphabetSelector( _scrollList.bounds ) ;
			
		}

		public function get groupBy():Array
		{
			return _groupBy;
		}

		public function set groupBy(value:Array):void
		{
			_groupBy = value;
			dataProvider = dataProvider ; // reset the content
		}

		public function set getListItemBounds(value:Function):void
		{
			_getListItemBounds = value;
			dataProvider = dataProvider ;
		}

		
	}
}