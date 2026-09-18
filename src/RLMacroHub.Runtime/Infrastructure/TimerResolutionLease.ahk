class TimerResolutionLease {
    __New(periodMilliseconds, logger) {
        this.PeriodMilliseconds := periodMilliseconds
        this.Logger := logger
        this.IsAcquired := false
    }

    Acquire() {
        if this.IsAcquired
            return true

        result := DllCall("Winmm\timeBeginPeriod", "UInt", this.PeriodMilliseconds, "UInt")
        this.IsAcquired := result = 0
        if !this.IsAcquired
            this.Logger.Warn("timeBeginPeriod failed with code " result ".")
        return this.IsAcquired
    }

    Dispose() {
        if !this.IsAcquired
            return

        DllCall("Winmm\timeEndPeriod", "UInt", this.PeriodMilliseconds, "UInt")
        this.IsAcquired := false
    }
}
