package
{
    import com.durej.PSDParser.PSDLayer;
    import com.durej.PSDParser.PSDParser;

    import flash.display.Bitmap;
    import flash.display.BitmapData;
    import flash.display.Sprite;
    import flash.display.StageAlign;
    import flash.display.StageScaleMode;
    import flash.events.Event;
    import flash.events.MouseEvent;
    import flash.net.FileFilter;
    import flash.net.FileReference;
    import flash.text.TextField;
    import flash.text.TextFieldAutoSize;
    import flash.text.TextFormat;

    /**
     * com.durej.PSDParser
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
	[SWF(backgroundColor="#FFFFFF", frameRate="31", width="800", height="480")]
	public class Main extends Sprite 
	{
		private var file					: FileReference;
		private var psdParser				: PSDParser;
		private var layersLevel				: Sprite;
		
		public function Main()
		{
			addEventListener(Event.ADDED_TO_STAGE, init);
		}
		
		private function init(event : Event) : void 
		{
			var wid:int = this.stage.stageWidth;
			var hei:int = this.stage.stageHeight;
			
			//draw shape and add it to sprite so that stage is clickable
			var bg:Sprite = new Sprite();
			bg.graphics.beginFill(0xFFFFFF);
			bg.graphics.drawRect(0, 0, wid, hei);
			this.addChild(bg);
			
			//add text prompt
			var format:TextFormat 		= new TextFormat();
			format.bold					= true;
			format.font					= "Arial";
			format.color				= 0xDEDEDE;
			format.size					= 28;
			
			var prompt_txt:TextField 	= new TextField();
			prompt_txt.width			= 600;
			prompt_txt.autoSize			= TextFieldAutoSize.LEFT;
			prompt_txt.multiline 		= true;
			prompt_txt.wordWrap 		= true;
			prompt_txt.selectable 		= false;			
			
			prompt_txt.text 			= "CLICK ANYWHERE TO LOAD PSD FILE \nAfter file has been loaded click anywhere to cycle through layers";
			
			prompt_txt.setTextFormat(format);
			
			this.addChild(prompt_txt);
				
			prompt_txt.x				= (wid/2 - prompt_txt.width/2 );
			prompt_txt.y 				= (hei/2 - prompt_txt.height/2);
			
			//init stage
			this.stage.align 			= StageAlign.TOP_LEFT;
			this.stage.scaleMode 		= StageScaleMode.NO_SCALE;
			
			//click callback
			this.addEventListener(MouseEvent.CLICK, loadPSD);
		}

		//load action must be perfomed on click due to the flash 10 security
		protected function loadPSD(e:Event):void
		{
			file = null;
			file = new FileReference();
			file.addEventListener(Event.SELECT, onFileSelected);
			file.browse([new FileFilter("Photoshop Files","*.psd;")]); 
		}
			
		
		//after file has been selected , load it
		private function onFileSelected(event:Event):void 
		{
			file.removeEventListener(Event.SELECT, onFileSelected);
			file.addEventListener(Event.COMPLETE,parsePSDData);
			file.load();
		}
		
		//after file has been loaded parse it	
		private function parsePSDData(event:Event):void
		{
			psdParser = PSDParser.getInstance();
			psdParser.parse(file.data);	
			
			layersLevel = new Sprite();
			this.addChild(layersLevel);

			for (var i : Number = 0;i < psdParser.allLayers.length; i++) 
			{
				var psdLayer 		: PSDLayer			= psdParser.allLayers[i];
				var layerBitmap_bmp : BitmapData 		= psdLayer.bmp;
				var layerBitmap 	: Bitmap 			= new Bitmap(layerBitmap_bmp);
				layerBitmap.x 							= psdLayer.position.x;
				layerBitmap.y 							= psdLayer.position.y;
				layerBitmap.filters						= psdLayer.filters_arr;
				layersLevel.addChild(layerBitmap);
			}
			
			var compositeBitmap:Bitmap = new Bitmap(psdParser.composite_bmp);
			layersLevel.addChild(compositeBitmap);
			
			this.removeEventListener(MouseEvent.CLICK, loadPSD);
			this.addEventListener(MouseEvent.CLICK, shuffleBitmaps);
		}	

		private function shuffleBitmaps(event : MouseEvent) : void 
		{
			layersLevel.setChildIndex(layersLevel.getChildAt(0), layersLevel.numChildren-1);
		}
	}
}
