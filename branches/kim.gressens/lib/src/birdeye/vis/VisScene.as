/*  
 * The MIT License
 *
 * Copyright (c) 2008
 * United Nations Office at Geneva
 * Center for Advanced Visual Analytics
 * http://cava.unog.ch
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
 
 package birdeye.vis
{
	import birdeye.vis.data.DataItemLayout;
	import birdeye.vis.guides.grid.Grid;
	import birdeye.vis.interactivity.InteractivityManager;
	import birdeye.vis.interfaces.coords.ICoordinates;
	import birdeye.vis.interfaces.elements.IElement;
	import birdeye.vis.interfaces.guides.IGuide;
	import birdeye.vis.interfaces.interactivity.IInteractivityManager;
	import birdeye.vis.interfaces.scales.INumerableScale;
	import birdeye.vis.interfaces.scales.IScale;
	import birdeye.vis.interfaces.transforms.IGraphLayout;
	import birdeye.vis.interfaces.transforms.IProjection;
	import birdeye.vis.interfaces.validation.IValidatingChild;
	import birdeye.vis.interfaces.validation.IValidatingParent;
	import birdeye.vis.interfaces.validation.IValidatingScale;
	
	import com.degrafa.GeometryGroup;
	import com.degrafa.Surface;
	import com.degrafa.geometry.RegularRectangle;
	import com.degrafa.paint.SolidFill;
	
	import flash.display.Shape;
	import flash.events.Event;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.xml.XMLNode;
	
	import mx.collections.ArrayCollection;
	import mx.collections.CursorBookmark;
	import mx.collections.ICollectionView;
	import mx.collections.IViewCursor;
	import mx.collections.XMLListCollection;
	import mx.core.IInvalidating;
	import mx.core.UIComponent;

	[Exclude(name="projections", kind="property")]
	[Exclude(name="graphLayouts", kind="property")]

	[DefaultProperty("dataProvider")]
	public class VisScene extends Surface implements IValidatingParent, ICoordinates
	{
		public static const CARTESIAN:String="cartesian";
		public static const POLAR:String="polar";
		public static const VISUAL:String="visual";
		
		// IMPLEMENTATION OF IVALIDATINGPARENT
		
		private var invalidateChilds:Array = new Array();
		private var invalidateScales:Array = new Array();
		
		public function invalidate(child:IValidatingChild):void
		{
			if (child is IValidatingScale)
			{
				if (invalidateScales.lastIndexOf(child) == -1)
				{
					invalidateScales.push(child);
				}
			}
			else
			{
				if (invalidateChilds.lastIndexOf(child) == -1)
				{
					invalidateChilds.push(child);
					invalidateProperties();
				}	
			}
		}
		
		// END IMPLEMENTATION
		
		protected var _active:Boolean = true;
		/** If set to false, the chart is removed and won't be drawn till active becomes true.*/
		[Inspectable(enumeration="true,false")]
		public function set active(val:Boolean):void
		{
			_active = val;
			if (_active)
			{
				invalidateProperties();
				invalidateDisplayList();
			} else 
				clearAll();
		}
		public function get active():Boolean
		{
			return _active;
		}
		
		protected var _isMasked:Boolean = false;
		[Inspectable(enumeration="true,false")]
		public function set isMasked(val:Boolean):void
		{
			_isMasked = val;
			invalidateDisplayList();
		}
		
		public function get svgData():String
		{
			var _svgData:String = '';
			var initialPoint:Point;
			if (elements)
				for each (var element:IElement in elements)
					if (element.svgData)
					{
						initialPoint = contentToGlobal(new Point(elementsContainer.x + element.x, 
																elementsContainer.y + element.y));
						_svgData += '\n<svg x="' + String(initialPoint.x) + 
										'" y="' + String(initialPoint.y) + '">' +
									 element.svgData + '\n</svg>';
					}

			_svgData += '\n';

			if (guides)
				for each (var guide:IGuide in guides)
					if (guide.svgData)
					{
						if (guide.parentContainer)
							initialPoint = localToGlobal(new Point(guide.parentContainer.x + guide.x, 
																	guide.parentContainer.y + guide.y));
						else if (guide is Grid)
							initialPoint = localToGlobal(new Point(elementsContainer.x, 
																	elementsContainer.y));
						else
							initialPoint = localToGlobal(new Point(guide.x, guide.y));
							
						_svgData += '\n<svg x="' + String(initialPoint.x) + 
										'" y="' + String(initialPoint.y) + '">' +
									 guide.svgData + '"\n</svg>';
					}

			_svgData += '\n';
			return _svgData;
		}
		
		private var _coordType:String;
		public function set coordType(val:String):void
		{
			_coordType = val;
			invalidateDisplayList();
		}
		public function get coordType():String
		{
			return _coordType;
		}
		
		private var _transforms:Array;
        [Inspectable(category="General", arrayType="birdeye.vis.interfaces.transforms.ITransform")]
        [ArrayElementType("birdeye.vis.interfaces.transforms.ITransform")]
		public function set transforms(val:Array):void
		{
			_transforms = val;
			var p:uint = 0, l:uint = 0;
			var proj:Array, gLayouts:Array;
			for (var i:Number = 0; i<_transforms.length; i++)
			{
				if (_transforms[i] is IProjection)
				{
					if (!proj)
						proj = [];
					proj[p++] = _transforms[i];
				} else if (_transforms[i] is IGraphLayout) {
					if (!gLayouts)
						gLayouts = [];
					gLayouts[l++] = _transforms[i];
				}
			}
			
			// needed to properly invalidate the display list in case 
			// any of these array is not empty
			if (proj)
				projections = proj;
			if (gLayouts)
				graphLayouts = gLayouts;
		}
		public function get transforms():Array
		{
			return _transforms;
		}

		private var _projections:Array;

        [Inspectable(category="General", arrayType="birdeye.vis.interfaces.IProjection")]
        [ArrayElementType("birdeye.vis.interfaces.IProjection")]
		public function set projections(val:Array):void
		{
			_projections = val;
			invalidateDisplayList();
		}

		private var _graphLayouts:Array
        [Inspectable(category="General", arrayType="birdeye.vis.interfaces.IGraphLayout")]
        [ArrayElementType("birdeye.vis.interfaces.IGraphLayout")]
		public function set graphLayouts(val:Array):void
		{
			_graphLayouts = val;
			invalidateDisplayList();
		}
		public function get graphLayouts():Array
		{
			return _graphLayouts;
		}

		protected var _maxStacked100:Number = NaN;
		/** @Private
		 * The maximum value among all elements stacked according to stacked100 type.
		 * This is needed to "enlarge" the related axis to include all the stacked values
		 * so that all stacked100 elements fit into the chart.*/
		public function get maxStacked100():Number
		{
			return _maxStacked100;
		}
		
		protected var _scales:Array; /* of IScale */
		/** Array of scales, each element will take a scale target from this scale list.*/
        [Inspectable(category="General", arrayType="birdeye.vis.interfaces.scale.IScale")]
        [ArrayElementType("birdeye.vis.interfaces.scales.IScale")]
		public function set scales(val:Array):void
		{
			_scales = val;
			
			// Implementation of IValidatingParent!
			for each (var valChild:IValidatingChild in _scales)
			{
				if (valChild)
				{
					valChild.parent = this;
				}
			}
			
			invalidateProperties();
			invalidateDisplayList();
		}
		
		public function get scales():Array
		{
			return _scales;
		}
		
		protected var _guidesChanged:Boolean =false		
		protected var _guides:Array; /* of IGuide */
		/** Array of guides. */
		[Inspectable(category="General", arrayType="birdeye.vis.interfaces.IGuide")]
		[ArrayElementType("birdeye.vis.interfaces.guides.IGuide")]
		public function set guides(val:Array):void
		{
			_guides = val;
			_guidesChanged = true;
			invalidateProperties();
			invalidateDisplayList();
		}
		
		public function get guides():Array
		{
			return _guides;
		}
		
		protected var _origin:Point;
		public function set origin(val:Point):void
		{
			_origin = val;
			invalidateDisplayList();
		}
		public function get origin():Point
		{
			return _origin;
		}

		private var _colorAxis:INumerableScale;
		/** Define an axis to set the colorField for data items.*/
		public function set colorAxis(val:INumerableScale):void
		{
			_colorAxis = val;
			invalidateDisplayList();
		}
		public function get colorAxis():INumerableScale
		{
			return _colorAxis;
		}

		private var _sizeScale:INumerableScale;
		/** Define a scale to set the sizeDim for data items.*/
		public function set sizeScale(val:INumerableScale):void
		{
			_sizeScale = val;
			invalidateDisplayList();
		}
		public function get sizeScale():INumerableScale
		{
			return _sizeScale;
		}


		
		private var _thicknessRatio:Number = 0.6;
		public function set thicknessRatio(val:Number):void
		{
			_thicknessRatio = val;
			invalidateDisplayList();
		}
		public function get thicknessRatio():Number
		{
			return _thicknessRatio;
		}
		
		private var _customTooltTipFunction:Function;
		public function set customTooltTipFunction(val:Function):void
		{
			_customTooltTipFunction = val;
			invalidateProperties();
			invalidateDisplayList();
		}
		public function get customTooltTipFunction():Function
		{
			return _customTooltTipFunction;
		}

		protected var defaultTipFunction:Function;

		private var _cursor:IViewCursor = null;
		
		protected var chartBounds:Rectangle;

		protected var _elementsContainer:Surface = new Surface();
		public function get elementsContainer():Surface
		{
			return _elementsContainer;
		}

		protected var _lineColor:Number = NaN;
		public function set lineColor(val:Number):void
		{
			_lineColor = val;
			invalidateDisplayList();
		}
		
		protected var _lineAlpha:Number = 1;
		public function set lineAlpha(val:int):void
		{
			_lineAlpha = val;
			invalidateDisplayList();
		}		
		
		protected var _lineWidth:Number = 1;
		public function set lineWidth(val:int):void
		{
			_lineWidth = val;
			invalidateDisplayList();
		}		

		protected var _fillAlpha:Number = 1;
		public function set fillAlpha(val:int):void
		{
			_fillAlpha = val;
			invalidateDisplayList();
		}		

		protected var _fillColor:Number = NaN;
		public function set fillColor(val:Number):void
		{
			_fillColor = val;
			invalidateDisplayList();
		}
		
		protected var _elements:Array; // of IElement
		protected var _elementsChanged:Boolean = false;
		/** Array of elements, mandatory for any coords scene.
		 * Each element must implement the IElement interface which defines 
		 * methods that allow to set fields, basic styles, axes, dataproviders, renderers,
		 * max and min values, etc. Look at the IElement for more details.
		 * Each element can define its own scale (in case a cartesian or polar coords )
		 * or layout (for Visual).
		 * The data providers are calculated based on the group of element that share them.*/
        [Inspectable(category="General", arrayType="birdeye.vis.interfaces.elements.IElement")]
        [ArrayElementType("birdeye.vis.interfaces.elements.IElement")]
		public function set elements(val:Array):void
		{
			_elements = val;
			_elementsChanged = true;
			
			for each (var element:IElement in _elements)
				if (element.visScene != this)
						element.visScene = this;
			
			invalidateProperties();
			invalidateDisplayList();
		}
		public function get elements():Array
		{
			return _elements;
		}

		private var _percentHeight:Number = NaN;
		override public function set percentHeight(val:Number):void
		{
			_percentHeight = val;
			var p:IInvalidating = parent as IInvalidating;
			if (p) {
				p.invalidateSize();
				p.invalidateDisplayList();
			}
		}
		/** 
		 * @private
		 */
		override public function get percentHeight():Number
		{
			return _percentHeight;
		}
		
		private var _percentWidth:Number = NaN;
		override public function set percentWidth(val:Number):void
		{
			_percentWidth = val;
			var p:IInvalidating = parent as IInvalidating;
			if (p) {
				p.invalidateSize();
				p.invalidateDisplayList();
			}
		}
		/** 
		 * @private
		 */
		override public function get percentWidth():Number
		{
			return _percentWidth;
		}
		
		private var _dataItems:Vector.<Object>;
		public function get dataItems():Vector.<Object>
		{
			return _dataItems;
		}
		
		protected var invalidatedData:Boolean = false;
		public var axesFeeded:Boolean = true;
		public var layoutsFeeded:Boolean = true;
		protected var _dataProvider:Object=null;
		public function set dataProvider(value:Object):void
		{
			if (value is Vector.<Object>)
			{
	  			_dataItems = Vector.<Object>(value);

			} else {
				//_dataProvider = value;
				if(typeof(value) == "string")
		    	{
		    		//string becomes XML
		        	value = new XML(value);
		     	}
		        else if(value is XMLNode)
		        {
		        	//AS2-style XMLNodes become AS3 XML
					value = new XML(XMLNode(value).toString());
		        }
				else if(value is XMLList)
				{
					if(XMLList(value).children().length()>0){
						value = new XMLListCollection(value.children() as XMLList);
					}else{
						value = new XMLListCollection(value as XMLList);
					}
				}
				else if(value is Array)
				{
					value = new ArrayCollection(value as Array);
				}
				
				if(value is XML)
				{
					var list:XMLList = new XMLList();
					list += value;
					this._dataProvider = new XMLListCollection(list.children());
				}
				//if already a collection dont make new one
		        else if(value is ICollectionView)
		        {
		            this._dataProvider = ICollectionView(value);
		        }else if(value is Object)
				{
					// convert to an array containing this one item
					this._dataProvider = new ArrayCollection( [value] );
		  		}
		  		else
		  		{
		  			this._dataProvider = new ArrayCollection();
		  		}
		  		
		  		if (ICollectionView(_dataProvider).length > 0)
		  		{
		  			_cursor = ICollectionView(_dataProvider).createCursor();
		  		}
			}
	  			
  			axesFeeded = false;
  			layoutsFeeded = false;
  			invalidatedData = true;
	  		invalidateProperties();
			invalidateDisplayList();
		}		
		/**
		* Set the dataProvider to feed the chart. 
		*/
		public function get dataProvider():Object
		{
			return _dataProvider;
		}
		
		protected var _showDataTips:Boolean = true;
		/**
		* Indicate whether to show/create tooltips or not. 
		*/
		[Inspectable(enumeration="true,false")]
		public function set showDataTips(value:Boolean):void
		{
			_showDataTips = value;
			invalidateProperties();
			invalidateDisplayList();
		}		
		public function get showDataTips():Boolean
		{
			return _showDataTips;
		}

		protected var _showAllDataTips:Boolean = false;
		/**
		* Indicate whether to show/create tooltips or not. 
		*/
		[Inspectable(enumeration="true,false")]
		public function set showAllDataTips(value:Boolean):void
		{
			_showAllDataTips = value;
			invalidateProperties();
			invalidateDisplayList();
		}		
		public function get showAllDataTips():Boolean
		{
			return _showAllDataTips;
		}

		protected var _dataTipFunction:Function = null;
		/**
		* Indicate the function used to create tooltips. 
		*/
		public function set dataTipFunction(value:Function):void
		{
			_dataTipFunction = value;
			invalidateProperties();
			invalidateDisplayList();
		}
		public function get dataTipFunction():Function
		{
			return _dataTipFunction;
		}

		protected var _dataTipPrefix:String;
		/**
		* Indicate the prefix for the tooltip. 
		*/
		public function set dataTipPrefix(value:String):void
		{
			_dataTipPrefix = value;
			invalidateProperties();
			invalidateDisplayList();
		}
		public function get dataTipPrefix():String
		{
			return _dataTipPrefix;
		}

		protected var _tipDelay:Number;
		/**
		* Indicate the delay for the tooltip to show up. 
		*/
		public function set tipDelay(value:Number):void
		{
			_tipDelay = value;
			invalidateDisplayList();
		}
		
		/** 
		 * Indicate whether to have a background or not. Sometimes it's useful that the 
		 * visscene is empty, for ex. when it shares the same space with another visscene and 
		 * we want the scene on the back to have his interactivity.
		 */
		public var _backgroundEmpty:Boolean = false;
		[Inspectable(enumeration="true,false")]
		public function set backgroundEmpty(val:Boolean):void
		{
			_backgroundEmpty = val;
		}
		public function get backgroundEmpty():Boolean
		{
			return _backgroundEmpty;
		}

		/**
		 * Return the mask needed to hide elements that draws outside the elementContainer boundaries.*/
		public function get maskShape():Shape
		{
			return _maskShape;
		}
		
		// UIComponent flow
		
		
		public function VisScene(interactivityMgr:IInteractivityManager = null):void
		{
			super();
			doubleClickEnabled = true;

			if (!interactivityMgr)
			{
				_interactivityManager = new InteractivityManager();
				_interactivityManager.registerCoordinates(this);
			}
			else
			{
				_interactivityManager = interactivityMgr;
			}
		}
		
		
		protected var _interactivityManager:IInteractivityManager;
		
		public function get interactivityManager():IInteractivityManager
		{
			return _interactivityManager;
		}
		
		
		protected var _tooltipLayer:UIComponent;
		
		protected function placeTooltipLayer():void
		{
			if (!_tooltipLayer)
			{
				_tooltipLayer = new UIComponent();
				_elementsContainer.addChild(_tooltipLayer);
				
				this.dispatchEvent(new Event("tooltipLayerPlaced"));
			}
		}
		
		public function get tooltipLayer():UIComponent
		{
			return _tooltipLayer;
		}
		
		protected var rectBackGround:RegularRectangle;
		protected var ggBackGround:GeometryGroup;
		protected var _maskShape:Shape; 
		override protected function createChildren():void
		{
			super.createChildren();
			
			if (!backgroundEmpty)
			{
				_maskShape = new Shape();
				_elementsContainer.addChildAt(_maskShape, 0);
				
				ggBackGround = new GeometryGroup();
				//ggBackGround.enableEvents = false;
				addChildAt(ggBackGround, 0);
				ggBackGround.target = _elementsContainer;
				rectBackGround = new RegularRectangle(0,0,2000,2000);
				rectBackGround.fill = new SolidFill(0x000000,0);
				ggBackGround.geometryCollection.addItem(rectBackGround);
			}
			
			
			
		/*elementsContainer.graphics.beginFill(0xffffff, 0.5);
			elementsContainer.graphics.drawRect(0,0,2000, 2000);
			elementsContainer.graphics.endFill();*/
			
			
			
		}
		
		override protected function commitProperties():void
		{
			super.commitProperties();
			

			
			if (elements && invalidatedData && _cursor)
				loadElementsValues();
			
			commitValidatingChilds();	

		}
		
		protected function commitValidatingChilds():void
		{
			// IMPLEMENTATION IVALIDATINGPARENT
			
			if (invalidateChilds && invalidateChilds.length > 0)
			{
				while(invalidateChilds.length > 0)
				{
					(invalidateChilds.pop() as IValidatingChild).commit();
				}
			}
			
			// END IMPLEMENTATION
		}
		
		protected function commitValidatingScales():void
		{
			if (invalidateScales && invalidateScales.length > 0)
			{
				while (invalidateScales.length > 0)
				{
					(invalidateScales.pop() as IValidatingScale).commit();
				}
			}
		}

		override protected function updateDisplayList(unscaledWidth:Number, unscaledHeight:Number):void
		{
			super.updateDisplayList(unscaledWidth, unscaledHeight);
			
			if (ggBackGround)
			{
				rectBackGround.width = unscaledWidth;
				rectBackGround.height = unscaledHeight;

				if (!contains(ggBackGround))
					addChildAt(ggBackGround, 0);
			}
			
			if (showAllDataTips)
			{
				removeDataItems();
				for (var i:uint = 0; i<numChildren; i++)
				{
					if (getChildAt(i) is DataItemLayout)
						DataItemLayout(getChildAt(i)).showToolTip();
				}
			}
		}
		
		// Other methods

		private function loadElementsValues():void
		{
			_cursor.seek(CursorBookmark.FIRST);
			_dataItems = new Vector.<Object>;
			var j:uint = 0;
			while (!_cursor.afterLast)
			{
				_dataItems[j++] = (_cursor.current);
				_cursor.moveNext();
			}
			
		}

		protected function getDimMaxValue(item:Object, dims:Object, stacked:Boolean = false):Number
		{
			if (dims is String)
				return item[dims];
			else if (dims is Array)
			{
				var dimsA:Array = dims as Array;
				var max:Number = NaN;
				for (var i:Number = 0; i<dimsA.length; i++)
				{ 
					if (isNaN(max))
						max = item[dimsA[i]];
					else {
						if (stacked)
							max += item[dimsA[i]];
						else
							max = Math.max(max, item[dimsA[i]]);
					}
				}
				return max;
			}
			return NaN;
		}

		protected function getDimMinValue(item:Object, dims:Object):Number
		{
			if (dims is String)
				return item[dims];
			else if (dims is Array)
			{
				var dimsA:Array = dims as Array;
				var min:Number = NaN;
				for (var i:Number = 0; i<dimsA.length; i++)
				{ 
					if (isNaN(min))
						min = item[dimsA[i]];
					else 
						min = Math.min(min, item[dimsA[i]]);
				}
				return min;
			}
			return NaN;
		}
		
		protected function removeDataItems():void
		{
			var i:int; 
			var child:*;
			
			for (i = numChildren-1; i>=0; i--)
			{
				child = getChildAt(i); 
				if (child is DataItemLayout)
				{
					DataItemLayout(child).hideToolTip();
					DataItemLayout(child).clearAll();
					removeChildAt(i);
				}
			}
			
			var nItems:Number = graphicsCollection.items.length;
			for (i = 0; i<nItems; i++)
			{
				child = graphicsCollection.getItemAt(i);
				if (child is DataItemLayout)
				{
					DataItemLayout(child).hideToolTip();
					DataItemLayout(child).clearAll();
				}
			}
			graphicsCollection.items = [];
		}
		
		protected function resetScales():void
		{
			if (_scales)
				for (var i:Number = 0; i<_scales.length; i++)
					IScale(_scales[i]).resetValues();
					
			if (_elements)
			{
				for ( i = 0; i<_elements.length; i++)
				{
					resetScale(IElement(_elements[i]).scale1);
					resetScale(IElement(_elements[i]).scale2);
					resetScale(IElement(_elements[i]).scale3);
					resetScale(IElement(_elements[i]).colorScale);
					resetScale(IElement(_elements[i]).sizeScale);
				}	
			}
		}
		
		private function resetScale(scale:IScale):void
		{
			if (scale) scale.resetValues();
		}
		
		public function refresh(updatedDataItems:Vector.<Object>, field:Object = null, colorFieldValues:Array = null, fieldID:Object = null):void
		{
			for (var i:Number = 0; i<elements.length; i++)
				IElement(elements[i]).refresh(updatedDataItems, field, colorFieldValues, fieldID);
		}
		
	    public function clearAll():void
	    {
			
			if (elements)
			{
				var elLength:int = elements.length;

				for (var j:int=0;j<elLength;j++)
				{
					if (elements[i] is IElement)
					{
						(elements[i] as IElement).clear();
					}
				}
			}
		
            if (guides)
            {
				var gLength:int = guides.length;

            	for (var i:int=0;i<gLength;i++)
            	{
            		if (guides[i] is IGuide)
            		{
            			(guides[i] as IGuide).clearAll();
            		}
            	}
            }
	    }
	}  
}