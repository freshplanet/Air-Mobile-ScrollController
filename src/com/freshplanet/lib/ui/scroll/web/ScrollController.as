package com.freshplanet.lib.ui.scroll.web
{
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.InteractiveObject;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	
	public class ScrollController
	{
		private var _content:DisplayObject;
		private var _container:DisplayObjectContainer;
		/** ViewPort in coordinates of the container. */
		private var _containerViewport:Rectangle;
		private var _scrollBarThumb:InteractiveObject;
		private var _scrollBarViewPort:Rectangle;
		
		/** ViewPort in coordinates of the content. */
		private var _contentViewport:Rectangle;
		
		/** Level in the screen stack. */
		private static var level:int = 0;
		
		public static const JS_SCROLLING_EVENT:String = "JSScrollingEvent";
		
		public function ScrollController():void{};
		
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// INTERFACE
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		/**
		 * Add a scroll controller
		 * @param content the display object that will be scrolled
		 * @param container the object containing the content
		 * @param containerViewPort mask for the content
		 * @param scrollBarThumb the thumb (clickable moving part) of the scrollbar
		 * @param scrollBarViewPort mask for the scrollbar
		 */
		public function addScrollControll(content:DisplayObject, container:DisplayObjectContainer, containerViewport:Rectangle, scrollBarThumb:InteractiveObject, scrollBarViewPort:Rectangle = null):void
		{
			_content = content;
			_container = container;
			_containerViewport = containerViewport.clone();
			_scrollBarThumb = scrollBarThumb;
			if(scrollBarViewPort == null)
				_scrollBarViewPort = containerViewport.clone();
			else
				_scrollBarViewPort = scrollBarViewPort.clone();
			
			// compute the viewport in the content coordinates
			var viewportTopLeft:Point = _content.globalToLocal( _container.localToGlobal( _containerViewport.topLeft ));
			var viewportBottomRight:Point = _content.globalToLocal( _container.localToGlobal( _containerViewport.bottomRight ));
			
			_contentViewport = new Rectangle( 0, 0, viewportBottomRight.x - viewportTopLeft.x, viewportBottomRight.y - viewportTopLeft.y );
			if(_contentViewport.height >= getContentHeight())
			{
				scrollBarThumb.visible = false;
				_content = null;
				_container = null;
				_containerViewport = null;
				_scrollBarThumb = null;
				_scrollBarViewPort = null;
				return;
			}
			scrollBarThumb.visible = true;
			scrollBarThumb.y = _scrollBarViewPort.y;
			_content.scrollRect = _contentViewport.clone();
			
			setupListeners();
			level++;
		}
		
		public function removeScrollControll():void
		{
			if(_content != null)
			{
				removeListeners();
				_content = null;
				_container = null;
				_containerViewport = null;
				_scrollBarThumb = null;
				_scrollBarViewPort = null;
				level--;
			}
		}
		
		/** Scroll to a specific position. Fraction should be between 0.0 and 1.0. */
		public function scrollTo(fraction:Number):void
		{
			if(_content != null)
			{
				fraction = fraction > 1.0 ? 1.0 : (fraction < 0.0 ? 0.0 : fraction);
				
				// bounds of the scrollbar
				var minY:Number = _scrollBarViewPort.y;
				var maxY:Number = _scrollBarViewPort.height - _scrollBarThumb.height + _scrollBarViewPort.y;
				
				// update scrollbar position
				_scrollBarThumb.y = maxY + (minY - maxY) * (1.0 - fraction);
				
				updateContentPositionFromScrollBar();
			}
		}
		
		public function getCurrentScrollPosition():Number
		{
			return _content != null ? _content.scrollRect.y : 0;
		}
		
		public function setCurrentScrollPosition(position:Number):void
		{
			if(_content == null)
				return;
			moveContentTo(position);
			updateScrollBarPositionFromContent();
		}
		
		public function getReversedScrollPosition():Number
		{
			return getContentHeight() - _content.scrollRect.y;
		}
		
		public function setReversedScrollPosition(position:Number):void
		{
			moveContentTo(getContentHeight() - position);
			updateScrollBarPositionFromContent();
		}
		
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// LISTENERS MANAGEMENT
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		private function setupListeners():void
		{
			if (_scrollBarThumb) _scrollBarThumb.addEventListener(MouseEvent.MOUSE_DOWN, onScrollBarThumbMouseDown);
			_container.stage.addEventListener(JS_SCROLLING_EVENT, handleMouseWheel, false, level);
		}
		
		private function removeListeners():void
		{
			_scrollBarThumb.removeEventListener(MouseEvent.MOUSE_DOWN, onScrollBarThumbMouseDown);
			_scrollBarThumb.removeEventListener(MouseEvent.MOUSE_UP, onScrollBarThumbMouseUp);
			_container.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onDragThumb);
			_container.stage.removeEventListener(JS_SCROLLING_EVENT, handleMouseWheel);
		}
		
		private function onScrollBarThumbMouseDown(event:MouseEvent):void
		{
			_scrollBarThumb.removeEventListener(MouseEvent.MOUSE_DOWN, onScrollBarThumbMouseDown);
			_container.stage.addEventListener(MouseEvent.MOUSE_UP, onScrollBarThumbMouseUp);
			_container.stage.addEventListener(MouseEvent.MOUSE_MOVE, onDragThumb);
			
			// stores the initial positions
			_firstTouchY = event.stageY;
			_initialScrollY = _scrollBarThumb.y;
		}
		
		private function onScrollBarThumbMouseUp(event:MouseEvent):void
		{
			_scrollBarThumb.addEventListener(MouseEvent.MOUSE_DOWN, onScrollBarThumbMouseDown);
			
			if (_container && _container.stage)
			{
				_container.stage.removeEventListener(MouseEvent.MOUSE_UP, onScrollBarThumbMouseUp);
				_container.stage.removeEventListener(MouseEvent.MOUSE_MOVE, onDragThumb);
			}
		}
		
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// UPDATE HANDLERS
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		private var _firstTouchY:Number;
		private var _initialScrollY:Number;
		private function onDragThumb(event:MouseEvent):void
		{
			var newTouchY:Number = event.stageY;
			var stageDeltaY:Number = newTouchY - _firstTouchY;
			
			// convert to scrollbar coordinates
			var deltaY:Number = _scrollBarThumb.globalToLocal( new Point( 0, stageDeltaY )).y - _scrollBarThumb.globalToLocal( new Point( 0, 0 )).y;
			
			moveScrollBarTo(_initialScrollY + deltaY);
			updateContentPositionFromScrollBar();
		}
		
		private function handleMouseWheel(event:MouseEvent):void {
			// arbitrary conversion of delta
			var atBound:Boolean = moveContentBy(-event.delta*6);
			updateScrollBarPositionFromContent();
			event.stopImmediatePropagation();
			if(!atBound)
				event.preventDefault();
		}
		
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// POSITION UPDATE
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// Scrollbar
		private function moveScrollBarTo(posY:Number):void
		{
			// bounds of the scrollbar
			var minY:Number = _scrollBarViewPort.y;
			var maxY:Number = _scrollBarViewPort.height - _scrollBarThumb.height + _scrollBarViewPort.y;
			
			// update scrollbar position
			_scrollBarThumb.y = posY > maxY ? maxY : (posY < minY ? minY:posY);
		}
		
		private function updateContentPositionFromScrollBar():void
		{
			// get the percent from the scrollbar position
			// percent = (val - min)/(max - min)
			var percent:Number = (_scrollBarThumb.y - _scrollBarViewPort.y) / ( _scrollBarViewPort.height - _scrollBarThumb.height );
			
			// bounds of the content
			var minY:Number = _contentViewport.y;
			var maxY:Number = _contentViewport.y - _contentViewport.height + getContentHeight();
			
			var newViewPort:Rectangle = _content.scrollRect.clone();
			newViewPort.y = maxY + (minY - maxY) * (1.0 - percent);
			
			// update content position
			_content.scrollRect = newViewPort;
		}
		
		private function moveContentTo(position:Number):void
		{
			// bounds of the content
			var minY:Number = _contentViewport.y;
			var maxY:Number = _contentViewport.y - _contentViewport.height + getContentHeight();
			
			var newViewPort:Rectangle = _content.scrollRect.clone();
			newViewPort.y = position > maxY ? maxY : (position < minY ? minY:position);
			
			// update content position
			_content.scrollRect = newViewPort;
		}
		
		// Mouse wheel
		private function moveContentBy(deltaY:Number):Boolean
		{
			// bounds of the content
			var minY:Number = _contentViewport.y;
			var maxY:Number = _contentViewport.y - _contentViewport.height + getContentHeight();
			
			var newViewPort:Rectangle = _content.scrollRect.clone();
			
			var atBound:Boolean = newViewPort.y == maxY || newViewPort.y == minY;
			
			var newY:Number = newViewPort.y + deltaY;
			newY = newY > maxY ? maxY : (newY < minY ? minY:newY);
			newViewPort.y = newY;
			
			// update content position
			_content.scrollRect = newViewPort;
			
			atBound = atBound && (newY == maxY || newY == minY);
			
			return atBound;
		}
		
		private function updateScrollBarPositionFromContent():void
		{
			// get the percent from the content position
			// percent = (val - min)/(max - min)
			var percent:Number = (_content.scrollRect.y - _contentViewport.y) / ( getContentHeight() - _contentViewport.height );
			
			// bounds of the scrollbar
			var minY:Number = _scrollBarViewPort.y;
			var maxY:Number = _scrollBarViewPort.height - _scrollBarThumb.height + _scrollBarViewPort.y;
			
			// update scrollbar position
			_scrollBarThumb.y = maxY + (minY - maxY) * (1.0 - percent);
		}
		
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		// UTIL
		////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		private function getContentHeight():Number
		{
			if (!_content.stage) return 0;
			
			var originalHeightOnStage:Number = _content.transform.pixelBounds.height;
			var originalHeightOnContent:Number = _content.globalToLocal( new Point( 0, originalHeightOnStage )).y - _content.globalToLocal( new Point( 0, 0 )).y;
			originalHeightOnContent += 20;
			// handle the browser zoom out which scales the pixelBounds
			originalHeightOnContent *= _content.stage.getChildAt(0).height/_content.stage.getChildAt(0).transform.pixelBounds.height;
			return originalHeightOnContent;
		}
	}
}