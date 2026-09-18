#Requires AutoHotkey v2.0+
#Include "..\Infrastructure\HighResolutionWaiter.ahk"

DllCall("Winmm\timeBeginPeriod", "UInt", 1, "UInt")
frequency := 0
startCounter := 0
currentCounter := 0
DllCall("QueryPerformanceFrequency", "Int64*", &frequency)
DllCall("QueryPerformanceCounter", "Int64*", &startCounter)
nextClickCounter := startCounter
endCounter := startCounter + frequency
clickInterval := 1000.0 / 120.0
scheduledClicks := 0
waiter := HighResolutionWaiter()

while currentCounter < endCounter {
    DllCall("QueryPerformanceCounter", "Int64*", &currentCounter)
    if currentCounter >= nextClickCounter {
        scheduledClicks += 1
        nextClickCounter += frequency * clickInterval / 1000.0
        if currentCounter > nextClickCounter {
            DllCall("QueryPerformanceCounter", "Int64*", &nextClickCounter)
            nextClickCounter += frequency * clickInterval / 1000.0
        }
    }
    waiter.WaitUntil(nextClickCounter, frequency)
}

waiter.Dispose()
DllCall("Winmm\timeEndPeriod", "UInt", 1, "UInt")
FileAppend "scheduled-cps=" scheduledClicks "`n", "*"
