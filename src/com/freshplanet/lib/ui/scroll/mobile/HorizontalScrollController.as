package com.freshplanet.lib.ui.scroll.mobile
{
	import flash.display.DisplayObject;
	import flash.display.DisplayObjectContainer;
	import flash.display.Shape;
	import flash.events.Event;
	import flash.events.MouseEvent;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.utils.getTimer;
	
	public class HorizontalScrollController
	{
		
		
		// ------------------------------------------------------------------------------------------
		//
		// Static Vars
		// 
		// ------------------------------------------------------------------------------------------
		
		public static var FRICTION_COEFFICIENT:Number = 0.9;
		public static var MAX_SPEED_ALLOWED_WHEN_BOUNCING:Number = 0.5;
		public static var MAX_SPEED_ALLOWED_WHEN_RUNNING_FREE:Number = 2.0;
		public static var SPEED_REDUCTION_WHEN_BOUNCING:Number = 0.3;
		public static var SCROLLBAR_FIRST_POSITION:Number = 0;
		
		// ------------------------------------------------------------------------------------------
		//
		// Private Vars
		// 
		// ------------------------------------------------------------------------------------------
		
		// state 
		private var _paused : Boolean = true;
		
		// config scroll
		private var _content : DisplayObject;
		private var _container : DisplayObjectContainer;
		
		private var _contentViewport : Rectangle;
		private var _containerViewport : Rectangle;
		
		private var _contentInitialBounds : Rectangle; // full size of the content before we put it in the scroll Rect, don't seem to be able to find it after so cache it here
		
		// scroll movement cache
		private var _lastTouch : Object;
		private var _touches : Vector.<Object>;
		private var _trajectories : Vector.<Object>;
		private var _touchesCleanup:Boolean = false; // do we need to clean _touches after processing them this frame ?
		
		public function HorizontalScrollController() {}
		
		private function addTouch( event : MouseEvent ) : void
		{
			if ( !_touches )
				_touches = new Vector.<Object>();
			
			var time : Number = getTimer();
			this._touches.push( { 'time' : time, 'stageX' : event.stageX } );
			
		}
		
		/**
		 * trajectory are in y in coordinate of content and represent the scrollRect.y over frames
		 */
		private function addTrajectory( currentX : Number, time : Number = 0 ) : void
		{
			if ( !_trajectories )
				_trajectories = new Vector.<Object>();
			
			var trajectoryTime : Number = time != 0 ? time : getTimer();
			this._trajectories.push( { 'time' : trajectoryTime, 'localX' : currentX } );
			
		}
		
		private function getDeltaTime() : Number
		{
			if ( _trajectories != null && _trajectories.length != 0 )
				return getTimer() - _trajectories[_trajectories.length - 1]['time'];
			else 
				return 1000 / 24; // 1 frame in ms
		}
		
		private function getContentWidth() :  Number
		{
			var originalWidthOnStage : Number = _content.transform.pixelBounds.width;
			var originalWidthOnContent : Number = _content.globalToLocal( new Point( originalWidthOnStage, 0 )).x - _content.globalToLocal( new Point( 0, 0 )).x;
			return originalWidthOnContent + 10; // margin bottom (!!!!! warning, drawDebug messup this function)
		}
		
		private function processTouchInteraction( touch : Object ) : void
		{
			if ( touch == null || touch == _lastTouch )
				return;
			
			var deltaX : int = 0;
			var coef : Number; // how much do we follow touch movement, 1 = we follow completelly
			
			if ( ( _content.scrollRect.x + _contentViewport.width <  this.getContentWidth() )  && _contentViewport.left < _content.scrollRect.x ) // if inside scroll area
			{
				//trace( 'scrolling from interaction inside area' );
				coef = 1;
			}
			else // if outside
			{
				//trace( 'scrolling from interaction outside area' );
				coef = 0.3;
			}
			
			var stageDeltaX : int = _lastTouch['stageX'] - touch['stageX']; // delta in event position y in stage space
			var contentDeltaX : int = _content.globalToLocal( new Point( stageDeltaX, 0 )).x - _content.globalToLocal( new Point( 0, 0 )).x;
			
			deltaX = contentDeltaX * coef;
			
			_lastTouch = touch;
			
			moveContentFromDelta( deltaX, touch['time'] );
		}
		
		
		private function moveContentFromDelta( deltaX : Number, time : Number = 0 ) : void
		{
			var newScrollRect : Rectangle = _content.scrollRect.clone();
			newScrollRect.x += deltaX;
			_content.scrollRect = newScrollRect;
			this.addTrajectory( newScrollRect.x, time );
		}
		
		
		
		// ------------------------------------------------------------------------------------------
		//
		// Private Event Handler
		// 
		// ------------------------------------------------------------------------------------------
		
		private function mouseDownHandler( event : MouseEvent ) : void
		{
			hasTouchContainer = true;
			this.addTouch( event );
			_container.addEventListener( MouseEvent.MOUSE_MOVE, onMoveDrag, false, 0, true );
			_container.addEventListener( MouseEvent.MOUSE_UP, onStopDrag, false, 0, true );
			_container.addEventListener( Event.ENTER_FRAME, onEnterFrame, false, 0, true );
			
		}
		
		private function onMoveDrag( event : MouseEvent ) : void
		{
			addTouch( event );
			_container.addEventListener( Event.ENTER_FRAME, onEnterFrame, false, 0, true ); // we re-add it because we may demove it since we stopped moving for a while and restart
		}
		
		private function onStopDrag( event : MouseEvent ) : void
		{
			_container.removeEventListener( MouseEvent.MOUSE_MOVE, onMoveDrag );
			_container.removeEventListener( MouseEvent.MOUSE_UP, onStopDrag );
			_touchesCleanup = true;
		}
		
		private function onContentResize( event : Event ) : void
		{
			if ( _contentViewport.width >= this.getContentWidth() )
				pause();
			else
			{
				if (_paused)
				{
					var newViewPort:Rectangle = _contentViewport.clone();
					//newViewPort.x += SCROLLBAR_FIRST_POSITION;
					_content.scrollRect = newViewPort;
					//resume();
				}
			}
		}
		
		
		private function onEnterFrame( event : Event ) : void
		{
			if (_content.scrollRect == null)
			{
				return;
			}
			
			// setting up first touch
			if ( _lastTouch == null && _touches && _touches.length != 0 )
			{
				//trace( 'first touch' );
				_lastTouch = _touches[0];
				
				this.addTrajectory( _content.scrollRect.x, _lastTouch['time'] );
				
				if ( _touches.length == 1)
					return;
				// no return otherwise, can be different from current touch, sometimes we get several touch per frame
			}
			
			var pendingTouches : Vector.<Object>;
			
			if ( _touches && _touches.length != 0 && _touches.indexOf( _lastTouch ) != _touches.length - 1 )
			{
				pendingTouches = _touches.slice( _touches.indexOf( _lastTouch ) + 1 );
				//trace( 'pending touches lenght =', pendingTouches.length );
			}
			
			
			var deltaX : int = 0;
			var stopAfterThisOne : Boolean = false;
			
			if ( pendingTouches ) // there is new touches
			{
				//trace( 'onEnterFrame with interaction' );
				
				// if so for each pending touch, process them and add them to the trajectory
				for each ( var touch : Object in pendingTouches )
				{
					this.processTouchInteraction( touch );
				}
			}
			else
			{
				//trace( 'no interaction this frame' );
				var currentSpeed : Number = this.getLastSpeed();
				
				if ( ( _content.scrollRect.x + _contentViewport.width <  this.getContentWidth() )  && _contentViewport.left < _content.scrollRect.x ) // if inside scroll area
				{
					//trace( 'scrolling freely inside area' );
					if ( currentSpeed )
					{
						currentSpeed = currentSpeed * Math.min( MAX_SPEED_ALLOWED_WHEN_RUNNING_FREE, Math.abs( currentSpeed )) / Math.abs( currentSpeed ); // current speed maxed out at twice what's possible when boncing
						//trace( 'currentSpeed =', currentSpeed );
						deltaX = currentSpeed * FRICTION_COEFFICIENT * this.getDeltaTime(); // friction
					}
					else
						deltaX = 0; // because when blocking free move with click, there is not trajectories so no speed yet
					
					var absDeltaX:Number = deltaX > 0 ? deltaX : -deltaX;
					if ( absDeltaX < 2 ) // Math.abs( deltaX ) < 2
					{
						//trace( 'natural scroll too slow, stopping interaction now' );
						stopAfterThisOne = true;
					}
				}
				else // if outside
				{
					//trace( 'scrolling freely outside area' );
					// get closer to border at constant speed linear from initial delta
					var v : Number;
					// if on top
					if ( _contentViewport.left >= _content.scrollRect.x )
					{
						//trace( 'on top' );
						
						// var v : Number = currentSpeed - 0.0001 * ( _content.scrollRect.y - _contentViewport.top ) * this.getDeltaTime(); // speed
						v = -MAX_SPEED_ALLOWED_WHEN_BOUNCING > currentSpeed + SPEED_REDUCTION_WHEN_BOUNCING ?  -MAX_SPEED_ALLOWED_WHEN_BOUNCING : currentSpeed + SPEED_REDUCTION_WHEN_BOUNCING  //Math.max( -MAX_SPEED_ALLOWED_WHEN_BOUNCING, currentSpeed + SPEED_REDUCTION_WHEN_BOUNCING );
						//trace( 'v =', v );
						deltaX = v * this.getDeltaTime();
						
						if ( deltaX > _contentViewport.left - _content.scrollRect.x  ) // going back to scrolling freeling inside area, we want to stop
						{
							//trace('going back to free after this one, time to stop');
							deltaX = _contentViewport.left - _content.scrollRect.x;
							stopAfterThisOne = true;
						}
					}
					else
					{
						//trace( 'on bottom' );
						
						//var v : Number = currentSpeed - 0.0001 * ( (_content.scrollRect.y + _contentViewport.height) - this.getContentHeight() ) * this.getDeltaTime(); // speed
						v = MAX_SPEED_ALLOWED_WHEN_BOUNCING < currentSpeed - SPEED_REDUCTION_WHEN_BOUNCING ? MAX_SPEED_ALLOWED_WHEN_BOUNCING : currentSpeed - SPEED_REDUCTION_WHEN_BOUNCING// Math.min( MAX_SPEED_ALLOWED_WHEN_BOUNCING, currentSpeed - SPEED_REDUCTION_WHEN_BOUNCING );
						//trace( 'v =', v );
						deltaX = v * this.getDeltaTime();
						
						if ( deltaX < this.getContentWidth() - (_content.scrollRect.x + _contentViewport.width)  ) // going back to scrolling freeling inside area, we want to stop
						{
							//trace('going back to free after this one, time to stop');
							deltaX = this.getContentWidth() - (_content.scrollRect.x + _contentViewport.width);
							stopAfterThisOne = true;
						}
					}
				}
			}
			
			if ( deltaX != 0 )
			{
				this.moveContentFromDelta( deltaX );
			}
			
			if ( stopAfterThisOne )
			{
				//trace( 'stopAfterThisOne' );
				_container.removeEventListener( Event.ENTER_FRAME, onEnterFrame );
				//trace('remove onEnterFrame');
				
				var last : Object = _trajectories[ _trajectories.length - 1];
				this._trajectories = new Vector.<Object>;
				_trajectories.push( last ); // keep last one
			}
			
			if ( _touchesCleanup )
			{
				//trace( 'touches cleanup' );
				_touchesCleanup = false;
				_touches = null;
				_lastTouch = null;
			}
			
			
			//trace( '\\ exit onEnterFrame -----------------------------------------------------------' );
		}
		
		
		
		
		// ------------------------------------------------------------------------------------------
		//
		// Public API
		// 
		// ------------------------------------------------------------------------------------------
		
		/**
		 * add scroll logic for this content, in this container, displayed in this viewport area 
		 * @param content stuff to scroll
		 * @param container We will listen the mouse event on this guy
		 * @param containerViewPort we will mask the content outside the viewport
		 * 
		 */
		public function addScrollControll( content : DisplayObject, container : DisplayObjectContainer, containerViewPort : Rectangle ) : void
		{
			if ( _content != null || _container != null )
				throw new Error( "This Scroll Controller Already manage some content and container, find another one for you!" );
			
			if ( content == null || container == null )
				throw new Error( "Content or Container are null, I cannot manage that!" );
			
			if ( containerViewPort == null || containerViewPort.width == 0 || containerViewPort.height == 0 )
				throw new Error( "Incorrect viewport information, what do you really want to see ? viewport = " + containerViewPort.toString() );
			
			_container = container;
			_content = content;
			
			_containerViewport = containerViewPort.clone(); // don't touch my viewport
			
			var viewportTopLeft : Point = _content.globalToLocal( _container.localToGlobal( containerViewPort.topLeft ));
			var viewportBottomRight : Point = _content.globalToLocal( _container.localToGlobal( containerViewPort.bottomRight ));
			
			
			_contentViewport = new Rectangle( 0, 0, viewportBottomRight.x - viewportTopLeft.x, viewportBottomRight.y ); // we want viewport in content coords too
			
			//trace('y position', _content.y, _contentViewport.y);
			
			//_content.y = viewportTopLeft.y;
			
			_container.addEventListener( MouseEvent.MOUSE_DOWN, mouseDownHandler, false, 0, true );
			
			onContentResize( null );
			
		}
		
		
		/**
         * Draw the viewport area on top of the container 
         */
   		public function drawDebug() : void
    	{
	           if ( !_container || !_containerViewport )
		               return;
	           
	           
	           // debug container
	           var shape : Shape = new Shape();
	           shape.graphics.lineStyle( 3, 0xFF0000 );
	           shape.graphics.beginFill( 0xFFFFFF, 0.4 );
	           shape.graphics.drawRect( _containerViewport.x, _containerViewport.y, _containerViewport.width, _containerViewport.height );
	           shape.graphics.endFill();
	           shape.cacheAsBitmap = true;
	           
	           _container.addChild( shape );
	           
	           // trace to debug content
	           trace( '---------- SCROLL CONTROLLER : DEBUG CONTENT --------------');
	           
	           var contentBounds : Rectangle = _content.getBounds( _content );
	           trace( 'content bounds   (x, y, w, h) :', int( contentBounds.x ), int( contentBounds.y ), int( contentBounds.width ), int( contentBounds.height ));
	           
	           trace( 'content position (x, y, w, h) :', int( _content.x ), int( _content.y ), int( _content.width ), int( _content.height ));
	           
	           trace( 'content viewport (x, y, w, h) :', int( _contentViewport.x ), int( _contentViewport.y ), int( _contentViewport.width ), int( _contentViewport.height ));
	           
	           if ( _content is DisplayObjectContainer )
	           {
		               shape = new Shape();
		               shape.graphics.lineStyle( 3, 0x00FF00 );
		               shape.graphics.beginFill( 0xFF0000, 0.4 );
		               shape.graphics.drawRect( _contentViewport.x, _contentViewport.y, _contentViewport.width, _contentViewport.height );
		               shape.graphics.endFill();
		               shape.cacheAsBitmap = true;
		               
		               DisplayObjectContainer( _content ).addChild( shape );
		               
		               shape = new Shape();
		               shape.graphics.lineStyle( 3, 0x0000FF );
		               shape.graphics.beginFill( 0x000000, 0.4 );
		               shape.graphics.drawCircle( 0, 0, 50 ); // see the origin of the content in parent
		               shape.graphics.endFill();
		               shape.cacheAsBitmap = true;
		               
		               DisplayObjectContainer( _content ).addChild( shape );
	           }
	           else
	           {
		               trace( _content );
	           }
   	    }
		
		public function removeScrollControll() : void
		{
			if (_content)
			{
				_content.removeEventListener( Event.RESIZE, onContentResize );
				_content.removeEventListener( Event.ADDED, onContentResize );
				_content.removeEventListener( Event.ADDED_TO_STAGE, onContentResize )
				_content.scrollRect = null;
				
			}
			
			if (_container)
			{
				_container.removeEventListener( MouseEvent.MOUSE_MOVE, onMoveDrag );
				_container.removeEventListener( MouseEvent.MOUSE_UP, onStopDrag );
				_container.removeEventListener( MouseEvent.MOUSE_DOWN, mouseDownHandler );
				_container.removeEventListener( Event.ENTER_FRAME, onEnterFrame );
			}

			_content = null;
			_container = null;
			_contentViewport = null;
			_containerViewport = null;
			_contentInitialBounds = null;
		}
		
		
		public function pause() : void
		{
			_paused = true;
			//trace('pause scroll controll');
			_container.removeEventListener( MouseEvent.MOUSE_MOVE, onMoveDrag );
			_container.removeEventListener( MouseEvent.MOUSE_UP, onStopDrag );
			_container.removeEventListener( MouseEvent.MOUSE_DOWN, mouseDownHandler );
			_container.removeEventListener( Event.ENTER_FRAME, onEnterFrame );
			
			//trace('remove onEnterFrame');
		}
		
		public function resume() : void
		{
			if (_contentViewport.height >= this.getContentWidth())
			{
				return;
			}
			
			_paused = false;
			//trace('resume scroll controll');
			_container.addEventListener( MouseEvent.MOUSE_DOWN, mouseDownHandler, false, 0, true );
		}
		
		private function getLastSpeed() : Number
		{
			if ( this._trajectories == null || this._trajectories.length < 2 )
				return 0;
			
			var a : Object = _trajectories[ this._trajectories.length - 2 ];
			var b : Object = _trajectories[ this._trajectories.length - 1 ];	
			
			if ( this._trajectories.length > 2400 ) // no need to keep that much, cleaning up if movement last very long only
			{
				this._trajectories = new Vector.<Object>();
				this._trajectories.push( a, b );
			}
			
			// speed = delta_D / delta_t
			return ( b['localX'] - a['localX'] ) / ( b['time'] - a['time'] );
		}
		
		private var hasTouchContainer:Boolean = false;
		
		public function autoSlide():void
		{
			if (!hasTouchContainer)
			{
				if (_content && _content.scrollRect)
				{
					var newScrollRect : Rectangle = _content.scrollRect.clone();
					newScrollRect.x += 1;
					_content.scrollRect = newScrollRect;
					
					if (newScrollRect.x + newScrollRect.width >= this.getContentWidth())
					{
						hasTouchContainer = true;
					}
				}
			}
		}
		
	}
}