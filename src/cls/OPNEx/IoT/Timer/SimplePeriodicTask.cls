Class OPNEx.IoT.Timer.SimplePeriodicTask Extends %RegisteredObject
{

/// Set a timer for executing the Dummy task, with default values (period or 1 second) and a closing token to stop it manually.
ClassMethod Test(pTimeLapse As %Integer = 20)
{
	#dim tTimer as %Integer = ##class(OPNLib.IoT.Timer).GetTimerFree()
	#dim tStop as %Integer=0
	#dim tMsg as %String=""
	#dim tEndMsg as %String=":##CLOSING"
	#dim tTokenID as %String="BASIC"_$random(9999)
	#dim tStart, tRightNow as %Decimal=$piece($now(),",",2)
	
	do $system.Event.Clear($JOB)
	
	write !,"TokenID: ["_tTokenID_"]. Preserve if you want to close this Task manually"
	set tTimer = ##class(OPNLib.IoT.Timer).Subscribe(.tTimer,$JOB,tTokenID,,tEndMsg)
	
	while 'tStop
	{
		set tMsg = $system.Event.WaitMsg()
		set tRightNow = $piece($now(),",",2)
		
		set tStop = ($List(tMsg,2)[tEndMsg)||((tRightNow-tStart)>pTimeLapse)
		if tStop
		{
			write !,"Stopping..... Bye!"
			do ##class(OPNLib.IoT.Timer).UnSubscribe(tTimer,$JOB,tTokenID)	
		}
		else 
		{
			write !,"Receiving wake-up signal. Excuting... Result: "_..Dummy()
		}
	}
	
	quit
}

ClassMethod StopTask(pTokenID As %String)
{
	// Assumes no other JOB is executing under this TokenID. It will unsubscribe all Timer entries with this pTokenID
	return ##class(OPNLib.IoT.Timer).UnSubscribe(,,pTokenID)
}

ClassMethod Dummy() As %String
{
	return "Task Logic [Number generation: "_$random(99)_"]"
}

}
