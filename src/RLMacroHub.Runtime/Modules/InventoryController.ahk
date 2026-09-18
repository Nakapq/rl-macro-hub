class InventoryController {
    __New(state, configuration, context, logger) {
        this.State := state
        this.Configuration := configuration
        this.Context := context
        this.Logger := logger
        this.Autoclicker := ""
    }

    AttachAutoclicker(autoclicker) {
        this.Autoclicker := autoclicker
    }

    Toggle() {
        state := this.State
        state.InventoryOpen := !state.InventoryOpen

        if state.InventoryOpen {
            this.Logger.Info("Inventory state opened; autoclicking remains active outside the inventory panel.")
            return
        }

        if this.Configuration.Autoclicker.ForceEnabledWhenInventoryCloses
            state.Enabled := true

        this.Logger.Info("Inventory state closed; runtime enabled=" state.Enabled ".")
        if this.Context.IsActive() && GetKeyState("LButton", "P") {
            state.PhysicalLButtonDown := true
            state.LastPhysicalDownTick := A_TickCount - this.Configuration.Autoclicker.HoldThresholdMs
            if IsObject(this.Autoclicker)
                this.Autoclicker.Start()
        }
    }

    static IsInventoryKey(key) {
        normalized := Trim(key)
        return normalized = "``"
            || normalized = "~"
            || normalized = "SC029"
            || normalized = "vkC0"
            || normalized = "vkC0sc029"
    }
}
