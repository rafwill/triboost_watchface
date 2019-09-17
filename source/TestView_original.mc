using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;
using Toybox.Application;
using Toybox.Activity;
using Toybox.ActivityMonitor;
using Toybox.Time;
using Toybox.Time.Gregorian;



class TestView_original extends WatchUi.WatchFace {

	//var geomanist = null;
	

    function initialize() {
        WatchFace.initialize(); 
    }

    // Load your resources here
    function onLayout(dc) {
        setLayout(Rez.Layouts.WatchFace(dc));
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() {
    }

    // Update the view
    function onUpdate(dc) {
    	
    	
    
        // Get the current time and format it correctly
        var timeFormat = "$1$:$2$";
        var clockTime = System.getClockTime();
        var hour = clockTime.hour;
        if (!System.getDeviceSettings().is24Hour) {
        	hour = hour % 12;
        	if (hour == 0) {
        		hour =12;
        	}
        }
        var strhour = hour.toString();
        var strmin = Lang.format("$1$", [clockTime.min.format("%02d")]);
        System.println("Hora:" + strhour);
        System.println("Min:" + strmin);
        
        
        //Get date
        var today = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
		var dateString = Lang.format(
    		"$1$ $2$ $3$",
    		[
        		today.day_of_week,
        		today.day,
		        today.month
		    ]
		);
		System.println(dateString); // e.g. "16:28:32 Wed 1 Mar 2017"
        
        // Get steps, update the field
        var activity = ActivityMonitor.getInfo();
        var stepsGoal = activity.stepGoal;
        var stepsLive = activity.steps;
        
        //var altitude = Activity.getActivityInfo().altitude;
        //System.println("ALtitude:" + altitude);
        
         
        if( activity.stepGoal == 0 ) {

            activity.stepGoal = 5000;

        }
        var stepString = stepsLive.toString() + "/" + stepsGoal.toString( );
		
		System.println("StepsString:" + stepString);
		
		
		//Get Battery
        var batt = System.getSystemStats().battery.toString();
        //var batx = batt.toNumber();
        System.println("Batt:"+ batt + "%");
        //System.println("Batx:"+ batx + "%");
        
        
        //Get altitude 
        var H1P2 = null;
        var H2P2 = null; 
        if( Activity.getActivityInfo().altitude != null ) {
			if(System.getDeviceSettings().elevationUnits == System.UNIT_METRIC){
			H1P2 = Activity.getActivityInfo().altitude.toFloat();
			H1P2 = H1P2.format( "%.0d" );
			H2P2 = " m";
			}
		else{
			H1P2 = Activity.getActivityInfo().altitude.toFloat() * 3.2808399;
			H1P2 = H1P2.format( "%.0d" );
			H2P2 = " ft";
			}
		}
		else{H1P2 = "No data";}
		var altitude = H1P2 + H2P2;
		System.println("altitude:" + altitude);
		
		
		
		
        // Update the view
        
        var view = View.findDrawableById("DateString");
        view.setColor(Application.getApp().getProperty("ForegroundColor"));
        view.setText(dateString);
        
        view = View.findDrawableById("Hour");
        view.setText(strhour);
        
        view = View.findDrawableById("Min");
        view.setText(strmin);
        
        view = View.findDrawableById("StepLabel");
        view.setText(stepString);
        
        view = View.findDrawableById("altitude");
        view.setText(altitude);
        
        view = View.findDrawableById("battery");
        view.setText(batt);
        
        
       //Get Phone Conected
		
		var phone = System.getDeviceSettings().phoneConnected;
		var connected = null;
		if (phone == true) {
			connected = "connected";
			view = View.findDrawableById("phone");
        	view.setText(connected);
        	System.println("connected:" + connected);
		}
		else {
			connected = "connected";
			view = View.findDrawableById("notphone");
        	view.setText(connected);
        	System.println("notconnected:" + connected);
		}
        
        
        //dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
		//dc.drawText(dc.getWidth()/2, dc.getHeight() / 2, Graphics.FONT_LARGE, "altitude:" + altitude, Graphics.TEXT_JUSTIFY_CENTER);
		  
           
        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() {
    }

    // The user has just looked at their watch. Timers and animations may be started here.
    function onExitSleep() {
    }

    // Terminate any active timers and prepare for slow updates.
    function onEnterSleep() {
    }
    
    

}
