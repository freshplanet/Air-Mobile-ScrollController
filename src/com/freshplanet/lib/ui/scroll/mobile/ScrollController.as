package com.freshplanet.lib.ui.scroll.mobile
{
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.Shape;
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.MouseEvent;
	import flash.events.TimerEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.Timer;
	import flash.utils.getTimer;

	public class ScrollController extends EventDispatcher
	{
		// --------------------------------------------------------------------------------------//
		//																						 //
		// 									   CONSTANTS										 //
		// 																						 //
		// --------------------------------------------------------------------------------------//
		
		/**
		 * Event dispatched every time the scroll position changes.
		 * Read <code>scrollPosition</code> to know the current scroll position.
		 *
		 * @see #scrollPosition
		 */
		public static const SCROLL_POSITION_CHANGE : String = "ScrollPositionChange";
		
		/**
		 * Event dispatched every time the page changes.
		 * Read <code>currentPage</code> to know the current page.
		 *
		 * @see #currentPage
		 * @see #pagingEnabled
		 */
		public static const PAGE_CHANGE : String = "PageChange";
		
		// Toggle debug statements.
		private static const DEBUG : Boolean = false;
		
		// Scrolling parameters
		private static const SCROLLING_MIN_AMPLITUDE : Number = 1; // in pixels
		private static const SCROLLING_MIN_SPEED : Number = 0.01; // in pixels/ms
		private static const SCROLLING_MAX_SPEED : Number = 4; // in pixels/ms
		private static const FREE_SCROLLING_FRICTION_COEF : Number = 0.0015;
		private static const BOUNCING_FRICTION_COEF : Number = 3;
		private static const BOUNCING_SPRING_RATE : Number = 0.03;
		private static const BOUNCING_FINGER_SLOW_DOWN_COEF : Number = 0.5;
		private static const FORCED_ANIMATED_SCROLLING_MIN_DURATION : Number = 150; // in ms
		private static const FORCED_ANIMATED_SCROLLING_MAX_SPEED : Number = 8; // in pixels/ms
		
		// Scroll bars appearance
		private static const SCROLLBAR_THICKNESS : Number = 10;
		private static const SCROLLBAR_MIN_LENGTH_WHEN_FREE : Number = 100;
		private static const SCROLLBAR_MIN_LENGTH_WHEN_BOUNCING : Number = 10;
		private static const SCROLLBAR_CORNER_RADIUS : Number = 10;
		private static const SCROLLBAR_SIDE_MARGIN : Number = 2;
		private static const SCROLLBAR_COLOR : uint = 0x000000;
		private static const SCROLLBAR_ALPHA : Number = 0.5;
		private static const SCROLLBAR_FADEOUT_DELAY : Number = 250; // in ms
		
		
		// --------------------------------------------------------------------------------------//
		//																						 //
		// 									  PUBLIC API										 //
		// 																						 //
		// --------------------------------------------------------------------------------------//
		
		/** Indicate if scrolling is enabled in the vertical direction */
		public var verticalScrollingEnabled : Boolean = true;
		
		/** Indicate if scrolling is enabled in the horizontal direction */
		public var horizontalScrollingEnabled : Boolean = true;
		
		/**
		 * Indicate if the vertical scroll bar should be displayed.
		 * This has no effect if vertical scrolling is disabled.
		 */
		public var displayVerticalScrollbar : Boolean = true;
		
		/**
		 * Indicate if the horizontal scroll bar should be displayed.
		 * This has no effect if horizontal scrolling is disabled.
		 */
		public var displayHorizontalScrollbar : Boolean = true;
		
		/**
		 * Indicate if the scrolling should scroll only to integer increments
		 * of the viewport width (like iOS homepage).
		 */
		public var pagingEnabled : Boolean = false;
		
		/** The current scrolling page (in horizontal and vertical directions) */
		public var currentPage : Point = new Point();
		
		public function ScrollController()
		{
			super();
		}
		
		/**
		 * Add scroll logic to a given view.
		 *
		 * @param content The content that should be scrollable.
		 * @param container The container on which we will listen to mouse events.
		 * @param containerViewport A rectangle (in container coordinates) outside of which the
		 * content should be masked. The scroll bar will be displayed on the right side of the
		 * container viewport. If null, we default to the container bounds.
		 * @param contentRect A rectangle (in content coordinates) outside of which the scrolling
		 * shouldn't go. If null, the whole content will be scrollable.
		 * @param scaleRatio The scale ratio between the content and the container (scaleRatio > 0).
		 * Default: 1.
		 */
		public function addScrollControll( content : DisplayObject,
										   container : DisplayObjectContainer,
										   containerViewport : Rectangle = null,
										   contentRect : Rectangle = null,
										   scaleRatio : Number = 1) : void
		{
			if (scaleRatio > 0)
			{
				_scaleRatio = scaleRatio;
			}
			
			if (_content || _container)
			{
				trace("ScrollController Error - This controller is already in use.");
				return;
			}
			
			if (!content || !container)
			{
				trace("ScrollController Error - content and container can't be null.");
				return;
			}
			
			// Save the parameters
			_container = container;
			_content = content;
			_cachedContentBounds = null;
			
			// Setup content rect
			setContentRect(contentRect);
			
			// Setup container viewport
			this.containerViewport = containerViewport;
			
			// Initialize the scroll bars
			initScrollBars();
			
			// Start listening to touch events
			_container.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown, false, 0, true);
		}
		
		/** Remove scroll logic of this controller. */
		public function removeScrollControll() : void
		{
			if (_content)
				_content.scrollRect = null;
			
			if (_container)
			{
				_container.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
				_container.removeEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
				_container.removeEventListener(MouseEvent.MOUSE_OUT, onMouseOut);
				_container.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);
				_container.removeEventListener(Event.ENTER_FRAME, onEnterFrame);
				_container.mouseChildren = true;
			}
			
			scrollBarFadeOutTimer.removeEventListener(TimerEvent.TIMER_COMPLETE, onScrollBarFadeOutTimerComplete);
			
			if (_verticalScrollBar && _container && _container.contains(_verticalScrollBar))
				_container.removeChild(_verticalScrollBar);
			
			if (_horizontalScrollBar && _container && _container.contains(_horizontalScrollBar))
				_container.removeChild(_horizontalScrollBar);
			
			_content = null;
			_container = null;
			_verticalScrollBar = null;
			_horizontalScrollBar = null;
			
			_containerViewport = null;
			_contentRect = null;
		
			_forcedAnimatedScrolling = false;
			_scrollingLockedForPaging = false;
		}
		
		/**
		 * Scroll to the origin (top-left) of the scrollable area.
		 *
		 * @param animated If true, the scrolling will be animated at the maximum scrolling speed.
		 * If false, the scrolling will happen instantely.
		 *
		 * @see #scrollTo()
		 */
		public function scrollToOrigin( animated : Boolean = false ) : void
		{
			scrollTo(contentRect.topLeft, animated);
		}
		
		/**
		 * Scroll to the top of the scrollable area.
		 *
		 * @param animated If true, the scrolling will be animated at the maximum scrolling speed.
		 * If false, the scrolling will happen instantely.
		 *
		 * @see #scrollTo()
		 */
		public function scrollToTop( animated : Boolean = false ) : void
		{
			var newPosition:Point = new Point(scrollPosition.x, contentRect.top);
			scrollTo(newPosition, animated);
		}
		
		/**
		 * Scroll to the bottom of the scrollable area.
		 *
		 * @param animated If true, the scrolling will be animated at the maximum scrolling speed.
		 * If false, the scrolling will happen instantely.
		 *
		 * @see #scrollTo()
		 */
		public function scrollToBottom( animated : Boolean = false ) : void
		{
			_cachedContentBounds = null;
			var newPosition:Point = new Point(scrollPosition.x, contentRect.bottom - _content.scrollRect.height);
			scrollTo(newPosition, animated);
		}
		
		/**
		 * Scroll to the left of the scrollable area.
		 *
		 * @param animated If true, the scrolling will be animated at the maximum scrolling speed.
		 * If false, the scrolling will happen instantely.
		 *
		 * @see #scrollTo()
		 */
		public function scrollToLeft( animated : Boolean = false ) : void
		{
			var newPosition:Point = new Point(contentRect.left, scrollPosition.y);
			scrollTo(newPosition, animated);
		}
		
		/**
		 * Scroll to the right of the scrollable area.
		 *
		 * @param animated If true, the scrolling will be animated at the maximum scrolling speed.
		 * If false, the scrolling will happen instantely.
		 *
		 * @see #scrollTo()
		 */
		public function scrollToRight( animated : Boolean = false ) : void
		{
			var newPosition:Point = new Point(contentRect.right - _content.scrollRect.width, scrollPosition.y);
			scrollTo(newPosition, animated);
		}
		
		/**
		 * Scroll to a given position (in content coordinates).
		 *
		 * @param position A point representing the target scrolling position.
		 * @param animated If true, the scrolling will be animated at the maximum scrolling speed.
		 * If false, the scrolling will happen instantely.
		 *
		 * @see #scrollToTop()
		 */
		public function scrollTo( position : Point, animated : Boolean = false ) : void
		{
			if (animated)
			{
				_forcedAnimatedScrollingTarget = position;
				var forcedAnimatedScrollingSpeedX:Number = Math.min(FORCED_ANIMATED_SCROLLING_MAX_SPEED, Math.abs((position.x - scrollPosition.x) / FORCED_ANIMATED_SCROLLING_MIN_DURATION));
				var forcedAnimatedScrollingSpeedY:Number = Math.min(FORCED_ANIMATED_SCROLLING_MAX_SPEED, Math.abs((position.y - scrollPosition.y) / FORCED_ANIMATED_SCROLLING_MIN_DURATION));
				_forcedAnimatedScrollingSpeed = new Point(forcedAnimatedScrollingSpeedX, forcedAnimatedScrollingSpeedY);
				_forcedAnimatedScrolling = true;
				_timeOfLastFrame = getTimer();
				_container.addEventListener(Event.ENTER_FRAME, onEnterFrame, false, 0, true);
			}
			else if (_content && _content.scrollRect)
			{
				var scrollRect:Rectangle = _content.scrollRect;
				scrollRect.x = position.x;
				scrollRect.y = position.y;
				_content.scrollRect = scrollRect;
				_previousScrollPositions['t-1'] = _previousScrollPositions['t-2'] = scrollPosition;
				updateScrollBars();
			}
		}
		
		/** The current scroll position (in content coordinates). */
		public function get scrollPosition() : Point
		{
			return _content && _content.scrollRect ? _content.scrollRect.topLeft : new Point();
		}
		
		/** Indicates if the user is touching the scrolling area at the moment. */
		public function get touchingScreen() : Boolean
		{
			return _touchingScreen;
		}
		
		/** The current scrolling speed (in pixel/ms in content coordinates). */
		public function get speed() : Point
		{
			return _speed;
		}
		
		private var _cachedContentBounds:Rectangle = null;
		
		/** The initial bounds of the content in its own coordinates system. */
		public function get contentBounds() : Rectangle
		{
			if (!_content)
				return null;
			
			if (_cachedContentBounds)
				return _cachedContentBounds.clone();
			
			var originalWidthOnStage : Number = _content.transform.pixelBounds.width;
			var originalWidthOnContent : Number = _content.globalToLocal(new Point(originalWidthOnStage, 0)).x - _content.globalToLocal(new Point()).x;
			
			var originalHeightOnStage : Number = _content.transform.pixelBounds.height;
			var originalHeightOnContent : Number = _content.globalToLocal(new Point( 0, originalHeightOnStage)).y - _content.globalToLocal(new Point()).y;
			
			_cachedContentBounds = new Rectangle(0, 0, int(originalWidthOnContent), int(originalHeightOnContent));
			
			return _cachedContentBounds.clone();
		}
		
		/** A rectangle (in content coordinates) outside of which the scrolling won't go. */
		public function get contentRect() : Rectangle
		{
			if (!_content)
				return null;
			
			return _contentRect ? _contentRect : contentBounds;
		}
		
		/**
		 * Set the <code>contentRect</code> property.
		 *
		 * @param rect The desired scrollable area.
		 * @param animated If true, and the current scrolling position is out of the new rectangle,
		 * we will animate a scrolling movement to get back in the new rectangle. If false, the
		 * scrolling movement happens instantly.
		 */
		public function setContentRect( rect : Rectangle, animated : Boolean = false ) : void
		{
			// Content rect accept only integer values
			if (rect)
				_contentRect = new Rectangle(int(rect.x), int(rect.y), int(rect.width), int(rect.height));
			else
				_contentRect = null;
			
			
			_cachedContentBounds = null;
			
			// Content rect can't be smaller than viewport
			contentRect.width = Math.max(contentRect.width, containerViewport.width/_scaleRatio);
			contentRect.height = Math.max(contentRect.height, containerViewport.height/_scaleRatio);
			
			if (animated)
			{
				_timeOfLastFrame = getTimer();
				_container.addEventListener(Event.ENTER_FRAME, onEnterFrame, false, 0, true);
			}
			else
			{
				if (!contentRect.containsPoint(scrollPosition))
					scrollToOrigin();
			}
		}
		
		/** A rectangle (in container coordinates) outside of which the content is masked. */
		public function get containerViewport() : Rectangle
		{
			if (!_container)
				return null;
			
			if (!_containerViewport)
			{
				var bounds:Rectangle = _container.getBounds(_container);
				_containerViewport = new Rectangle(int(bounds.x), int(bounds.y), int(bounds.width), int(bounds.height));
			}
			
			return _containerViewport;
		}
		
		public function set containerViewport( viewport : Rectangle ) : void
		{
			var oldViewport:Rectangle = _containerViewport;
			
			_containerViewport = viewport ? viewport.clone() : null;
			
			// Content rect can't be smaller than viewport
			contentRect.width = Math.max(contentRect.width, containerViewport.width);
			contentRect.height = Math.max(contentRect.height, containerViewport.height);
			
			if (!_content.scrollRect || !containerViewport.equals(oldViewport))
			{
				// Update the scroll rect
				var topLeft:Point = _content.globalToLocal(_container.localToGlobal(containerViewport.topLeft));
				var bottomRight:Point = _content.globalToLocal(_container.localToGlobal(containerViewport.bottomRight));
				_content.scrollRect = new Rectangle(contentRect.x, contentRect.y, int(bottomRight.x-topLeft.x), int(bottomRight.y-topLeft.y));				
			}
		}
		
		
		public function pauseScrolling():void
		{
			if (_container)
			{
				_container.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
			}
		}
		
		public function resumeScrolling():void
		{
			if (_container)
			{
				_container.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown, false, 0, true);
			}
		}
		
		// --------------------------------------------------------------------------------------//
		//																						 //
		// 									  PRIVATE VARS										 //
		// 																						 //
		// --------------------------------------------------------------------------------------//
		
		// Managed objects
		private var _content : DisplayObject;
		private var _container : DisplayObjectContainer;
		
		// Scale ratio
		private var _scaleRatio : Number = 1;
		
		// Config rectangles
		private var _contentRect : Rectangle;
		private var _containerViewport : Rectangle;
		
		// Scroll bars
		private var _verticalScrollBar : Shape;
		private var _horizontalScrollBar : Shape;
		private var _scrollBarFadeOutTimer : Timer;
		
		// Flag indicating if the user is touching the screen
		private var _touchingScreen : Boolean = false;
		
		// Flag indicating that we receive a touch event between two frames, and that it has not
		// been processed yet.
		private var _pendingTouch : Boolean = false;
		
		// Last 2 finger positions (in stage coordinates)
		private var _previousFingerPosition : Point = new Point();
		private var _currentFingerPosition : Point = new Point();
		
		// Time-related vars
		private var _timeOfLastFrame : Number = 0;
		private var _timeOfLastMouseDown : Number = 0;
		
		// Current scrolling speed (in pixels/ms in content coordinates)
		private var _speed : Point = new Point();
		
		// Last 2 scrolling positions (in content coordinates)
		private var _previousScrollPositions : Object = { 't-1': new Point(), 't-2': new Point() };
		
		// Forced animated scrolling (cf. scrollTo())
		private var _forcedAnimatedScrolling : Boolean = false;
		private var _forcedAnimatedScrollingSpeed : Point = new Point();
		private var _forcedAnimatedScrollingTarget : Point = new Point();
		
		// Flag indicating if the scrolling is locked for paging purpose
		private var _scrollingLockedForPaging : Boolean = false;
		
		
		// --------------------------------------------------------------------------------------//
		//																						 //
		// 								  PRIVATE FUNCTIONS										 //
		// 																						 //
		// --------------------------------------------------------------------------------------//
		
		/** Create the scroll bars and add them to the display list */
		private function initScrollBars() : void
		{
			_verticalScrollBar = new Shape();
			_verticalScrollBar.cacheAsBitmap = true;
			_verticalScrollBar.alpha = 0;
			
			_horizontalScrollBar = new Shape();
			_horizontalScrollBar.cacheAsBitmap = true;
			_horizontalScrollBar.alpha = 0;
			
			updateScrollBars();
		}
		
		/** Redraw vertical scroll bar with a new length (can't use scaling because of the rounded corners) */
		private function set verticalScrollBarLength( value : Number ) : void
		{
			var currentAlpha:Number = _verticalScrollBar.alpha;
			_verticalScrollBar.transform = _content.transform;
			_verticalScrollBar.alpha = currentAlpha;
			_verticalScrollBar.graphics.clear();
			_verticalScrollBar.graphics.beginFill(SCROLLBAR_COLOR, SCROLLBAR_ALPHA);
			_verticalScrollBar.graphics.drawRoundRect(0, 0, SCROLLBAR_THICKNESS, value, SCROLLBAR_CORNER_RADIUS, SCROLLBAR_CORNER_RADIUS);
			_verticalScrollBar.graphics.endFill();
		}
		
		/** Redraw horizontal scroll bar with a new length (can't use scaling because of the rounded corners) */
		private function set horizontalScrollBarLength( value : Number ) : void
		{
			var currentAlpha:Number = _horizontalScrollBar.alpha;
			_horizontalScrollBar.transform = _content.transform;
			_horizontalScrollBar.alpha = currentAlpha;
			_horizontalScrollBar.graphics.clear();
			_horizontalScrollBar.graphics.beginFill(SCROLLBAR_COLOR, SCROLLBAR_ALPHA);
			_horizontalScrollBar.graphics.drawRoundRect(0, 0, value, SCROLLBAR_THICKNESS, SCROLLBAR_CORNER_RADIUS, SCROLLBAR_CORNER_RADIUS);
			_horizontalScrollBar.graphics.endFill();
		}
		
		/**
		 * Update the size and position of the scroll bars depending on the current state of the
		 * controller.
		 */
		private function updateScrollBars() : void
		{
			// Check if the scroll bars are on the display list. If not, add them.
			// We do it at every update because they are added on the container, which might clean its
			// children without us knowing.
			if (!_container.contains(_verticalScrollBar)) _container.addChild(_verticalScrollBar);
			if (!_container.contains(_horizontalScrollBar)) _container.addChild(_horizontalScrollBar);
			
			// We hide a scroll bar if one of the following is true:
			// - scrolling in this direction is disabled
			// - the scroll bar in this direction is disabled
			// - the content is smaller than the container in this direction
			_verticalScrollBar.visible = verticalScrollingEnabled && displayVerticalScrollbar && contentRect.height > _content.scrollRect.height;
			_horizontalScrollBar.visible = horizontalScrollingEnabled && displayHorizontalScrollbar && contentRect.width > _content.scrollRect.width;
			
			// If the content is smaller than the container in both directions, no need to continue
			if (!_verticalScrollBar.visible && !_horizontalScrollBar.visible) return;
			
			// Same as scrolling relative position, but constrained between 0 and 1 because the scroll bar
			// has to stay within the container viewport.
			var verticalScrollBarRelativePosition:Number = Math.min(1, Math.max(0, scrollingRelativePosition.y));
			var horizontalScrollBarRelativePosition:Number = Math.min(1, Math.max(0, scrollingRelativePosition.x));
			
			// Compute new scroll bars length
			var newVerticalScrollBarLength:Number = Math.max(SCROLLBAR_MIN_LENGTH_WHEN_FREE, _content.scrollRect.height * (_content.scrollRect.height / contentRect.height));
			var newHorizontalScrollBarLength:Number = Math.max(SCROLLBAR_MIN_LENGTH_WHEN_FREE, _content.scrollRect.width * (_content.scrollRect.width / contentRect.width));
			
			// Absolute number of pixels currently in the bounce areas (0 if we are not bouncing).
			// Used to reduce the height of the scroll bars when bouncing.
			var bounceAbsoluteSize:Point = new Point();
			if (bouncingAboveContent) bounceAbsoluteSize.y = _content.scrollRect.height * Math.abs(scrollingRelativePosition.y);
			else if (bouncingUnderContent) bounceAbsoluteSize.y = _content.scrollRect.height * (scrollingRelativePosition.y - 1);
			if (bouncingLeftFromContent) bounceAbsoluteSize.x = _content.scrollRect.width * Math.abs(scrollingRelativePosition.x);
			if (bouncingRightFromContent) bounceAbsoluteSize.x = _content.scrollRect.width * Math.abs(scrollingRelativePosition.x - 1);
			if (bounceAbsoluteSize.y) newVerticalScrollBarLength = Math.max(SCROLLBAR_MIN_LENGTH_WHEN_BOUNCING, newVerticalScrollBarLength - bounceAbsoluteSize.y);
			if (bounceAbsoluteSize.x) newHorizontalScrollBarLength = Math.max(SCROLLBAR_MIN_LENGTH_WHEN_BOUNCING, newHorizontalScrollBarLength - bounceAbsoluteSize.x);
			
			// Apply new scroll bars length (redraws the scroll bars)
			verticalScrollBarLength = newVerticalScrollBarLength;
			horizontalScrollBarLength = newHorizontalScrollBarLength;
			
			// Update scroll bars position
			_verticalScrollBar.x = containerViewport.right - _verticalScrollBar.width - SCROLLBAR_SIDE_MARGIN;
			_verticalScrollBar.y = _containerViewport.top + (_containerViewport.height - newVerticalScrollBarLength*_verticalScrollBar.scaleY) * verticalScrollBarRelativePosition;
			_horizontalScrollBar.x = _containerViewport.left + (_containerViewport.width - newHorizontalScrollBarLength*_horizontalScrollBar.scaleX) * horizontalScrollBarRelativePosition;
			_horizontalScrollBar.y = containerViewport.bottom - _horizontalScrollBar.height - SCROLLBAR_SIDE_MARGIN;
		}
		
		/**
		 * Timer used to fade out the scroll bar after a given delay when no scrolling is
		 * happening. When the speed reaches zero in the content area, the timer starts.
		 * When the timer fires, the fade out animation starts. If the user starts scrolling,
		 * the timer is reset.
		 */
		private function get scrollBarFadeOutTimer() : Timer
		{
			// Lazy creation
			if (!_scrollBarFadeOutTimer)
			{
				_scrollBarFadeOutTimer = new Timer(SCROLLBAR_FADEOUT_DELAY, 1);
				_scrollBarFadeOutTimer.addEventListener(TimerEvent.TIMER_COMPLETE, onScrollBarFadeOutTimerComplete, false, 0, true);
			}
			
			return _scrollBarFadeOutTimer;
		}
		
		/** Display the scroll bar and cancel any fade out animation. */
		private function showScrollBars() : void
		{
			if (!_verticalScrollBar || !_horizontalScrollBar)
				return;
			
			// Reset the fade out timer
			scrollBarFadeOutTimer.reset();
			
			// Stop the fade out action if started
			_verticalScrollBar.removeEventListener(Event.ENTER_FRAME, fadeOutScrollBar);
			_horizontalScrollBar.removeEventListener(Event.ENTER_FRAME, fadeOutScrollBar);
			
			// Show the scroll bars
			_verticalScrollBar.alpha = 1;
			_horizontalScrollBar.alpha = 1;
		}
		
		/**
		 * Start the fade out timer to hide the scroll bars after a given delay.
		 *
		 * @see #scrollBarFadeOutTimer()
		 */
		private function hideScrollBars() : void
		{
			if (!_verticalScrollBar || !_horizontalScrollBar)
				return;
			
			// Start the fade out timer
			scrollBarFadeOutTimer.start();
		}
		
		/**
		 * Scroll bar fade out animation. This function is called every frame while the scroll bars
		 * fade out.
		 */
		private function fadeOutScrollBar( event : Event ) : void
		{
			var scrollBar:Shape = event.target as Shape;
			if (!scrollBar) return;
			
			// Decrease the scroll bar alpha
			scrollBar.alpha = Math.max(0, scrollBar.alpha - 0.2);
			
			// Stop the fade out if finished
			if (scrollBar.alpha == 0) scrollBar.removeEventListener(Event.ENTER_FRAME, fadeOutScrollBar);
		}
		
		/** Set the current page and update the scrolling */
		private function setCurrentPage( page : Point, animated:Boolean = true ) : void
		{
			if (!page || contentRect == null) return;
			
			if (page.x != currentPage.x || page.y != currentPage.y)
			{
				currentPage = page;
				
				// Dispatch a change event
				dispatchEvent(new Event(PAGE_CHANGE));
			}
			
			// Scroll to the new page
			var targetX:Number = contentRect.left + currentPage.x * _content.scrollRect.width;
			var targetY:Number = contentRect.top + currentPage.y * _content.scrollRect.height;
			var target:Point = new Point(targetX, targetY);
			scrollTo(target, animated);
		}
		
		/**
		 * Follow the finger when touching the screen.
		 *
		 * @param deltaTime The time (in seconds) since the last frame
		 */
		private function manageFingerScrolling( deltaTime : Number ) : void
		{
			// DEBUG INFO
			if (DEBUG)
			{
				trace('---- Start managing finger scrolling');
			}
			
			// Compute the scrolling amplitude
			var delta:Point = _content.globalToLocal(_previousFingerPosition).subtract(_content.globalToLocal(_currentFingerPosition));
			if (!horizontalScrollingEnabled) delta.x = 0;
			if (!verticalScrollingEnabled) delta.y = 0;
			if (bouncingLeftFromContent || bouncingRightFromContent) delta.x *= BOUNCING_FINGER_SLOW_DOWN_COEF;
			if (bouncingAboveContent || bouncingUnderContent) delta.y *= BOUNCING_FINGER_SLOW_DOWN_COEF;
			
			// Apply the scrolling movement
			moveContentFromDelta(delta, deltaTime);
			
			// Save the finger position
			_previousFingerPosition = _currentFingerPosition;
			
			// Indicate that finger touch has been processed
			_pendingTouch = false;
			
			// DEBUG INFO
			if (DEBUG)
			{
				trace('------ _currentFingerPosition = ' + _currentFingerPosition + ' | speed = ' + speed + ' | delta = ' + delta + ' | deltaTime = ' + deltaTime);
				trace('---- Stop managing finger scrolling');
			}
		}
		
		/**
		 * Apply physics laws when scrolling freely.
		 *
		 * @param deltaTime The time (in seconds) since the last frame
		 */
		private function manageFreeScrolling( deltaTime : Number ) : void
		{
			// DEBUG INFO
			if (DEBUG)
			{
				trace('---- Start managing free scrolling');
			}
			
			// Physics without paging
			var f:Point = new Point();
			var k:Point = new Point();
			var x0:Number = 0;
			var y0:Number = 0;
			
			// Update the physics laws in X axis
			if (bouncingLeftFromContent || bouncingRightFromContent)
			{
				f.x = 3; // friction coefficient
				k.x = BOUNCING_SPRING_RATE; // spring rate
				x0 = bouncingLeftFromContent ? contentRect.left+10 : contentRect.right-_content.scrollRect.width-10; // spring origin
			}
			else
			{
				f.x = FREE_SCROLLING_FRICTION_COEF; // friction coefficient
				k.x = 0; // spring rate (no spring on content)
				x0 = 0; // spring origin (no spring on content)
			}
				
			// Update the physics laws in Y axis
			if (bouncingAboveContent || bouncingUnderContent)
			{
				f.y = 3; // friction coefficient
				k.y = BOUNCING_SPRING_RATE; // spring rate
				y0 = bouncingAboveContent ? contentRect.top+10 : contentRect.bottom-_content.scrollRect.height-10; // spring origin
			}
			else
			{
				f.y = FREE_SCROLLING_FRICTION_COEF; // friction coefficient
				k.y = 0; // spring rate (no spring on content)
				y0 = 0; // spring origin (no spring on content)
			}
			
			// Compute the new scrolling position after deltaTime.
			// The movement equation is one of a mobile moving on a plane surface with a friction coefficient, maybe attached to a spring (if in the bouncing area).
			// It is thus a second order differential equation: d2y/dt2 + f*dy/dt + k*(y-y0) = 0
			// Here we assume deltaTime is very short and thus discretize the equation and compute y based on y(t-1) and y(t-2).
			var x:Number = 1/(1/Math.pow(deltaTime,2)+f.x/deltaTime+k.x) * (_previousScrollPositions['t-1'].x*(f.x/deltaTime+2/Math.pow(deltaTime,2)) - _previousScrollPositions['t-2'].x/Math.pow(deltaTime,2) + k.x*x0);
			var y:Number = 1/(1/Math.pow(deltaTime,2)+f.y/deltaTime+k.y) * (_previousScrollPositions['t-1'].y*(f.y/deltaTime+2/Math.pow(deltaTime,2)) - _previousScrollPositions['t-2'].y/Math.pow(deltaTime,2) + k.y*y0);
			
			// When we go from the bouncing area to the content area, we force the position to be exactly on the top (or bottom) of the content area.
			// This prevents a vibration effect when the content is smaller than the screen (the elasticity would make the scroller go from one bouncing
			// area to the other). We then stop the movement completely.
			var stopAfter:Boolean = false;
			if (_previousScrollPositions['t-1'].x < contentRect.left && x > contentRect.left)
			{
				x = contentRect.left;
				stopAfter = true;
			}
			if (_previousScrollPositions['t-1'].x + _content.scrollRect.width > contentRect.right && x + _content.scrollRect.width < contentRect.right)
			{
				x = contentRect.right - _content.scrollRect.width;
				stopAfter = true;
			}
			if (_previousScrollPositions['t-1'].y < contentRect.top && y > contentRect.top)
			{
				y = contentRect.top;
				stopAfter = true;
			}
			if (_previousScrollPositions['t-1'].y + _content.scrollRect.height > contentRect.bottom && y + _content.scrollRect.height < contentRect.bottom)
			{
				y = contentRect.bottom - _content.scrollRect.height;
				stopAfter = true;
			}
			
			// Apply the movement
			var delta:Point = new Point(x-_content.scrollRect.x, y-_content.scrollRect.y);
			moveContentFromDelta(delta, deltaTime, SCROLLING_MAX_SPEED, SCROLLING_MAX_SPEED, stopAfter);
			
			// DEBUG INFO
			if (DEBUG)
			{
				trace('------ speed = ' + speed + ' | delta = ' + delta + ' | deltaTime = ' + deltaTime);
				trace('---- Stop managing free scrolling');
			}
		}
		
		/**
		 * Manage the forced animated scrolling.
		 *
		 * @param deltaTime The time (in seconds) since the last frame
		 *
		 * @see #scrollTo()
		 */
		private function manageForcedAnimatedScrolling( deltaTime : Number ) : void
		{
			// DEBUG INFO
			if (DEBUG)
			{
				trace('---- Start managing forced animated scrolling');
			}
			
			// Compute the total distance remaining and let moveContentFromDelta()'s speed control
			// do the job.
			var delta:Point = _forcedAnimatedScrollingTarget.subtract(scrollPosition);
			
			if (!delta.x && !delta.y)
			{
				stopMovement();
				_forcedAnimatedScrolling = false;
			}
			else
			{
				// If the delta makes us go in the bounce area, we limit it and then stop the movement
				var stopAfter:Boolean = false;
				if (_previousScrollPositions['t-1'].x > contentRect.left && scrollPosition.x + delta.x < contentRect.left)
				{
					delta.x = contentRect.left - scrollPosition.x;
					stopAfter = true;
				}
				if (_previousScrollPositions['t-1'].x + _content.scrollRect.width < contentRect.right && scrollPosition.x + delta.x + _content.scrollRect.width > contentRect.right)
				{
					delta.x = contentRect.right - _content.scrollRect.width - scrollPosition.x;
					stopAfter = true;
				}
				if (_previousScrollPositions['t-1'].y > contentRect.top && scrollPosition.y + delta.y < contentRect.top)
				{
					delta.y = contentRect.top - scrollPosition.y;
					stopAfter = true;
				}
				if (_previousScrollPositions['t-1'].y + _content.scrollRect.height < contentRect.bottom && scrollPosition.y + delta.y + _content.scrollRect.height > contentRect.bottom)
				{
					delta.y = contentRect.bottom - _content.scrollRect.height - scrollPosition.y;
					stopAfter = true;
				}
				
				
				moveContentFromDelta(delta, deltaTime, _forcedAnimatedScrollingSpeed.x, _forcedAnimatedScrollingSpeed.y, stopAfter);
			}
			
			// DEBUG INFO
			if (DEBUG)
			{
				trace('------ target = ' + _forcedAnimatedScrollingTarget + ' | speed = ' + speed + ' | delta = ' + delta + ' | deltaTime = ' + deltaTime);
				trace('---- Stop managing forced animated scrolling');
			}
		}
		
		/**
		 * Manage the paging behavior right after the user remove his finger from the screen.
		 *
		 * @see #pagingEnabled
		 */
		private function managePaging() : void
		{
			if (pagingEnabled && scrollingWithinContentArea && !_scrollingLockedForPaging)
			{
				_scrollingLockedForPaging = true;
				
				var pageX:int = Math.floor((scrollPosition.x - contentRect.left + _content.scrollRect.width/2) / _content.scrollRect.width);
				var pageY:int = Math.floor((scrollPosition.y - contentRect.top + _content.scrollRect.height/2) / _content.scrollRect.height);
				if (_speed.x > 0 && pageX == currentPage.x) pageX += 1;
				else if (_speed.x < 0 && pageX == currentPage.x) pageX -= 1;
				if (_speed.y > 0 && pageY == currentPage.y) pageY += 1;
				else if (_speed.y < 0 && pageY == currentPage.y) pageY -= 1;
				
				setCurrentPage(new Point(pageX, pageY));
				
				return;
			}
		}
		
		/**
		 * Scroll the content from a given distance.
		 *
		 * @param delta The scrolling distance in pixels in the content coordinates.
		 * @param deltaTime The time interval corresponding to this movement (used to compute the current speed).
		 */
		private function moveContentFromDelta( delta : Point, deltaTime : Number, maxSpeedX : Number = SCROLLING_MAX_SPEED, maxSpeedY : Number = SCROLLING_MAX_SPEED, stopAfter : Boolean = false ) : void
		{
			
			// Avoid unintended tiny movement on single tap
			// We except the case where it brings the scrolling to the edges of the scrollable area
			// in order not to get stuck at the border of the bouncing area (and have the scroll bar not
			// disappearing. Also we except the forced animated scrolling
			if (Math.abs(delta.x) < SCROLLING_MIN_AMPLITUDE && (scrollPosition.x + delta.x) != contentRect.left && (scrollPosition.x + delta.x) != (contentRect.right - _content.scrollRect.width) && !_forcedAnimatedScrolling)
				delta.x = 0;
			if (Math.abs(delta.y) < SCROLLING_MIN_AMPLITUDE && (scrollPosition.y + delta.y) != contentRect.top && (scrollPosition.y + delta.y) != (contentRect.bottom - _content.scrollRect.height) && !_forcedAnimatedScrolling)
				delta.y = 0;
			
			// Limit the instant speed
			if (Math.abs(delta.x/deltaTime) > maxSpeedX)
				delta.x = delta.x/Math.abs(delta.x)*maxSpeedX*deltaTime;
			if (Math.abs(delta.y/deltaTime) > maxSpeedY)
				delta.y = delta.y/Math.abs(delta.y)*maxSpeedY*deltaTime;
			
			// Show the scroll bar if the movement is initiated by finger
			if ((delta.x || delta.y) && _touchingScreen)
				showScrollBars();
			
			// Update the scroll rect
			var scrollRect : Rectangle = _content.scrollRect.clone();
			scrollRect.x += delta.x;
			scrollRect.y += delta.y;
			if (delta.x || delta.y)
			{
				_content.scrollRect = scrollRect;
			}
			
			// Compute the speed and trajectory, or stop the movement if necessary
			if (stopAfter)
			{
				stopMovement();
			}
			else
			{
				// Compute the speed
				var currentSpeedX:Number = 0.5*(delta.x/deltaTime+_speed.x);
				if (Math.abs(currentSpeedX) < SCROLLING_MIN_SPEED) currentSpeedX = 0;
				var currentSpeedY:Number = 0.5*(delta.y/deltaTime+_speed.y);
				if (Math.abs(currentSpeedY) < SCROLLING_MIN_SPEED) currentSpeedY = 0;
				_speed = new Point(currentSpeedX, currentSpeedY);
				
				_movementStopped = (_speed.y == 0.0);
				
				// Save the trajectory
				_previousScrollPositions['t-2'] = _previousScrollPositions['t-1'];
				_previousScrollPositions['t-1'] = new Point(scrollRect.x, scrollRect.y);
			}
			
			// Update the scroll bars
			updateScrollBars();
			
			// Send an update event if the position has changed
			if (delta.x || delta.y)
			{
				var event:Event = new Event(SCROLL_POSITION_CHANGE);
				dispatchEvent(event);
			}
		}
		
		private var _movementStopped:Boolean = false;
		
		public function get movementStopped():Boolean
		{
			return _movementStopped;
		}
		
		/**
		 * Completely stop the movement.
		 */
		private function stopMovement() : void
		{
			_movementStopped = true;
			_previousScrollPositions['t-2'] = _previousScrollPositions['t-1'] = scrollPosition;
			_speed = new Point();
		}
		
		/**
		 * The current relative scrolling position. Values (x,y) are:
		 * <ul>
		 * 	<li>negative if bouncing above or left from the content area</li>
		 * 	<li>between 0 and 1 if scrolling within the content area</li>
		 * 	<li>greater than 1 if bouncing under or right from the content area</li>
		 * </ul>
		 */
		private function get scrollingRelativePosition() : Point
		{
			// When the content is smaller than the viewport, we choose arbitrary values
			// to obtain the desired behavior.
			var result:Point = new Point();
			
			if (contentRect.width > _content.scrollRect.width)
				result.x = (scrollPosition.x - contentRect.left) / (contentRect.width - _content.scrollRect.width);
			else if (scrollPosition.x == contentRect.left)
				result.x = 0;
			else if (scrollPosition.x < contentRect.left)
				result.x = -1;
			else
				result.x = 2;
			
			if (contentRect.height > _content.scrollRect.height)
				result.y = (scrollPosition.y - contentRect.top) / (contentRect.height - _content.scrollRect.height);
			else if (scrollPosition.y == contentRect.top)
				result.y = 0;
			else if (scrollPosition.y < contentRect.top)
				result.y = -1;
			else
				result.y = 2;
			
			return result;
		}
		
		/** Indicate if the scrolling position is within the content area. */
		private function get scrollingWithinContentArea() : Boolean
		{
			return scrollingRelativePosition.x >= 0 && scrollingRelativePosition.x <= 1 && scrollingRelativePosition.y >= 0 && scrollingRelativePosition.y <= 1;
		}
		
		/** Indicate if the scrolling position is in the left bouncing area. */
		private function get bouncingLeftFromContent() : Boolean
		{
			return scrollingRelativePosition.x < 0;
		}
		
		/** Indicate if the scrolling position is in the right bouncing area. */
		private function get bouncingRightFromContent() : Boolean
		{
			return scrollingRelativePosition.x > 1;
		}
		
		/** Indicate if the scrolling position is in the top bouncing area. */
		private function get bouncingAboveContent() : Boolean
		{
			return scrollingRelativePosition.y < 0;
		}
		
		/** Indicate if the scrolling position is in the bottom bouncing area. */
		private function get bouncingUnderContent() : Boolean
		{
			return scrollingRelativePosition.y > 1;
		}
		
		
		// --------------------------------------------------------------------------------------//
		//																						 //
		// 								PRIVATE EVENT LISTENERS									 //
		// 																						 //
		// --------------------------------------------------------------------------------------//
		
		
		private function onMouseDown( event : MouseEvent ) : void
		{
			// If the scrolling is locked by the paging feature, ignore the touch
			if (_scrollingLockedForPaging)
			{
				if (DEBUG)
				{
					trace('>> onMouseDown - scrollingLockedForPaging ', "returning...");
				}
				return;
			}
			
			// The user starts touching the screen
			_touchingScreen = true;
			_timeOfLastMouseDown = getTimer();
			
			// Update finger position
			_previousFingerPosition = new Point(event.stageX, event.stageY);
			_currentFingerPosition = _previousFingerPosition;
			
			// Start listening to touch and frame events
			_container.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove, false, 0, true);
			_container.addEventListener(MouseEvent.MOUSE_OUT, onMouseOut, false, 0, true);
			_container.addEventListener(MouseEvent.MOUSE_UP, onMouseUp, false, 0, true);
			_container.addEventListener(Event.ENTER_FRAME, onEnterFrame, false, 0, true);
			
			// DEBUG INFO
			if (DEBUG)
			{
				trace('>> onMouseDown - _currentFingerPosition = ' + _currentFingerPosition);
			}
		}
		
		private function onMouseUp( event : MouseEvent ) : void
		{
			// The user stops touching the screen
			_touchingScreen = false;
			
			// Stop listening to touch events
			_container.removeEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
			_container.removeEventListener(MouseEvent.MOUSE_OUT, onMouseOut);
			_container.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);
			
			// If we get a mouse down and a mouse up between two frames, we need to either stop the scrolling,
			// either update the speed.
			if (_timeOfLastMouseDown > _timeOfLastFrame)
			{
				if (_currentFingerPosition.equals(new Point(event.stageX, event.stageY)))
				{
					stopMovement();
				}
				else
				{
					onEnterFrame(null);
				}
			}
			
			// If the paging is enabled, now is the time to check if we're in between two pages
			if (pagingEnabled)
			{
				_pendingTouch = false;
				managePaging();
			}
			
			// DEBUG INFO
			if (DEBUG)
			{
				trace('<< onMouseUp - _currentFingerPosition = ' + _currentFingerPosition);
			}
		}
		
		private function onMouseOut( event : MouseEvent ) : void
		{
			// If it was a mouse out outside of the container, we consider it as a mouse up
			if (!_container.getBounds(_container.stage).contains(event.stageX, event.stageY))
				onMouseUp(event);
		}
		
		private function onMouseMove( event : MouseEvent) : void
		{
			// Indicate we received a touch and it hasn't been processed yet
			_pendingTouch = true;
			
			// Update finger position
			_currentFingerPosition = new Point(event.stageX, event.stageY);
			
			// DEBUG INFO
			if (DEBUG)
			{
				trace('xx onMouseMove - currentFingerPosition = ' + _currentFingerPosition);
			}
		}
		
		private function onEnterFrame( event : Event ) : void
		{
			// DEBUG INFO
			if (DEBUG)
			{
				trace('-- onEnterFrame | speed = ' + speed);
			}
			
			// If content scroll rect not ready, can't do anything
			if (!_content.scrollRect)
				return;
			
			// Update time information (if deltaTime == 0, we wait for the next frame)
			var deltaTime:Number = getTimer() - _timeOfLastFrame;
			if (deltaTime == 0) return;
			_timeOfLastFrame += deltaTime;
			
			// If a forced animated scrolling was requested, we perform it.
			// Otherwise, if the user is touching the screen, or if we haven't processed the last touch yet, we follow the finger.
			// Otherwise, we let the physics take care of the scrolling.
			if (_forcedAnimatedScrolling)
				manageForcedAnimatedScrolling(deltaTime)
			else if (_touchingScreen || _pendingTouch)
				manageFingerScrolling(deltaTime)
			else
				manageFreeScrolling(deltaTime);
			
			// If we are in the scrolling area, not touching the screen, not forcing an animation,
			// and with no speed, we can stop refreshing the display and fade out the scroll bars.
			if (!_forcedAnimatedScrolling && !_touchingScreen && scrollingWithinContentArea && speed.x == 0 && speed.y == 0)
			{
				_scrollingLockedForPaging = false;
				_container.removeEventListener(Event.ENTER_FRAME, onEnterFrame);
				hideScrollBars();
			}
			
			// If we are moving, we don't transmit mouse events to children
			_container.mouseChildren = (speed.x == 0 && speed.y == 0);
			
			// DEBUG INFO
			if (DEBUG)
			{
				trace('-- onExitFrame');
			}
		}
		
		private function onScrollBarFadeOutTimerComplete( event : TimerEvent ) : void
		{
			if(_verticalScrollBar)
				_verticalScrollBar.addEventListener(Event.ENTER_FRAME, fadeOutScrollBar, false, 0, true);
			
			if (_horizontalScrollBar)
				_horizontalScrollBar.addEventListener(Event.ENTER_FRAME, fadeOutScrollBar, false, 0, true);
		};
		
		/**
		 * Scroll to a certain page.
		 *
		 * This method will take care of translating between a certain page number
		 * and the position it has to move across.
		 *
		 * @param position
		 *
		 */
		public function scrollToPage(position:int, animated:Boolean = true):void
		{
			var p : Point;
			if (horizontalScrollingEnabled && !verticalScrollingEnabled) {
				p = new Point( position, currentPage.y  );
			} else if (!horizontalScrollingEnabled && verticalScrollingEnabled) {
				p = new Point( currentPage.x, position  );
			}
			setCurrentPage(p, animated);
		}
	}
}
