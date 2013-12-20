package com.freshplanet.lib.util.pool
{
	
	/** 
	 * @author Renaud Bardet
	 * 
	 * this is the prototype of a Pool, for storing reusable elements
	 * you can either use the DynamicPool implementation or implement this Interface for better performances on a specific case
	 * 
	 */
	public interface IPool
	{
		
		function alloc(size:int):void ;
		
		function pop():* ;
		
		function push(element:*):void ;
		
		function dealloc():void ;
		
		function close():void ;
		
	}
	
}