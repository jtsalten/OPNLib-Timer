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
    #dim tToken2 as %String = "BACISTOKEN002"

    do $system.Event.Clear($JOB)
    set tTimer = ##class(OPNLib.IoT.Timer).Subscribe(.tTimer,$JOB,tToken,tPeriodMillisec,tEndMsg)
    set tTimer = ##class(OPNLib.IoT.Timer).Subscribe(.tTimer,$JOB,tToken2,4*tPeriodMillisec,tEndMsg)

    while (tTimer>0)&&'tStop
    {
        set tListOfData = $system.Event.WaitMsg()

        set tData = $List(tListOfData,2)
        //Here we could execute a task depending on the data/token
        write !,"Token received....["_$piece($h,",",2)_"]: "_tData

        if (tData[tEndMsg)||(($p($h,",",2)-tStart) > pTimeOut)
        {
            set tStop = 1
            do ##class(OPNLib.IoT.Timer).UnSubscribe(,$JOB)
        }
    }

    quit
}

}
