Class OPNEx.IoT.Timer.Basic Extends %RegisteredObject
{

ClassMethod Test(pTimeOut As %Integer = 20)
{
    #dim tStop, tSlots as %Integer=0
    #dim tTimer as %Integer = ##class(OPNLib.IoT.Timer).GetTimerFree(.tSlots)
    #dim tStart as %Integer = $piece($h,",",2)
    #dim tEndMsg as %String = "##CLOSING"
    #dim tPeriodMillisec as %Integer = 1000
    #dim tToken as %String = "BASICTOKEN001"
    #dim tToken2 as %String = "BASICTOKEN002"

    do $system.Event.Clear($JOB)
    // Define & Launch the Timer(s). tTimer will store the PID of the timer process. It can be passed by reference
    // If tTimer already exist and has free slots, it will be used, if not, a new one will be launched.
    set tTimer = ##class(OPNLib.IoT.Timer).Subscribe(.tTimer,$JOB,tToken,tPeriodMillisec,tEndMsg)
    set tTimer = ##class(OPNLib.IoT.Timer).Subscribe(.tTimer,$JOB,tToken2,4*tPeriodMillisec,tEndMsg)

    // Wait and act when receives something... till tStop is true
    while (tTimer>0)&&'tStop
    {
        set tListOfData = $system.Event.WaitMsg()

        set tData = $List(tListOfData,2)
        //Here we could execute a task depending on the data/token
        write !,"Token received....["_$zt($piece($h,",",2))_"]: "_tData

        //If we receive EndMsg or reach TimeOut then Stop test
        if (tData[tEndMsg)||(($p($h,",",2)-tStart) > pTimeOut)
        {
            set tStop = 1
            do ##class(OPNLib.IoT.Timer).UnSubscribe(,$JOB)
        }
    }

    quit
}

ClassMethod StopTest()
{
	// Assumes no other JOB is executing under this TokenID. It will unsubscribe all Timer entries with this pTokenID
	do ##class(OPNLib.IoT.Timer).UnSubscribe(,,"BASICTOKEN001")
    do ##class(OPNLib.IoT.Timer).UnSubscribe(,,"BASICTOKEN002")
    quit
}

}
