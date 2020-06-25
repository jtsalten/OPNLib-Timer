Include OPNLib.IoT.Timer

/// Author: Jose-Tomas Salvador / May-2020 / Under MIT License
/// ************************************************************
/// 
/// Sample class to test Timer feature
/// It'll run a Clock (with an alarm), a CountDown and a Cronometer
Class OPNEx.IoT.Timer.Clocks Extends %RegisteredObject
{

Property ClockTimer As %Integer;

Property CountDownTimer As %Integer;

Property CronometerTimer As %Integer;

Property AdminTimer As %Integer;

Property AdminSignal As %String [ InitialExpression = "TM-ADMIN" ];

Property AdminEndToken As %String [ InitialExpression = "##STOP" ];

Property TkSep As %String [ InitialExpression = ":" ];

Property Map As %String [ MultiDimensional ];

/// Clocks Sample will initiate a Clock that will stop after pClockTime seconds, a CountDown of pCountDown seconds and a Cronometer that will finish after pCronometer
ClassMethod Test(pClockTime As %Integer = 30, pCDTime As %Integer = 20, pCronoTime As %Integer = 10) As %Status
{
	#dim tClockSet as OPNEx.IoT.Timer.Clocks = ..%New()
	#dim tTkSep as %String = tClockSet.TkSep
	#dim tTimer,tSlots as %Integer=0

	// It clears whatever other signal pending for this $JOB
	do $system.Event.Clear($JOB)
	// Signals the parent process if any, sending back this process JOB
	do:$ZPARENT'=0 $system.Event.Signal($ZPARENT,"CLOCKS:"_$JOB)
		
	// Get a Timer with free slots, if there is any already running
	set tTimer = ##class(OPNLib.IoT.Timer).GetTimerFree(.tSlots)
	
	// Launch
	set tClockSet.ClockTimer = ##class(OPNLib.IoT.Timer).Subscribe(.tTimer,$JOB,"TMCLOCK",1000)
	set tClockSet.CountDownTimer = ##class(OPNLib.IoT.Timer).Subscribe(.tTimer,$JOB,"TMCOUNTDOWN",100)
	set tClockSet.CronometerTimer = ##class(OPNLib.IoT.Timer).Subscribe(.tTimer,$JOB,"TMCRONOMETER",100)
	set tClockSet.AdminTimer = ##class(OPNLib.IoT.Timer).Subscribe(.tTimer,$JOB,tClockSet.AdminSignal,10000,tTkSep_tClockSet.AdminEndToken)
	
	// Initialize data for each Task: CLOCK, COUNTDOWN, CRONOMETER and ADMIN
	// This depends totally on the logic that we decide to implement
	set tClockSet.Map("TMCLOCK","init")=$piece($h,",",2)
	set tClockSet.Map("TMCLOCK","val")= $piece($h,",",2)
	set tClockSet.Map("TMCLOCK","method")="Clock"
	set tClockSet.Map("TMCLOCK","alarm")= $zt($piece($h,",",2)+pClockTime)  //sets an alarm... when reached it'll stop
	set tClockSet.Map("TMCOUNTDOWN","init")=$p($now(),",",2)+pCDTime
	set tClockSet.Map("TMCOUNTDOWN","val")=tClockSet.Map("TMCOUNTDOWN","init")
	set tClockSet.Map("TMCOUNTDOWN","method")="CountDown"
	set tClockSet.Map("TMCOUNTDOWN","min")=0 
	set tClockSet.Map("TMCRONOMETER","init")=$p($now(),",",2)
	set tClockSet.Map("TMCRONOMETER","val")=0
	set tClockSet.Map("TMCRONOMETER","method")="Cronometer"
	set tClockSet.Map("TMCRONOMETER","max")=pCronoTime
	set tClockSet.Map("TMCRONOMETER","val")=0
	set tClockSet.Map(tClockSet.AdminSignal,"method")="Admin"
	
	do tClockSet.ReceiveInfo()
	
	// Unsubscribe (if not already done)
	set tClockSet.ClockTimer = ##class(OPNLib.IoT.Timer).UnSubscribe(tClockSet.ClockTimer,$JOB,"TMCLOCK")
	set tClockSet.CountDownTimer = ##class(OPNLib.IoT.Timer).UnSubscribe(tClockSet.CountDownTimer,$JOB,"TMCOUNTDOWN")
	set tClockSet.CronometerTimer = ##class(OPNLib.IoT.Timer).UnSubscribe(tClockSet.CronometerTimer,$JOB,"TMCRONOMETER")
	set tClockSet.AdminTimer = ##class(OPNLib.IoT.Timer).UnSubscribe(tClockSet.AdminTimer,$JOB,tClockSet.AdminSignal)
	quit
}

/// Stop all subscriptions for this sample. Asssuming default names for the signals
ClassMethod StopTest()
{
	// Assumes no other JOB is executing under this TokenID. It will unsubscribe all Timer entries with this pTokenID
	do ##class(OPNLib.IoT.Timer).UnSubscribe(,,"TMCLOCK")
    do ##class(OPNLib.IoT.Timer).UnSubscribe(,,"TMCOUNTDOWN")
    do ##class(OPNLib.IoT.Timer).UnSubscribe(,,"TMCRONOMETER")
    do ##class(OPNLib.IoT.Timer).UnSubscribe(,,"TM-ADMIN")
    quit
}

/// It keeps Waiting for signals for ever of till a pEndToken for a particular pCtrlSignal is received
Method ReceiveInfo()
{
	#dim tInfo as %List
	#dim tStopToken as %Boolean=0
	#dim tSignalID as %String=""
	
	while 'tStopToken 
	{
		set tInfo = $system.Event.WaitMsg()
		//trace		w !,$List(tInfo,1)_" ** "_$List(tInfo,2)
		
		set tSignalID = $piece($List(tInfo,2),":")
		if (tSignalID = ..AdminSignal)
		{
		  set tStopToken = $List(tInfo,2)[..AdminEndToken
		  continue:tStopToken
		}
		
		set ..Map(..AdminSignal,"currentSignal")=tSignalID
		
		set:tSignalID'="" ..Map(tSignalID,"val") = $method($this,$get(..Map(tSignalID,"method"),"Dummy"))
	}
	quit
}

Method Dummy() As %String
{
	do ..Display()
	return ""
}

Method Admin() As %String
{
	// Check if everything is stopped and, if so, unsubscribe itself
	if (..ClockTimer=-1)&&(..CronometerTimer=-1)&&(..CountDownTimer=-1)
	{
		do ##class(OPNLib.IoT.Timer).UnSubscribe(..AdminTimer,$JOB,..AdminSignal)
		set ..AdminTimer = -1
	}
	return ""
}

Method Clock() As %String
{
	#dim tHora as %Integer=$p($h,",",2)
	
	set ..Map("TMCLOCK","val")= tHora
	do ..Display()

    //trace write !,"Alarm: "_$zth($get(..Map("TMCLOCK","alarm"),""),,86400)
	if tHora'< $zth($get(..Map("TMCLOCK","alarm"),""),,86400)
	{
		//trace     write !,"en el ifff..."
		do ##class(OPNLib.IoT.Timer).UnSubscribe(..ClockTimer,$JOB,"TMCLOCK")
		set ..ClockTimer = -1
	}
	
	//trace write !,"Map: "_$get(..Map("TMCLOCK","alarm")," ** ")_" tHora: "_tHora
	return tHora
}

Method CountDown() As %String
{
	// This COUNTDOWN is supposed to be initialized to $now() + time to countdown when started.
	#dim tInit as %Integer=$get(..Map("TMCOUNTDOWN","init"),0)
	#dim tRemaining as %Integer=(tInit - $p($now(),",",2))
	
	if tRemaining < $get(..Map("TMCOUNTDOWN","min"),0) set tRemaining = $get(..Map("TMCOUNTDOWN","min"),0)

	set ..Map("TMCOUNTDOWN","val")= tRemaining
	do ..Display()
	
	if tRemaining '> $get(..Map("TMCOUNTDOWN","min"),0) 
	{
		do ##class(OPNLib.IoT.Timer).UnSubscribe(..CountDownTimer,$JOB,"TMCOUNTDOWN")
		set ..CountDownTimer = -1
	}
	
	return tRemaining
}

Method Cronometer() As %Integer
{
	// This CRONOMETER is supposed to be initialized to $now() when started
	#dim tInit as %Integer=$get(..Map("TMCRONOMETER","init"),0)
	#dim tTimePassed as %Integer=($p($now(),",",2) - tInit)

	if tTimePassed '< $get(..Map("TMCRONOMETER","max"),0) set tTimePassed = $get(..Map("TMCRONOMETER","max"),0)
	
	set ..Map("TMCRONOMETER","val")= tTimePassed
	do ..Display()
	
	if tTimePassed '< $get(..Map("TMCRONOMETER","max"),0) 
	{
		do ##class(OPNLib.IoT.Timer).UnSubscribe(..CronometerTimer,$JOB,"TMCRONOMETER")
		set ..CronometerTimer = -1
	}

	return tTimePassed
}

Method Display() As %String
{
	w #
	w !,!,!,!,!
	w ?5,"CLOCK [alarm: "_$get(..Map("TMCLOCK","alarm"),"")_"]",?30,"COUNTDOWN",?45,"CRONOMETER [up to: "_$get(..Map("TMCRONOMETER","max"),"")_"]"
	w !
	w ?8,$zt($get(..Map("TMCLOCK","val"),$p($h,",",2))),?30,$get(..Map("TMCOUNTDOWN","val"),""),?45,$get(..Map("TMCRONOMETER","val"),"")
	quit
}

}
