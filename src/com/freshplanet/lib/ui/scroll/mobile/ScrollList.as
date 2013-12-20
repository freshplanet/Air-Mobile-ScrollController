package com.freshplanet.lib.ui.scroll.mobile
{
	
	import flash.display.DisplayObject;
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	
	/**
	 * @author Renaud Bardet
	 * 
	 * This Class handles a scrollable list of any displayable items
	 * it is optimised for long lists
	 */
	public class ScrollList extends Sprite
	{
		
		public static const SCROLL_LIST_ORIENTATION_HORIZONTAL:String = "horizontal" ;
		public static const SCROLL_LIST_ORIENTATION_VERTICAL:String = "vertical" ;
		
		private var _orientation:String ;
		
		private var _dataProvider : Vector.<*>;
		
		private var _content : Sprite;
		private var _extraContent:Sprite;
		private var _listContent:Sprite;
		
		private var _scrollController : ScrollController;
		
		private var _getElementBounds : Function ;
		
		private var _createElement : Function ; // function(elementData):DisplayObject
		
		private var _releaseElement : Function ; // function(DisplayObject):void
		
		private var _upperIndex : int ; // index of data wich is currently represented by the upper effective element
		
		private var _cacheElementsBounds : Vector.<Rectangle> ;
		private var _cacheContentBounds : Rectangle ;
		
		private var _currentElements : Array ; // used as a int-hash
		
		// ---------------------------------------
		//  CONSTRUCTOR
		// ---------------------------------------
		
		public function ScrollList(
							orientation:String,
							dataProvider:Vector.<*>,			// elementData
							boundsRect:Rectangle,
							getElementBoundsFct:Function,		// function(elementData):Rectangle
							createElementFct:Function,			// function(elemenetData):DisplayObject
							releaseElementFct:Function = null	// function(DisplayObject):void
						)
		{
			
			if ( orientation != SCROLL_LIST_ORIENTATION_HORIZONTAL && orientation != SCROLL_LIST_ORIENTATION_VERTICAL )
				throw new ArgumentError( "Orientation should be one of refered Strings SCROLL_LIST_ORIENTATION_HORIZONTAL or SCROLL_LIST_ORIENTATION_VERTICAL" ) ;
			
			_orientation = orientation ;
			
			if ( !dataProvider )
				throw new ArgumentError( "You should provide a dataProvider even if it is empty" ) ;
			
			this._getElementBounds = getElementBoundsFct ;
			this._createElement = createElementFct ;
			this._releaseElement = releaseElementFct ;
			
			this._content = new Sprite();
			_extraContent = new Sprite();
			_listContent = new Sprite();
			
			addChild( this._content );
			_content.addChild(_extraContent);
			_content.addChild(_listContent);
			
			_scrollController = new ScrollController() ;
			_scrollController.horizontalScrollingEnabled = _orientation == SCROLL_LIST_ORIENTATION_HORIZONTAL ;
			_scrollController.verticalScrollingEnabled = _orientation == SCROLL_LIST_ORIENTATION_VERTICAL ;
			_scrollController.displayVerticalScrollbar = true;
			_scrollController.addScrollControll( _content, this, boundsRect, null, 1 ) ;
			
			this.dataProvider = dataProvider ;
			
			_scrollController.addEventListener( ScrollController.SCROLL_POSITION_CHANGE, onScrollChanged, false, 0, true ) ;
			
			addEventListener( Event.ADDED_TO_STAGE, onAddedToStage, false, 0, true ) ;
			
		}
		
		// ---------------------------------------
		//  PUBLIC
		// ---------------------------------------
		
		public function addExtraContent(object:DisplayObject):void
		{
			_extraContent.addChild(object);
		}
		
		public function setListMask(mask:DisplayObject):void
		{
			_extraContent.addChild(mask);
			_listContent.mask = mask;
		}
		/**
		 * scroll to a specified element in the list
		 * if the element is duplicated, the first element from the top will be considered
		 * @param data	an element present in dataProvider
		 */
		public function scrollTo( data:*, animated:Boolean = false ):void
		{
			
			for( var i:int = 0 ; i < _dataProvider.length ; ++i )
			{
				
				if ( _dataProvider[i] == data )
				{
					
					var elBounds:Rectangle = _cacheElementsBounds[i] ;
					var to:Point = elBounds.topLeft.clone();
					
					if ( _orientation == SCROLL_LIST_ORIENTATION_VERTICAL )
						to.y = Math.min( to.y, _cacheContentBounds.height - bounds.height ) ;
					else
						to.x = Math.min( to.x, _cacheContentBounds.width - bounds.width ) ;
					
					_scrollController.scrollTo( to, animated ) ;
					redraw() ;
					
					break;
				}
				
			}
			
		}
		
		public function dispose():void
		{
			
			_scrollController.removeScrollControll() ;
			
			for each ( var el:DisplayObject in _currentElements )
			{
				
				_listContent.removeChild( el ) ;
				el.removeEventListener( MouseEvent.MOUSE_DOWN, onElementMouseDown ) ;
				el.removeEventListener( MouseEvent.MOUSE_UP, onElementMouseUp ) ;
				_releaseElement( el ) ;
				
			}
			
			_currentElements = null ;
			
		}
		
		// ---------------------------------------
		//  PRIVATE
		// ---------------------------------------
		
		private function onScrollChanged( e: Event ):void
		{
			
			redraw() ;
			
		}
		
		private function onAddedToStage( e : Event ):void
		{
			
			redraw() ;
			
		}
		
		private function redraw():void
		{
			
			var displayedBounds:Rectangle = bounds.clone() ;
			if ( _orientation == SCROLL_LIST_ORIENTATION_VERTICAL )
				displayedBounds.y += _scrollController.scrollPosition.y ;
			else
				displayedBounds.x += _scrollController.scrollPosition.x ;
			
			for ( var i:int = 0 ; i < _currentElements.length ; ++i )
			{
				
				if ( _currentElements[i] == undefined )
					continue ;
				
				var elBounds:Rectangle = _currentElements[i].getBounds( _listContent ) ;
				
				// if the element is not visible anymore
				if (
					_orientation == SCROLL_LIST_ORIENTATION_VERTICAL && ( elBounds.bottom < displayedBounds.top || elBounds.top > displayedBounds.bottom )
					||
					_orientation == SCROLL_LIST_ORIENTATION_HORIZONTAL && ( elBounds.right < displayedBounds.left || elBounds.left > displayedBounds.right )
				)
				{
					
					_listContent.removeChild( _currentElements[i] ) ;
					_currentElements[i].removeEventListener( MouseEvent.MOUSE_DOWN, onElementMouseDown ) ;
					_currentElements[i].removeEventListener( MouseEvent.MOUSE_UP, onElementMouseUp ) ;
					_releaseElement( _currentElements[i] ) ;
					delete _currentElements[i] ; // delete the reference in the array but keep the indexes of other elements intact
					
				}
				
			}
			
			for ( i = 0 ; i < _cacheElementsBounds.length ; ++i )
			{
				
				if ( _currentElements[i] == undefined ) // if it's not currently displayed  
				{
					
					elBounds = _cacheElementsBounds[i] ;
					
					// check if it's visible
					if ( _orientation == SCROLL_LIST_ORIENTATION_VERTICAL )
					{
						if ( elBounds.bottom < displayedBounds.top ) // + _scrollController.speed
							continue ; // too high, skip to the next
						else if ( elBounds.top > displayedBounds.bottom )
							break ; // too low, next are not relevant
					}
					else
					{
						if ( elBounds.right < displayedBounds.left )
							continue ; // the el is left of the viewport, skip to the next
						else if ( elBounds.left > displayedBounds.right )
							break ; // the el is right of the viewport, next els are not relevant
					}
					
					var el:DisplayObject = _createElement( _dataProvider[i] ) ;
					el.addEventListener( MouseEvent.MOUSE_DOWN, onElementMouseDown ) ;
					el.addEventListener( MouseEvent.MOUSE_UP, onElementMouseUp ) ;
					el.y = elBounds.y ;
					el.x = elBounds.x ;
					_listContent.addChild( el ) ;
					_currentElements[i] = el ;
					
				}
				
			}
			
		}
		
		private function estimateContentBounds():Rectangle
		{
			
			var estBounds:Rectangle = new Rectangle( 0, 0, 0, 0 ) ;
			
			for ( var i:int = 0 ; i < _dataProvider.length ; ++i )
			{
				
				var elBounds:Rectangle = _getElementBounds( _dataProvider[i] ) ;
				if ( _orientation == SCROLL_LIST_ORIENTATION_VERTICAL )
				{
					estBounds.width = Math.max( elBounds.width, estBounds.width ) ;
					elBounds.y += estBounds.height ;
					estBounds.height += elBounds.height ;
				}
				else
				{
					estBounds.height = Math.max( elBounds.height, estBounds.height ) ;
					elBounds.x += estBounds.width ;
					estBounds.width += elBounds.width ;
				}
				_cacheElementsBounds.push( elBounds ) ;
				
			}
			
			return estBounds ;
			
		}
		
		private var _lastDownMousePos:Point = new Point(0, 0);
		private function onElementMouseDown(e:Event):void
		{
			
			_lastDownMousePos = new Point( this.mouseX, this.mouseY ) ;
			
		}
		
		private function onElementMouseUp(e:MouseEvent):void
		{
			
			// check if there was no significant delta Y between the down and the up
			// if so it's a click
			if (
				_orientation == SCROLL_LIST_ORIENTATION_VERTICAL && Math.abs(this.mouseY - _lastDownMousePos.y) < 10
				|| _orientation == SCROLL_LIST_ORIENTATION_HORIZONTAL && Math.abs(this.mouseX - _lastDownMousePos.x) < 10
			)
			{
				
				var element:DisplayObject = DisplayObject(e.currentTarget) ;
				var data:* = _currentElements.indexOf(element) > -1 ? _dataProvider[ _currentElements.indexOf(element) ] : null ;
				dispatchEvent( new ScrollListEvent( ScrollListEvent.CLICK, element, data ) ) ;
				
			}
			
		}
		
		// ---------------------------------------
		//  GETTERS AND SETTERS
		// ---------------------------------------
		
		public function get bounds():Rectangle
		{
			return _scrollController.containerViewport ;
		}
		
		public function set bounds(value:Rectangle):void
		{
			_scrollController.containerViewport = value ;
			redraw() ;
		}

		public function get dataProvider():Vector.<*>
		{
			return _dataProvider;
		}

		public function set dataProvider(value:Vector.<*>):void
		{
			
			for each ( var el:DisplayObject in _currentElements )
			{
				
				_listContent.removeChild( el ) ;
				_releaseElement( el ) ;
				
			}
			
			_dataProvider = value;
			
			_cacheElementsBounds = new <Rectangle>[] ;
			_currentElements = [] ;
			
			_cacheContentBounds = estimateContentBounds() ;
			
			_scrollController.setContentRect( _cacheContentBounds ) ;
			
			// if scroll is out of new bounds go to end
			if ( _orientation == SCROLL_LIST_ORIENTATION_VERTICAL )
			{
				if ( _scrollController.scrollPosition.y > _cacheContentBounds.height - _scrollController.containerViewport.height )
					_scrollController.scrollToBottom() ;
			}
			else
			{
				if ( _scrollController.scrollPosition.x > _cacheContentBounds.width - _scrollController.containerViewport.width )
					_scrollController.scrollToRight() ;
			}
			
			redraw() ;
			
		}
		
		public function get scrollController():ScrollController
		{
			
			return _scrollController ;
			
		}
		
	}
	
}