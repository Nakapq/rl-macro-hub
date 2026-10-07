class RuntimeState {
    __New(enabled := true) {
        this.Enabled := enabled
        this.AbilityAutoclickEnabled := true
        this.SelectedAbilitySlot := ""
        this.TypingPaused := false
        this.InventoryOpen := false
        this.RemapBusy := false
        this.PhysicalLButtonDown := false
        this.LastPhysicalDownTick := 0
        this.FastClickLoopRunning := false
        this.ClickCountTotal := 0
        this.ClickCountSample := 0
        this.CpsSampleTick := A_TickCount
        this.CurrentCps := 0
        this.BackwardsRunActive := false
    }
}
