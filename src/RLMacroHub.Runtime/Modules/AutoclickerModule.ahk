class AutoclickerModule {
    __New(state, configuration, context, inventoryPanel, logger) {
        this.State := state
        this.Configuration := configuration
        this.Context := context
        this.InventoryPanel := inventoryPanel
        this.Logger := logger
        this.Waiter := HighResolutionWaiter(logger)
    }

    Tick(*) {
        state := this.State
        if !this.Context.IsActive() {
            this.HardStop()
            return
        }

        if state.PhysicalLButtonDown && !GetKeyState("LButton", "P") {
            state.PhysicalLButtonDown := false
            state.LastPhysicalDownTick := 0
            this.HardStop()
            return
        }

        if state.PhysicalLButtonDown && !state.FastClickLoopRunning
            this.Start()
    }

    Start(*) {
        state := this.State
        if state.FastClickLoopRunning || !this.CanAutoClick()
            return

        state.FastClickLoopRunning := true
        try {
            clickInterval := 1000.0 / this.Configuration.MaximumCps
            frequency := 0
            nextClickCounter := 0
            currentCounter := 0
            DllCall("QueryPerformanceFrequency", "Int64*", &frequency)
            DllCall("QueryPerformanceCounter", "Int64*", &nextClickCounter)

            while state.PhysicalLButtonDown && GetKeyState("LButton", "P") {
                if !this.CanAutoClick()
                    break

                DllCall("QueryPerformanceCounter", "Int64*", &currentCounter)
                if currentCounter >= nextClickCounter {
                    Click()
                    state.ClickCountTotal += 1
                    state.ClickCountSample += 1
                    nextClickCounter += frequency * clickInterval / 1000.0

                    ; Never replay missed clicks as a catch-up burst.
                    if currentCounter > nextClickCounter {
                        DllCall("QueryPerformanceCounter", "Int64*", &nextClickCounter)
                        nextClickCounter += frequency * clickInterval / 1000.0
                    }
                }

                this.Waiter.WaitUntil(nextClickCounter, frequency)
            }
        } catch as error {
            this.Logger.Error("Autoclick loop failed: " error.Message)
        } finally {
            state.FastClickLoopRunning := false
        }
    }

    CanAutoClick() {
        return RuntimePolicy.CanAutoClick(
            this.State,
            this.Configuration,
            this.Context.IsActive(),
            GetKeyState("LButton", "P"),
            this.InventoryPanel.IsPointerBlocked())
    }

    UpdateCps(*) {
        state := this.State
        now := A_TickCount
        elapsed := now - state.CpsSampleTick
        if elapsed <= 0
            return

        state.CurrentCps := Round(state.ClickCountSample * 1000.0 / elapsed)
        state.ClickCountSample := 0
        state.CpsSampleTick := now
    }

    HardStop() {
        state := this.State
        if !GetKeyState("LButton", "P") {
            state.PhysicalLButtonDown := false
            state.LastPhysicalDownTick := 0
        }
    }

    Dispose() {
        this.Waiter.Dispose()
    }
}
