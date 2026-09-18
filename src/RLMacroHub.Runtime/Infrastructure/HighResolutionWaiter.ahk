class HighResolutionWaiter {
    static TimerAllAccess := 0x1F0003
    static HighResolutionFlag := 0x2

    __New(logger := "") {
        this.Logger := logger
        this.DueTime := Buffer(8, 0)
        this.HasLoggedFailure := false
        this.Handle := DllCall(
            "CreateWaitableTimerExW",
            "Ptr", 0,
            "Ptr", 0,
            "UInt", HighResolutionWaiter.HighResolutionFlag,
            "UInt", HighResolutionWaiter.TimerAllAccess,
            "Ptr")

        if !this.Handle {
            this.Handle := DllCall(
                "CreateWaitableTimerW",
                "Ptr", 0,
                "Int", false,
                "Ptr", 0,
                "Ptr")
        }

        if !this.Handle
            this.LogFailure("Could not create a precision waitable timer; falling back to scheduler yields.")
    }

    WaitUntil(targetCounter, frequency) {
        currentCounter := 0
        DllCall("QueryPerformanceCounter", "Int64*", &currentCounter)
        remainingTicks := targetCounter - currentCounter
        if remainingTicks <= 0
            return

        if !this.Handle {
            Sleep 0
            return
        }

        relativeHundredNanoseconds := -Max(1, Floor(remainingTicks * 10000000.0 / frequency))
        NumPut("Int64", relativeHundredNanoseconds, this.DueTime, 0)
        timerSet := DllCall(
            "SetWaitableTimer",
            "Ptr", this.Handle,
            "Ptr", this.DueTime,
            "Int", 0,
            "Ptr", 0,
            "Ptr", 0,
            "Int", false,
            "Int")
        if !timerSet {
            this.LogFailure("The precision waitable timer could not be armed; falling back to scheduler yields.")
            Sleep 0
            return
        }

        waitResult := DllCall("WaitForSingleObject", "Ptr", this.Handle, "UInt", 0xFFFFFFFF, "UInt")
        if waitResult != 0
            this.LogFailure("The precision timer wait failed with result " waitResult ".")
    }

    Dispose() {
        if this.Handle {
            DllCall("CloseHandle", "Ptr", this.Handle, "Int")
            this.Handle := 0
        }
    }

    LogFailure(message) {
        if this.HasLoggedFailure
            return

        this.HasLoggedFailure := true
        if IsObject(this.Logger)
            this.Logger.Warn(message)
    }
}
