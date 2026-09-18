class RuntimePolicy {
    static CanAutoClick(state, configuration, isRobloxActive, isPhysicalLeftDown, isPointerOverInventoryPanel := false, nowTick := unset) {
        if !isRobloxActive || !state.Enabled || !state.AbilityAutoclickEnabled || state.TypingPaused || state.RemapBusy
            return false

        if state.InventoryOpen && isPointerOverInventoryPanel
            return false

        if !state.PhysicalLButtonDown || !isPhysicalLeftDown
            return false

        currentTick := IsSet(nowTick) ? nowTick : A_TickCount
        return (currentTick - state.LastPhysicalDownTick) >= configuration.HoldThresholdMs
    }
}
