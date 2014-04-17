package com.durej.PSDParser 
{
    import flash.display.BitmapData;
    import flash.display.BlendMode;
    import flash.filters.DropShadowFilter;
    import flash.filters.GlowFilter;
    import flash.geom.Point;
    import flash.geom.Rectangle;
    import flash.utils.IDataInput;

    /**
     * com.durej.PSDLayer
     *
     * @author       Copyright (c) 2010 Slavomir Durej
     * @version      0.1
     *
     * @link         http://durej.com/
     *
     * Licensed under the Apache License, Version 2.0 (the "License");
     * you may not use this file except in compliance with the License.
     * You may obtain a copy of the License at
     *
     * http://www.apache.org/licenses/LICENSE-2.0
     *
     * Unless required by applicable law or agreed to in writing, software
     * distributed under the License is distributed on an "AS IS" BASIS,
     * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
     * either express or implied. See the License for the specific language
     * governing permissions and limitations under the License.
     */
	public class PSDLayer 
	{
		public static const LayerType_FOLDER_OPEN 	: String = "folder_open";
		public static const LayerType_FOLDER_CLOSED : String = "folder_closed";
		public static const LayerType_HIDDEN 		: String = "hidden";
		public static const LayerType_NORMAL 		: String = "normal";

		private var dataSource				: IDataInput;
		
		public var bmp						: BitmapData;
		public var bounds					: Rectangle;
		public var position					: Point;
		public var name						: String;
		public var type						: String = LayerType_NORMAL;
		public var layerID					: uint;
		public var numChannels				: int;
		public var channelsInfo_arr			: Array;
		public var blendModeKey				: String;
		public var blendMode				: String;
		public var alpha					: Number;
		public var maskBounds				: Rectangle;
		public var maskBounds2				: Rectangle;	
		public var clippingApplied			: Boolean;
		public var isLocked					: Boolean;
		public var isVisible				: Boolean;
		public var pixelDataIrrelevant		: Boolean;
		public var nameUNI					: String; //layer unicode name		
		public var filters_arr				: Array; //filters array	
			
		public function PSDLayer(data:IDataInput)
		{
			this.dataSource = data;
			readLayerBasicInfo();	
		}

		private function readLayerBasicInfo() : void 
		{
			
			//------------------------------------------------------------- get bounds
			/*
			4 * 4 bytes.
			Rectangle containing the contents of the layer. Specified as top, left,
			bottom, right coordinates.
			*/
			bounds 		= readRect();
			position	= new Point(bounds.x, bounds.y);
			
			//------------------------------------------------------------- get num channels
			/*
			2 bytes.
			The number of channels in the layer.
			*/
			numChannels 	= dataSource.readUnsignedShort(); //readShortInt
			
			//------------------------------------------------------------- get Layer channel info
			/*
			6 * number of channels bytes
			Channel information. Six bytes per channel.
			*/
			channelsInfo_arr		= new Array( numChannels );
			
			for ( var i:uint = 0; i < numChannels; ++i ) 
			{
				channelsInfo_arr[i] = new PSDChannelInfoVO(dataSource);
			}
			
			//------------------------------------------------------------- get signature
			/*
			4 bytes.
			Blend mode signature. 
			*/
			var sig:String = dataSource.readUTFBytes( 4 );
			if (sig != "8BIM") throw new Error("Invalid Blend mode signature: " + sig ); 

			//------------------------------------------------------------- get blend mode key
			/*
			4 bytes.
			Blend mode key.
			*/
			blendModeKey = dataSource.readUTFBytes( 4 );

			//------------------------------------------------------------- get blend mode
			/*
			matches the flash blend mode to photoshop layer blen mode if match is found
			it the blend modes are not compatible "BlendMode.NORMAL is used" 
			*/
			blendMode = getBlendMode();
			
			//------------------------------------------------------------- get opacity
			/*
			1 byte.
			Opacity. 0 = transparent ... 255 = opaque
			*/
			var opacity:int = dataSource.readUnsignedByte();
			
			//converts to more flash friendly alpha
			alpha = opacity/255;
			
			//------------------------------------------------------------- get clipping
			/*
			1 byte.
			Clipping. 0 (false) = base, 1 (true) = non-base
			 */
			clippingApplied = dataSource.readBoolean();
			
			
			//------------------------------------------------------------- get flags
			/*
			1 byte.
			bit 0 = transparency protected 
			bit 1 = visible
			bit 2 = obsolete
			bit 3 = 1 for Photoshop 5.0 and later, tells if bit 4 has useful information;
			bit 4 = pixel data irrelevant to appearance of document
			*/
			var flags:uint = dataSource.readUnsignedByte();
			
			//transparency protected 
			isLocked = ((flags&1) != 0);
			
			//visible
			isVisible = ((flags&2) == 0);
			
			//irrelevant
			if ((flags&3) != 0) pixelDataIrrelevant = (flags&4) != 0; //543
			
			// padding
            dataSource.readByte();
			
			//----------------------------------------------------------------------------
			//------------------------------------------------------------- get extra data
			//----------------------------------------------------------------------------
			
			var extraSize	:uint = dataSource.readUnsignedInt(); //561
			var pos			:int 	= dataSource["position"];
			var size		:int;

			//------------------------------------------------------------- get layer mask (564)
			parseLayerMaskData(dataSource);
			
			//------------------------------------------------------------- get blending ranges (570)
			//parseLayerBlendingRanges( fileData );
			//skipping for now..
			var layerBlendingRangesSectionSize:uint = dataSource.readUnsignedInt();
			dataSource["position"] += layerBlendingRangesSectionSize;
			
			//------------------------------------------------------------- get layer name (576)
			var nameObj:Object = readPascalStringObj();
			name = nameObj.str;
			
			//remember this position
			var prevPos:uint	= dataSource["position"];
			
			//----------------------------------------------------------------------------------
			//------------------------------------------------------------- read layer info tags
			//----------------------------------------------------------------------------------
			
			while (dataSource["position"] - pos < extraSize)
			{
				//------------------------------------------------------------- get signature
				sig = dataSource.readUTFBytes(4);
				
				//check signature
				if (sig != "8BIM") throw new Error("layer information signature error");
				
				//------------------------------------------------------------- get layer tag
				/*
				4 bytes.
				Key: a 4-character code
				*/
				var tag:String = dataSource.readUTFBytes(4); //readString(4)
				
				/*
				4 bytes.
				Length data below, rounded up to an even byte count.
				*/
				size = dataSource.readInt();
				size = (size + 1) & ~0x01;
				
				//remember previous position
				prevPos = dataSource["position"];
				
				// trace ("tag = "+tag);
				
				switch (tag)
				{
					//------------------------------------------------------------- get layer ID
					case "lyid": layerID 	= dataSource.readInt(); break;
					
					//------------------------------------------------------------- get layer divider section
					case "lsct": readLayerSectionDevider(); break;
					
					//------------------------------------------------------------- get layer unicode name
					case "luni": nameUNI 	= dataSource.readMultiByte(size*2, "unicode"); break;
					
					//------------------------------------------------------------- get layer effects
					case "lrFX": parseLayerEffects(); break;
				}

                dataSource["position"] += prevPos + size - dataSource["position"];
			}

            dataSource["position"] += pos + extraSize - dataSource["position"];
		}
		
		private function parseLayerEffects() :void
		{
			filters_arr = new Array();
			
			var version			:int = dataSource.readShort(); //fileData.readShort( length 2)
			var numEffects		:int = dataSource.readShort(); //fileData.readShort( length 2)
			var remainingSize	:int;
			
			for ( var i:uint = 0; i < numEffects; ++i ) 
			{
				
				var sig:String = dataSource.readUTFBytes(4);
				
				//check signature
				if (sig != "8BIM") throw new Error("layer effect information signature error");
				
				//check effect ID
				var effID:String = dataSource.readUTFBytes(4);
				
				switch (effID) 
				{
					case "cmnS":		//common state info
						//skip 
						/*
						4 Size of next three items: 7
						4 Version: 0
						1 Visible: always true
						2 Unused: always 0
						*/
                        dataSource["position"] += 11;
						break;
					
					case "dsdw":		//drop shadow
						remainingSize 				= dataSource.readInt();
						parseDropShadow(dataSource,false);
						break;
					
					case "isdw":		//inner drop shadow
						remainingSize 				= dataSource.readInt();
						parseDropShadow(dataSource,true);
						break;
					
					case "oglw":		//outer glow
						remainingSize 				= dataSource.readInt();
						parseGlow(dataSource,false);
						break;
					
					case "iglw":		//inner glow
						remainingSize 				= dataSource.readInt();
						parseGlow(dataSource,true);
						break;
					
					
					default :
                        dataSource["position"] += remainingSize;
						return;
				}
				
			}
			filters_arr.reverse();
		}

		private function parseGlow(dataSource:IDataInput, inner:Boolean = false):void
		{
			//4 Size of the remaining items: 41 or 51 (depending on version)
			var ver				:int 	= dataSource.readInt(); 			//0 (Photoshop 5.0) or 2 (Photoshop 5.5)
			var blur			:int 	= dataSource.readShort();			//Blur value in pixels (8)
			var intensity		:int	= dataSource.readInt();				//Intensity as a percent (10?) (not working)

            dataSource["position"] += 4;											//2 bytes for space
			var color_r:int = dataSource.readUnsignedByte();
            dataSource.readByte();
			var color_g:int = dataSource.readUnsignedByte();
            dataSource.readByte();
			var color_b:int = dataSource.readUnsignedByte();
			
			//color shoul be 0xFFFF6633
			var colorValue		:uint = color_r<< 16 | color_g << 8 | color_b;

            dataSource["position"] += 3;
			
			var blendSig:String = dataSource.readUTFBytes( 4 );
			if (blendSig != "8BIM") throw new Error("Invalid Blend mode signature for Effect: " + blendSig ); 
			
			/*
			4 bytes.
			Blend mode key.
			*/
			var blendModeKey:String = dataSource.readUTFBytes( 4 );
			
			var effectIsEnabled:Boolean = dataSource.readBoolean();			//1 Effect enabled
			
			var alpha : Number		= dataSource.readUnsignedByte() /255;	 					//1 Opacity as a percent
			
			if (ver == 2)
			{
				if (inner) var invert:Boolean = dataSource.readBoolean();
				
				//get native color
                dataSource["position"] += 4;											//2 bytes for space
				color_r = dataSource.readUnsignedByte();
                dataSource.readByte();
				color_g = dataSource.readUnsignedByte();
                dataSource.readByte();
				color_b = dataSource.readUnsignedByte();
                dataSource.readByte();
				
				var nativeColor		:uint = color_r<< 16 | color_g << 8 | color_b;
			}
			
			if (effectIsEnabled)
			{
				var glowFilter:GlowFilter	= new GlowFilter();
				glowFilter.alpha 			= alpha;
				glowFilter.blurX 			= blur;
				glowFilter.blurY 			= blur;
				glowFilter.color 			= colorValue;
				glowFilter.quality 			= 4;
				glowFilter.strength			= 1; //intensity isn't being passed correctly;
				glowFilter.inner 			= inner;
				
				filters_arr.push(glowFilter);
			}
		}		
		
		private function parseDropShadow(dataSource:IDataInput, inner:Boolean = false):void
		{
						//4 Size of the remaining items: 41 or 51 (depending on version)
			var ver				:int 	= dataSource.readInt(); 			//0 (Photoshop 5.0) or 2 (Photoshop 5.5)
			var blur			:int 	= dataSource.readShort();			//Blur value in pixels (8)
			var intensity		:int 	= dataSource.readInt();				//Intensity as a percent (10?)
			var angle			:int 	= dataSource.readInt();				//Angle in degrees		(120)
			var distance		:int 	= dataSource.readInt();				//Distance in pixels		(25)
			
			dataSource["position"] += 4;											//2 bytes for space
			var color_r:int = dataSource.readUnsignedByte();
            dataSource.readByte();
            var color_g:int = dataSource.readUnsignedByte();
            dataSource.readByte();
			var color_b:int = dataSource.readUnsignedByte();
			
			//color shoul be 0xFFFF6633
			var colorValue		:uint = color_r<< 16 | color_g << 8 | color_b;

            dataSource["position"] += 3;
			
			var blendSig:String = dataSource.readUTFBytes( 4 );
			if (blendSig != "8BIM") throw new Error("Invalid Blend mode signature for Effect: " + blendSig ); 
			
			/*
			4 bytes.
			Blend mode key.
			*/
			var blendModeKey:String = dataSource.readUTFBytes( 4 );
			
			var effectIsEnabled:Boolean = dataSource.readBoolean();			//1 Effect enabled
			
			var useInAllEFX:Boolean = dataSource.readBoolean();				//1 Use this angle in all of the layer effects
			
			var alpha : Number		= dataSource.readUnsignedByte() /255;	 					//1 Opacity as a percent
			
			//get native color
            dataSource["position"] += 4;											//2 bytes for space
			color_r = dataSource.readUnsignedByte();
            dataSource.readByte();
			color_g = dataSource.readUnsignedByte();
            dataSource.readByte();
			color_b = dataSource.readUnsignedByte();
            dataSource.readByte();
			
			var nativeColor		:uint = color_r<< 16 | color_g << 8 | color_b;
			
			if (effectIsEnabled)
			{
				var dropShadowFilter:DropShadowFilter = new DropShadowFilter();
				dropShadowFilter.alpha 		= alpha;
				dropShadowFilter.angle 		= 180 - angle;
				dropShadowFilter.blurX 		= blur;
				dropShadowFilter.blurY 		= blur;
				dropShadowFilter.color 		= colorValue;
				dropShadowFilter.quality 	= 4;
				dropShadowFilter.distance 	= distance;
				dropShadowFilter.inner 		= inner;
				dropShadowFilter.strength	= 1;
				
				filters_arr.push(dropShadowFilter);
				
				if (filters_arr.length == 2)
				{
					filters_arr.reverse();
				}
			}
		}		
		
		private function readRect():Rectangle
		{
			var y 		: int = dataSource.readInt();
			var x 		: int = dataSource.readInt();
			var bottom 	: int = dataSource.readInt();
			var right 	: int = dataSource.readInt();
			
			return new Rectangle(x,y,right-x, bottom-y);
		}
		
		private function readLayerSectionDevider() :void
		{
			var dividerType : int = dataSource.readInt();
			
			switch (dividerType) 
			{
				case 0: type = LayerType_NORMAL;	 		break;
				case 1: type = LayerType_FOLDER_OPEN; 		break;
				case 2: type = LayerType_FOLDER_CLOSED; 	break; 
				case 3: type = LayerType_HIDDEN;			break;
			}
		}		

		//returns the read value and its length in format {str:value, length:size}
		private function readPascalStringObj():Object
		{
			var size:uint = dataSource.readUnsignedByte();
			size += 3 - size % 4;
			return  {str:dataSource.readMultiByte( size, "shift-jis").toString(), length:size + 1};
		}

		public function getBlendMode():String
		{
			switch(blendModeKey)
			{
				case "lddg" : return BlendMode.ADD ;
				case "dark" : return BlendMode.DARKEN ;
				case "diff" : return BlendMode.DIFFERENCE ;
				case "hLit" : return BlendMode.HARDLIGHT ;
				case "lite" : return BlendMode.LIGHTEN ;
				case "mul " : return BlendMode.MULTIPLY ;
				case "over" : return BlendMode.OVERLAY ;
				case "scrn" : return BlendMode.SCREEN ;
				case "fsub" : return BlendMode.SUBTRACT ;
				default 	: return BlendMode.NORMAL; 
			}
		}

		private function parseLayerMaskData( dataSource:IDataInput ):void
		{
			//-------------------------------------------------------------  READING LAYER MASK
			/*
			4 bytes.
			Size of the data: 36, 20, or 0.
			If zero, the following fields are not present
			*/
			var maskSize:uint = dataSource.readUnsignedInt();
			
			if (!(maskSize == 0 || maskSize ==  20 || maskSize == 36))
			{
				throw new Error("Invalid mask size");
			}	
			
			if ( maskSize > 0 ) 
			{
				maskBounds2 = readRect();
				
				var defaultColor			: uint	= dataSource.readUnsignedByte(); // readTinyInt
				var flags					: uint	= dataSource.readUnsignedByte(); // readBits(1)
				
				if (maskSize == 20)
				{
					var maskPadding			: int	= dataSource.readInt(); // 723 (readShortInt)
				}
				else
				{
					var realFlags			: uint	= dataSource.readUnsignedByte();
					var realUserMaskBack	: uint	= dataSource.readUnsignedByte();
					
					maskBounds = readRect();
				}
			}
		}			
	}
}
