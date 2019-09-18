using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Lang as Lang;
using Toybox.Application as App;
using Toybox.Activity as Act;
using Toybox.ActivityMonitor as Actmon;
using Toybox.Time as Time;
using Toybox.Time.Gregorian as Greg;



class TestView extends Ui.WatchFace {

	var geo_small = null;
	var geo_number_small = null;
	var custom = null;
	var calibri_numbers = null;
	var mirrored = false; 
	var showNotifications = true;
	   


  
    function onLayout(dc) {
    	geo_small = Ui.loadResource(Rez.Fonts.geo_small);
    	geo_number_small = Ui.loadResource(Rez.Fonts.geo_number_small);
    	custom = Ui.loadResource(Rez.Fonts.custom);
    	calibri_numbers = Ui.loadResource(Rez.Fonts.calibri_numbers);
    
    }

  
    // Update the view
    function onUpdate(dc) {
    	var displayHeight = System.getDeviceSettings().screenHeight;
        var displayWidth = System.getDeviceSettings().screenWidth;
        var logo = null;
        
        // Shifting screen a little to the right for devices like FR235 to avoid numbers being cut off.
		var xOffset = (displayHeight == 180) ? 12 : 0;
		xOffset = mirrored ? -xOffset : xOffset;

		var xLine = displayWidth/2 + xOffset;
		var xTime = mirrored ? xLine + 10 : xLine - 10;
		var xDate = mirrored ? xLine - 10 : xLine + 10;
		var alignTime = mirrored ? Graphics.TEXT_JUSTIFY_LEFT : Graphics.TEXT_JUSTIFY_RIGHT;
		var alignDate = mirrored ? Graphics.TEXT_JUSTIFY_RIGHT : Graphics.TEXT_JUSTIFY_LEFT;
    	
    	dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_BLACK);
    	dc.clear();
    	
        // Get the current time and format it correctly
        var timeFormat = "$1$:$2$";
        var clockTime = Sys.getClockTime();
        var hour = clockTime.hour.format("%02d");
        if (!Sys.getDeviceSettings().is24Hour) {
        	hour = hour % 12;
        	if (hour == 0) {
        		hour =12;
        	}
        }
        var strhour = hour.toString();
        var strmin = Lang.format("$1$", [clockTime.min.format("%02d")]);
        //Sys.println("Hora:" + strhour);
        //Sys.println("Min:" + strmin);
        
        dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
		dc.drawText(dc.getWidth()/2 - 5, 23, calibri_numbers, strhour, Gfx.TEXT_JUSTIFY_RIGHT);
		dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
		dc.drawText(dc.getWidth()/2 - 5, 80, calibri_numbers, strmin, Gfx.TEXT_JUSTIFY_RIGHT);
        
        //Get date
        var today = Greg.info(Time.now(), Time.FORMAT_MEDIUM);
		var dateString = Lang.format(
    		"$1$ $2$ $3$",
    		[
        		today.day_of_week,
        		today.day,
		        today.month
		    ]
		);
		//Sys.println(dateString); 
		
		dc.setColor(Gfx.COLOR_DK_GRAY, Gfx.COLOR_TRANSPARENT);
		dc.drawText(dc.getWidth()/2, 10, geo_small, dateString, Gfx.TEXT_JUSTIFY_CENTER);
        
        // Get steps, update the field
        var activity = Actmon.getInfo();
        var stepsGoal = activity.stepGoal;
        var stepsLive = activity.steps;
        
         
        if( activity.stepGoal == 0 ) {

            activity.stepGoal = 5000;

        }
        var stepString = stepsLive.toString() + "/" + stepsGoal.toString( );
		
		//Sys.println("Pasos:" + stepString);
		
		dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
		dc.drawText(dc.getWidth()/2 + 5, 82, geo_small, stepString, Gfx.TEXT_JUSTIFY_LEFT);
		
		
		//Get Battery
        var batt = Sys.getSystemStats().battery.toString();
        var batx = batt.toNumber();
        //Sys.println("Porcentaje de bateria:"+ batx + "%");
        
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
		dc.drawText(dc.getWidth()/2 + 5, 42, geo_small, batx + "%", Gfx.TEXT_JUSTIFY_LEFT);
		
        
        //Get altitude 
        var H1P2 = null;
        var H2P2 = null; 
        if( Act.getActivityInfo().altitude != null ) {
			if(Sys.getDeviceSettings().elevationUnits == Sys.UNIT_METRIC){
			H1P2 = Act.getActivityInfo().altitude.toFloat();
			H1P2 = H1P2.format( "%.0d" );
			H2P2 = " m";
			}
		else{
			H1P2 = Act.getActivityInfo().altitude.toFloat() * 3.2808399;
			H1P2 = H1P2.format( "%.0d" );
			H2P2 = " ft";
			}
		}
		else{H1P2 = "No data";}
		var altitude = H1P2 + H2P2;
		//Sys.println("Altitud:" + altitude);
		
		
		dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
		dc.drawText(dc.getWidth()/2 + 5, 62, geo_small, altitude, Gfx.TEXT_JUSTIFY_LEFT);
		
        
        
        
       //Get Phone Conected
		
		var phone = Sys.getDeviceSettings().phoneConnected;
		var connected = null;
		if (phone == true) {
			connected = "Conectado";
			dc.setColor(Gfx.COLOR_YELLOW, Gfx.COLOR_TRANSPARENT);
			dc.drawText(dc.getWidth()/2 + 5, 102, geo_small, connected, Gfx.TEXT_JUSTIFY_LEFT);
			//Sys.println("Telefono " + connected);
		}
		else {
			connected = "Conectado";
			dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
			dc.drawText(dc.getWidth()/2 + 5, 102, geo_small, connected, Gfx.TEXT_JUSTIFY_LEFT);
			//Sys.println("Telefono no " + connected);
		}
        
        //Fancy Line
        
        dc.setColor(Gfx.COLOR_YELLOW,Gfx.COLOR_TRANSPARENT);
		dc.drawLine(xLine,40,xLine,145);    
        
        
        /*Notifications with icon
        if (Sys.DeviceSettings has :phoneConnected) {
        	dc.setColor(Gfx.COLOR_YELLOW,Gfx.COLOR_TRANSPARENT);
        	if (showNotifications && Sys.getDeviceSettings().notificationCount > 0) {
        		//drawNotificationSymbol(dc,mirrored ? xDate-15 : xDate, displayHeight/2 - 0.5*Gfx.getFontHeight(geo_small));
        		drawNotificationSymbol(dc,dc.getWidth()/2 + 5, 143);
        		dc.drawText(dc.getWidth()/2 + 25, 125, geo_small, "mensajes" , Gfx.TEXT_JUSTIFY_LEFT);
			
			} 
        }*/
        
        if (Sys.DeviceSettings has :phoneConnected) {
        	if (showNotifications && Sys.getDeviceSettings().notificationCount == 0) {
        		dc.setColor(Gfx.COLOR_WHITE,Gfx.COLOR_TRANSPARENT);
        		dc.drawText(dc.getWidth()/2 + 5, 122, geo_small, Sys.getDeviceSettings().notificationCount + " mensajes", Gfx.TEXT_JUSTIFY_LEFT);
			}
			else if (showNotifications && Sys.getDeviceSettings().notificationCount == 1) {
				dc.setColor(Gfx.COLOR_YELLOW,Gfx.COLOR_TRANSPARENT);
        		dc.drawText(dc.getWidth()/2 + 5, 122, geo_small, Sys.getDeviceSettings().notificationCount + " mensaje", Gfx.TEXT_JUSTIFY_LEFT);
			} 
			else if (showNotifications && Sys.getDeviceSettings().notificationCount > 1) {
				dc.setColor(Gfx.COLOR_YELLOW,Gfx.COLOR_TRANSPARENT);
        		dc.drawText(dc.getWidth()/2 + 5, 122, geo_small, Sys.getDeviceSettings().notificationCount + " mensajes", Gfx.TEXT_JUSTIFY_LEFT);
			}			 
        }

		//Logo de Triboost
		
		logo = Ui.loadResource(Rez.Drawables.triboost);
		dc.drawBitmap(dc.getWidth()/10 - 5, 130, logo);
    
    	
   		
   		
    }

    
    function onHide() {
    }
    function onExitSleep() {
    }
    function onEnterSleep() {
    }
    
    //Draw an envelope as symbol for phone notifications.
    function drawNotificationSymbol(dc, x, y) {
    	dc.drawRectangle(x,y-10,15,10);
    	dc.drawLine(x,y-10,x+8,y-2);
    	dc.drawLine(x+7,y-2,x+15,y-10);
   	}

}
