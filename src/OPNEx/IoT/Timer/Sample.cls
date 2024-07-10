Include OPNLib.IoT.Timer

/// Author: Jose-Tomas Salvador / May-2020 / Under MIT License
/// ************************************************************
/// 
/// Sample class to test Timer feature
/// It'll assign 4 tasks to 4 timers available or new
Class OPNEx.IoT.Timer.Sample Extends %RegisteredObject
{

Parameter TOKENTOPARENT = "TIMER.SAMPLE";

Property AdminSignal As %String [ InitialExpression = "TM-ADMIN" ];

Property AdminEndToken As %String [ InitialExpression = "##STOP" ];

Property AdminMethod As %String [ InitialExpression = "Admin" ];

Property AdminTimer As %Integer [ InitialExpression = 0 ];

/// Literal to separate signalID from Token/Content
Property TkSep As %String [ InitialExpression = ":" ];

Property Map As %String [ MultiDimensional ];

/// Method to Launch the Tasks in background
/// Parent process could get the PID of this with $ZCHILD... 
/// also, if it passes a pToken and waits, it'll receive an event with msg starting with that token and the JOB of child process
/// Parent process should keep control of PID of child process to stop the subscriptions if associated to that process if required
ClassMethod BGTest(pTasks As %Integer = 4, pToken As %String = "")
{
	set tSample = ..%New()
	do tSample.Test(pTasks,pToken)
}

/// Sample method to distribute pTasks that will run each 500, 1000, 2000, 4000,.. milliseconds
/// It will look for active Timers and assign the tasks as it finds them. 
/// If no Timer is found or there are tasks pending to assign it'll launch the subscription which 
/// will creates Timers as needed
Method Test(pTasks As %Integer = 4, pToken As %String = "") As %Status
{
	#dim tCnt, tSlots, tTimer as %Integer=0
	#dim tTaskLabel as %String=""
	#dim tStopTokenDummyTask as %String = "##STOP"
	#dim tPeriod as %Integer=500
	#dim tSC as %Status = $$$OK
	#dim e as %Exception.SystemException
	
	quit:pTasks'>0 "0-No tasks"
	
	// It clears whatever other signal pending for this $JOB
	do $system.Event.Clear($JOB)
	// Send a signal to the parent process
	do:pToken'="" $system.Event.Signal($ZPARENT,pToken)
	
	try
	{
		for tCnt=1:1:pTasks
		{
			// Define dummy tasks
			set tTaskLabel = "TM-Task"_tCnt
			set tPeriod = $Increment(tPeriod,500)
			set ..Map(tTaskLabel,"period")=tPeriod
			set ..Map(tTaskLabel,"method")="Dummy"
			set ..Map(tTaskLabel,"stop")=tStopTokenDummyTask
			set ..Map(tTaskLabel,"val")=""
		
			// Subscribe task
			set tTimer = ##class(OPNLib.IoT.Timer).GetTimerFree(.tSlots)
			set tTimer = ##class(OPNLib.IoT.Timer).Subscribe(.tTimer,$JOB,tTaskLabel,tPeriod,":"_tStopTokenDummyTask)		
			set ..Map(tTaskLabel,"PIDTIMER")=tTimer
		}

		set tTimer = ##class(OPNLib.IoT.Timer).GetTimerFree(.tSlots)
		set ..AdminTimer = ##class(OPNLib.IoT.Timer).Subscribe(.tTimer,$JOB,..AdminSignal,5000,":"_..AdminEndToken)		
		
		write !,"Waiting for Timers' signalling to execute tasks..."
		
		$$$TOE(tSC,..ReceiveInfo(..TkSep))
	}
	catch e
	{
		// Before quit be sure there is no subscriptions active
		do ..UnsubscribeAllTasks()
		set tSC = e.AsStatus()
	}
		
	quit tSC
}

Method UnsubscribeAllTasks() As %Status
{
	#dim tTaskLabel as %String=""
	#dim tTimer as %Integer = 0
	#dim tSC as %Status = $$$OK
	#dim e as %Exception.SystemException
	
	try
	{
		set tTaskLabel = $order(..Map(""))
		while tTaskLabel'=""
		{
			set tTimer = $get(..Map(tTaskLabel,"PIDTIMER"),0)
			do ##class(OPNLib.IoT.Timer).UnSubscribe(tTimer,$JOB,tTaskLabel)
			set tTaskLabel = $order(..Map(tTaskLabel))
		}
		// Unsubscribe also ADMIN task
		do ##class(OPNLib.IoT.Timer).UnSubscribe(..AdminTimer,$JOB,..AdminSignal)
	}
	catch e
	{
		set tSC = e.AsStatus()
	}
	
	quit tSC
}

/// It keeps Waiting for signals for ever of till the EndToken from AdminSignal is received
Method ReceiveInfo(pTkSep As %String = ":") As %Status
{
	#dim tInfo as %List
	#dim tStopToken as %Boolean=0
	#dim tSignalID as %String=""
	
	while 'tStopToken 
	{
		set tInfo = $system.Event.WaitMsg()
			
		set tSignalID = $piece($List(tInfo,2),pTkSep)
		if (tSignalID = ..AdminSignal)
		{
		  set tStopToken = $method($this,..AdminMethod,$List(tInfo,2))
		  continue:tStopToken
		}
		else
		{
			set ..Map(..AdminSignal,"val")=tSignalID	
			set:tSignalID'="" ..Map(tSignalID,"val") = $method($this,$get(..Map(tSignalID,"method"),"Dummy"),$List(tInfo,2))
		}
	}
	quit $$$OK
}

Method Dummy(pArgs...) As %String
{
	#dim tSignalID as %String = $piece($get(pArgs(1),"---:---"),..TkSep)
	#dim tToken as %String = $piece($get(pArgs(1),"---:---"),..TkSep,2)
	
	write !,$zt($p($h,",",2))_"."_$p($now(),".",2)_" ** Receiving signal to run... "_$get(pArgs(1)," ** no data reveived **")
	
	if ..Map(tSignalID,"stop")=tToken 
	{
		do ##class(OPNLib.IoT.Timer).UnSubscribe($get(..Map(tSignalID,"PIDTIMER"),"---"),$JOB,tSignalID)
	}

	return ""
}

Method Admin(pArgs...) As %Boolean
{
	#dim tSignalID as %String = $piece($get(pArgs(1),"---:---"),..TkSep)
	#dim tToken as %String = $piece($get(pArgs(1),"---:---"),..TkSep,2)
	
	write !,$zt($p($h,",",2))_"."_$p($now(),".",2)_" ** Receiving signal to run... "_$get(pArgs(1)," ** no data reveived **")
	
	if (tSignalID = ..AdminSignal) && (tToken = ..AdminEndToken)
	{
		do ..UnsubscribeAllTasks()
		return 1
	}

	return 0
}

/// This callback method is invoked by the <METHOD>%Close</METHOD> method to 
/// provide notification that the current object is being closed.
/// 
/// <P>The return value of this method is ignored.
Method %OnClose() As %Status [ Private, ServerOnly = 1 ]
{
	do ..UnsubscribeAllTasks()

	Quit $$$OK
}

}
