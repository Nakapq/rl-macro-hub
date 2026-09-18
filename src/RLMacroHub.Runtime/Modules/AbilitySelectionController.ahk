class AbilitySelectionController {
    __New(state, configuration, context, autoclicker, logger) {
        this.State := state
        this.Configuration := configuration
        this.Context := context
        this.Autoclicker := autoclicker
        this.Logger := logger
    }

    Select(slot) {
        if !RuntimeConfiguration.IsAbilitySlot(slot)
            return false

        state := this.State
        desiredEnabled := this.Configuration.AutoclickerEnabled[slot]
        if !desiredEnabled
            && !state.AbilityAutoclickEnabled
            && state.SelectedAbilitySlot = slot {
            state.SelectedAbilitySlot := ""
            state.AbilityAutoclickEnabled := true
            this.Logger.Info("Ability slot " slot " was unequipped; autoclicking is allowed.")
            this.ResumeHeldClickIfEligible()
            return true
        }

        state.SelectedAbilitySlot := slot
        if state.AbilityAutoclickEnabled = desiredEnabled
            return false

        state.AbilityAutoclickEnabled := desiredEnabled
        if !desiredEnabled {
            this.Autoclicker.HardStop()
            this.Logger.Info("Ability slot " slot " paused autoclicking.")
            return true
        }

        this.Logger.Info("Ability slot " slot " allowed autoclicking.")
        this.ResumeHeldClickIfEligible()
        return true
    }

    ResumeHeldClickIfEligible() {
        state := this.State
        if state.Enabled && this.Context.IsActive() && GetKeyState("LButton", "P") {
            state.PhysicalLButtonDown := true
            state.LastPhysicalDownTick := A_TickCount - this.Autoclicker.Configuration.HoldThresholdMs
            this.Autoclicker.Start()
        }
    }
}
