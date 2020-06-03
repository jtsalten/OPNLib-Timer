Include OPNLib.IoT.Timer

/// Author: Jose-Tomas Salvador / May-2020 / Under MIT License
/// ************************************************************
/// This class implements a Timer
/// A Timer will be an InterSystems IRIS process that keeps running and looping continously, 
/// sending periodical wake-up signals to the processes that are subscribed to it.
/// 
/// A Timer created without subscriptions will end after a timeout period (by default 900 seconds). 
/// In general, when a Timer has not work to do it starts elonging the loops to avoid CPU cycle consumption,
/// hanging in incremental intervals up to 9 seconds.
/// 
/// During the subscription process the subscriber send its PID, the period of time between wake-ups, the token 
/// that the Timer must use as the wake-up message and the message that the Timer should send back to inform 
/// to the subscriber that it will stop waking it up.
/// 
/// A Timer accepts as much subscribers as stated by $$$MaxSignalsByTimer (50 by default) defined in OPNEx.IoT.Config
/// If a process requests a subscription for a Timer that it doesn't exist or that has reached the maximum number 
/// of subscribers, automatically a new Timer will be created and that process will be subscribed to the new Timer. 
/// 
/// WARNING: The precission of a Timer will depend on several factors: general system load, number of subscribers and 
/// period duration. In general the Timer wake-up signals will reach the subscriber with more precission when system 
/// load and subscribers is lower and period greater.
/// Example:
///   We want to create/initiate To create/initiate a Timer just execute: 
///       do ##class(OPNEx.IoT.Timer).Start()
Class OPNLib.IoT.Timer Extends %RegisteredObject
{

/// Stop and drop the subscriptions for a particular pPIDTimer. 
/// By default doesn't ask for confirmacion (pAsk=0)
ClassMethod Stop(pPIDTimer As %Integer = "", pAsk As %Boolean = 0) As %Status
{
		quit:pPIDTimer="" 0
		do ..StopAll(pPIDTimer,pAsk,0)
		quit $$$OK
}

/// Stop and drop all the timers (without arguments) or a specific pPIDTimer
/// By default it'll prompt for confirmation.
ClassMethod StopAll(pPIDTimer As %Integer = "", pAsk As %Boolean = 1, pVerbose As %Boolean = 1) As %Status
{
	#dim tYes as %String="y"
	#dim tTimers as %List
	#dim tCnt, tTimer as %Integer=0
	
	if pPIDTimer = ""
	{
		read:pAsk "These will stop all the timers and delete all subscriptions to them. Are you sure (y/n)?",tYes
		if $zcvt(tYes,"l") = "y"
		{
			set tTimers = ..Timers()
			while $ListNext(tTimers,tCnt,tTimer)
			{
				write:pVerbose !,"Stopping Timer ...: "_tTimer
				do ..UnSubscribe(tTimer)
			}
			kill ^OPNLIBTIMER
		}
	}
	else
	{
		read:pAsk "These will stop this timer and delete all subscriptions to it. Are you sure (y/n)?",tYes
		if $zcvt(tYes,"l") = "y"
		{
			write:pVerbose !,"Stopping Timer ...: "_pPIDTimer
			do ..UnSubscribe(pPIDTimer)
			kill ^OPNLIBTIMER(pPIDTimer)
			do $I(^OPNLIBTIMER,-1)
		}
	}

	quit $$$OK
}

/// Returns a list with all the Timers - First list element is $c(0)
ClassMethod Timers(pVerbose As %Boolean = 0) As %List
{
	#dim tIdx, tValue as %String=""
	#dim tLista as %List=$ListBuild("")
	
	set tIdx = $order(^OPNLIBTIMER(tIdx),1,tValue)
	while (tIdx'="")
	{
		set $List(tLista,*+1)=tIdx
		set tIdx = $order(^OPNLIBTIMER(tIdx),1,tValue)
	}
	
	zw:pVerbose tLista

	return tLista
}

/// Returns the first Timer PID with free slots to new subscriptions, if any
ClassMethod GetTimerFree(Output pSlots As %Integer) As %Integer
{
	#dim tCnt as %Integer=0
	#dim tTimer as %Integer;
	
	set pSlots = 0
	
	set tTimer = $Order(^OPNLIBTIMER(""))
	while tTimer'=""
	{
		set pSlots = $$$MaxSignalsByTimer - $get(^OPNLIBTIMER(tTimer),0)
		quit:(pSlots > 0)
		
		set tTimer = $Order(^OPNLIBTIMER(tTimer))
	}
	
	// Returns the Timer PID or 0
	return +tTimer
}

/// Returns a list with the subscriptions attached to a particular pPIDTimer and the Slots free in that timer for new subscriptions
/// First element in the list is $c(0)
ClassMethod SubscriptionsByTimer(pPIDTimer As %Integer = 0, Output pTimerSlots) As %List
{
	#dim tIdx as %String = ""
	#dim tLista as %List=$ListBuild("")
	set pTimerSlots = 0
	quit:pPIDTimer="" tLista
	
	set tIdx = $order(^OPNLIBTIMER(pPIDTimer,"subs",tIdx))
	while (tIdx='"")
	{
		set $List(tLista,*+1)=tIdx
		set tIdx = $order(^OPNLIBTIMER(pPIDTimer,"subs",tIdx))
	}
	
	set pTimerSlots = ($$$MaxNumOfTimers - $LL(tLista)-1)
	quit tLista
}

/// It will subscribe a pPIDSubscriber with a pToken to pPIDTimer or it will create a new one
///  - pPeriod (milliseconds) as the counterback to wake-up the pPIDSubscriber
///  - pEndingMessage to include a final signal message for this pToken
/// It'll return the PID of the timer and also will update pPIDTimer if it's passed by reference
ClassMethod Subscribe(ByRef pPIDTimer As %Integer = 0, pPIDSubscriber As %Integer, pToken As %String = "", pPeriod As %Integer = 1000, pEndingMessage As %String = ":##TIMERCLOSED") As %Integer
{
	#dim tSC as %Status = $$$OK
	#dim tTimer as %SYS.ProcessQuery = ##class(%SYS.ProcessQuery).%OpenId(pPIDTimer)
	#dim tToken as %String= $get(pToken,"unidentified")
	#dim tChild as %Integer = $ZCHILD
	
	// Check if process exists and it's running a timer. If it's not or it reached its max subscriptions' limit initiates one
	if '$IsObject(tTimer)||'(tTimer.Routine [ ..%ClassName(1))||($get(^OPNLIBTIMER(pPIDTimer),0)'< $$$MaxSignalsByTimer)
	{
		// Tries to Start a new Timer. If it fails will return -1
		set pPIDTimer = ..Start()
		
		if pPIDTimer '>0 
		{
			set tSC = 0
		}
	}
	
	if tSC
	{
		return ..SaveSubscription(pPIDTimer,pPIDSubscriber,pToken,pPeriod,pEndingMessage)
	}
	
	return 0
}

ClassMethod SaveSubscription(pPIDTimer As %Integer, pPIDSubscriber As %Integer, pToken As %String, pPeriod As %Integer, pEndingMessage As %String = "") As %Integer
{
	// Save the new subscription
	#dim e as %Exception.SystemException

	try 
	{
		if ..Lock(pPIDTimer,pPIDSubscriber,pToken)
		{
			set ^OPNLIBTIMER(pPIDTimer)=$I(^OPNLIBTIMER(pPIDTimer))
			//transform pPeriod to seconds
			set ^OPNLIBTIMER(pPIDTimer,"subs",pPIDSubscriber,pToken)=(pPeriod/1000)_":"_($now()*100000+$p($now(),",",2))
			set ^OPNLIBTIMER(pPIDTimer,"endMsg",pPIDSubscriber,pToken)=pEndingMessage
			
			// Store reverse idx to find the PICTimer easier: by subscriber+token and by token+subscriber
			set ^OPNLIBTIMERIDX("subs",pPIDSubscriber,pToken,pPIDTimer)=""
			set ^OPNLIBTIMERIDX("token",pToken,pPIDSubscriber,pPIDTimer)=""
			do ..UnLock(pPIDTimer,pPIDSubscriber,pToken)
		}
		else 
		{
			set pPIDTimer = 0
		}
	}
	catch e
	{
		set pPIDTimer = 0
		do ..UnLock(pPIDTimer,pPIDSubscriber,pToken)	
	}
		
	return pPIDTimer
}

ClassMethod UnSubscribe(pPIDTimer As %Integer = "", pPIDSubscriber As %Integer = "", pToken As %String = "", pMessageFinal As %String = "") As %Status
{
	#dim tSC as %Status=$$$OK
	#dim tPIDTimer as %Integer
	#dim tPIDSubscriber as %Integer
	#dim tToken as %String
	
	//return:(pPIDTimer'>0) 0	
	//trace	w !,"Unsubscribe...pPIDTimer/pPIDSubscriber/pToken/pMessageFinal: "_pPIDTimer_" / "_pPIDSubscriber_" / "_pToken_" / "_pMessageFinal
	
	if (pPIDTimer'="")&&(pPIDSubscriber'="")&&(pToken'="")
	{	// Unsubscribe an especific token
		set tSC = ..SendUnSubscribeSignal(pPIDTimer,pPIDSubscriber,pToken,pMessageFinal)
	}
	elseif (pPIDTimer'="")
	{
		// Loop to unsubscribe the token(s) of the subscriber(s). 
		// Cases: pPIDSubscriber = "" and pToken="" --> unsubscribe all for this PIDTimer
		//        pPIDSubscriber '= "" --> unsubscribe all for PIDTimer-PIDSubscriber
		//        pToken '="" --> unsubscribe all for PIDTimer-Token no matter for which PIDSubscriber
		set tPIDSubscriber = $order(^OPNLIBTIMER(pPIDTimer,"subs",""))
		while (tPIDSubscriber'="")
		{
			//if we have to Unsuscribe all:("") or the current subscriber:(tPIDSubscriber), we'll go ahead, otherwise will skip this iteration
			if (pPIDSubscriber="")||(pPIDSubscriber=tPIDSubscriber)
			{
				set tToken = $order(^OPNLIBTIMER(pPIDTimer,"subs",tPIDSubscriber,""))
				while (tToken'="")
				{
					//if we have to Unsuscribe all Tokens:("") or the current subscriber we'll go ahead, otherwise will skip this iteration
					if (pToken="")||(pToken=tToken)
					{
						set tSC = ..SendUnSubscribeSignal(pPIDTimer,tPIDSubscriber,tToken,pMessageFinal)
					}
					set tToken = $order(^OPNLIBTIMER(pPIDTimer,"subs",tPIDSubscriber,tToken))
				}
			}
			// If we reached the subscriber (<>""), stop looping
			if (pPIDSubscriber'="")&&(tPIDSubscriber = pPIDSubscriber) quit
			set tPIDSubscriber = $order(^OPNLIBTIMER(pPIDTimer,"subs",tPIDSubscriber))
		}
	}
	elseif (pPIDSubscriber'="")
	{
		// Unsubscribe all signals from a subscriber not matter wich Timer are assigned to
		set tToken=$order(^OPNLIBTIMERIDX("subs",pPIDSubscriber,""))
		while tToken'=""
		{
			set tPIDTimer = $order(^OPNLIBTIMERIDX("subs",pPIDSubscriber,tToken,""))
			while tPIDTimer'=""
			{
				set tSC = ..SendUnSubscribeSignal(tPIDTimer,pPIDSubscriber,tToken,pMessageFinal)
				set tPIDTimer = $order(^OPNLIBTIMERIDX("subs",pPIDSubscriber,tToken,tPIDTimer))				
			}
			set tToken=$order(^OPNLIBTIMERIDX("subs",pPIDSubscriber,tToken))
		}	
	}
	elseif (pToken'="")
	{
		// Unsubscribe all signals with pToken not matter which Timer and Subscriber belongs to
		// Unsubscribe the pair PIDSuscriber-Token in all the Timers that could be assigned to (this case should not happen)
		set tPIDSubscriber=$order(^OPNLIBTIMERIDX("token",pToken,""))
		while tPIDSubscriber'=""
		{
			set tPIDTimer = $order(^OPNLIBTIMERIDX("token",pToken,tPIDSubscriber,""))
			while tPIDTimer'=""
			{
				
				set tSC = ..SendUnSubscribeSignal(tPIDTimer,tPIDSubscriber,pToken,pMessageFinal)
				set tPIDTimer = $order(^OPNLIBTIMERIDX("token",pToken,tPIDSubscriber,tPIDTimer))
			}
			set tPIDSubscriber=$order(^OPNLIBTIMERIDX("token",pToken,tPIDSubscriber))
		}
	}	
	
	return tSC
}

ClassMethod Lock(pPIDTimer As %Integer, pPIDSubscriber As %Integer, pToken As %String) As %Status
{
	lock +^OPNLIBTIMER(pPIDTimer,pPIDSubscriber,pToken)#"E":5 quit:$TEST 1
	quit 0
}

ClassMethod UnLock(pPIDTimer As %Integer, pPIDSubscriber As %Integer, pToken As %String) As %Status
{
	lock -^OPNLIBTIMER(pPIDTimer,pPIDSubscriber,pToken)#"E":5 quit:$TEST 1
	quit 0
}

ClassMethod DeleteSubscription(pPIDTimer As %Integer, pPIDSubscriber As %Integer, pToken As %String)
{
	//trace		write !,"DeleteSubcription...pPIDTimer/pPIDSubscriber/pToken: "_pPIDTimer_" / "_pPIDSubscriber_" / "_pToken
	if $data(^OPNLIBTIMER(pPIDTimer,"subs",pPIDSubscriber,pToken))
	{
		kill ^OPNLIBTIMER(pPIDTimer,"subs",pPIDSubscriber,pToken)
		kill ^OPNLIBTIMER(pPIDTimer,"endMsg",pPIDSubscriber,pToken)
		kill ^OPNLIBTIMERIDX("subs",pPIDSubscriber,pToken,pPIDTimer)
		kill ^OPNLIBTIMERIDX("token",pToken,pPIDSubscriber,pPIDTimer)

		//trace		write " Before decrement   ^OPNLIBTIMER(pPIDTIMER): "_$get(^OPNLIBTIMER(pPIDTimer),0)		set ^JTSLOG($now(),pPIDTimer_" / "_pPIDSubscriber_" / "_pToken,$get(^OPNLIBTIMER(pPIDTimer),"--"))=""
		
		// Decrement the count of signals associated to this timer
		do $Increment(^OPNLIBTIMER(pPIDTimer),-1)
	}
	//trace	write "    ^OPNLIBTIMER(pPIDTIMER): "_$get(^OPNLIBTIMER(pPIDTimer),0)
	
	quit
}

/// Sends a pMessageFinal to a pIDSubscriber+pToken before drop the subscription
/// The full message will be: pToken concatenated with pMessageFinal
/// By default pMessageFinal = :##TIMERCLOSED
ClassMethod SendUnSubscribeSignal(pPIDTimer As %Integer, pPIDSubscriber As %Integer, pToken As %String, pMessageFinal As %String = "") As %Status
{
	#dim tSC as %Status = $$$OK
	#dim tMsgFinal as %String = ""
	
	//trace w !,"Entry in SendUnSubscribe.."
	
	quit:(pPIDTimer="")||(pPIDSubscriber="")||(pToken="") 0
	if ..Lock(pPIDTimer,pPIDSubscriber,pToken)&&$data(^OPNLIBTIMER(pPIDTimer,"subs",pPIDSubscriber,pToken))
	{
		set:pMessageFinal="" tMsgFinal = $get(^OPNLIBTIMER(pPIDTimer,"endMsg",pPIDSubscriber,pToken),":##TIMERCLOSED")
		do $system.Event.Signal(pPIDSubscriber,pToken_tMsgFinal)
		do ..DeleteSubscription(pPIDTimer,pPIDSubscriber,pToken)
		do ..UnLock(pPIDTimer,pPIDSubscriber,pToken)
	}
	
	quit tSC
}

/// Wrapper for the Init method. It starts the Timer in a JOB 
/// It will return the Timer Process ID or -1 if Timer cannot be initiated (be aware, JOB could success and ..Init() fail at some point)
ClassMethod Start(pTimeOut As %Integer = {$$$TimerDefaultTimeOut}, pMinPeriod As %Integer = 1) As %Integer
{
	#dim tChild as %Integer = $ZCHILD

	// Launch JOB if there is still slot for an additional timer
	job:($get(^OPNLIBTIMER,0)<$$$MaxNumOfTimers) ..Init(pTimeOut,pMinPeriod)
	
	// Verifies that the child process has been created and is running
	if (tChild '= $ZCHILD)&&$IsObject(##class(%SYS.ProcessQuery).%OpenId($ZCHILD))
	{
		return $ZCHILD
	}
	
	return -1
}

/// Launch the timer - if the job number was already used for an old timer, we have to Stop it before (to clean the global)
/// If there is no subscriptions after pTimeOut, it exits
ClassMethod Init(pTimeOut As %Integer = 900, pMinPeriod As %Integer = 1) As %Status
{
	#dim tSC As %Status = $$$OK
	#dim e as %Exception.SystemException
	#dim tTiming, tToken as %String=""
	#dim tPeriod, tWait as %Integer = 0
	#dim tTimeOut as %Integer = pTimeOut
	#dim tPIDTimer as %Integer=$JOB
	#dim tProcIDSubscriber as %Integer=0
	
	quit:$data(^OPNLIBTIMER(tPIDTimer))>0 "0-Timer already exists"
	quit:$get(^OPNLIBTIMER,0)'<$$$MaxNumOfTimers "0-Reached Max number of active Timers"
	quit:pMinPeriod<1 "0-Minimum period shouldn't be shorter than 1 millisecond"
	
	try
	{
		// Update number of timers and initialize a new one... setting root node to >=0 means active
		do $Increment(^OPNLIBTIMER)
		set ^OPNLIBTIMER(tPIDTimer)= 0
			
		while $data(^OPNLIBTIMER(tPIDTimer))>0
		{
			// Wait for subscriptions if none. Waiting time will increment till 10 seconds and restart
			// If the times is waiting for mor than the tTimeOut it dies
			set:tWait>10 tWait=0
			if $data(^OPNLIBTIMER($JOB))'=11
			{
				hang $I(tWait)
				set tTimeOut = tTimeOut - tWait
				if tTimeOut'>0 Throw ##class(%Exception.General).%New("TimeOut",9000,..%ClassName(1)_" ** Init()")
				continue	
			}
			//Back to normal
			set tWait=0
			set tTimeOut = pTimeOut
			
			// Run across subscriptions
			// Expected: ^OPNLIBTIMER(<ThisJOB>,"subs",<PIDofSuscriber>,<token>)="<SignalPeriod>:<LastSent>"
			//     where:
			//           token: is a key set by the subscriber
			//           LastSent: $now()*100000+$piece($now(),",",2) --> 65512,50464.382 would be 6551250464.382
			//                     This way we don't need to care about changing to next day
			//           SignalPeriod: in seconds
			set tProcIDSubscriber = $order(^OPNLIBTIMER(tPIDTimer,"subs",""))
			while (tProcIDSubscriber '="")
			{
				set tTiming = ""
				set tToken = $order(^OPNLIBTIMER(tPIDTimer,"subs",tProcIDSubscriber,""),1,tTiming)
				while (tToken '="")
				{
					set tPeriod = $p(tTiming,":")
					if tPeriod < (pMinPeriod/1000) set tPeriod = pMinPeriod/1000
					
					set tLastSent = $p(tTiming,":",2)
					set tNow = $now()*100000 + $p($now(),",",2)
					
					if (tNow-tLastSent)'< tPeriod
					{
						// Set the LastSent time for this signal
						set $p(^OPNLIBTIMER(tPIDTimer,"subs",tProcIDSubscriber,tToken),":",2)=tNow
						
						//trace	w !,tNow_" ** Subs:"_tProcIDSubscriber_" ** Periodo:"_tPeriod_" ** "_$system.Event.Count(tProcIDSubscriber)
						// Signal. Only will send new signal for wake-up if there is no more signals in queue for that process
						do:$system.Event.Count(tProcIDSubscriber)<2 $system.Event.Signal(tProcIDSubscriber,tToken)
					}
					set tToken = $order(^OPNLIBTIMER(tPIDTimer,"subs",tProcIDSubscriber,tToken),1,tTiming)
				}
				set tProcIDSubscriber = $order(^OPNLIBTIMER(tPIDTimer,"subs",tProcIDSubscriber))
			}
		}
	}
	catch e
	{
		do:(e.Name'="Timeout") ..Stop(tPIDTimer)
		set tSC = e.AsStatus()
	}
	return tSC
}

}
