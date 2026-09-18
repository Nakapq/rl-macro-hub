class KeybindModule {
    __New(state, configuration, context, inventory, abilitySelection, logger) {
        this.State := state
        this.Configuration := configuration
        this.Context := context
        this.Inventory := inventory
        this.AbilitySelection := abilitySelection
        this.Logger := logger
        this.Registrations := []
    }

    Register() {
        if !this.Configuration.Enabled
            return

        HotIfWinActive RobloxContext.WindowSelector
        for binding in this.Configuration.Bindings {
            hotkeyName := "$*" binding.Source
            callback := ObjBindMethod(this, "Handle", binding)
            try {
                Hotkey hotkeyName, callback, "On"
                this.Registrations.Push({ Name: hotkeyName, Callback: callback })
            } catch as error {
                this.Logger.Error("Could not register binding '" binding.Source "' -> '" binding.Target "': " error.Message)
            }
        }
        HotIfWinActive
    }

    Unregister() {
        HotIfWinActive RobloxContext.WindowSelector
        for registration in this.Registrations {
            try Hotkey registration.Name, "Off"
        }
        HotIfWinActive
        this.Registrations := []
    }

    Handle(binding, *) {
        source := binding.Source
        target := binding.Target
        if this.MacroKeybindsDisabled(source) {
            this.SendOriginalKeyPassthrough(source)
            return
        }

        isControlTrigger := this.IsControl(source)
        isAltTrigger := this.IsAlt(source)
        isShiftTrigger := this.IsShift(source)
        isWinTrigger := this.IsWin(source)

        if !isControlTrigger && GetKeyState("Ctrl", "P") {
            this.SendOriginalKey(source)
            return
        }
        if !isAltTrigger && GetKeyState("Alt", "P") {
            this.SendOriginalKeyPassthrough(source)
            return
        }
        if !isShiftTrigger && GetKeyState("Shift", "P") {
            this.SendOriginalKeyPassthrough(source)
            return
        }
        if !isWinTrigger && (GetKeyState("LWin", "P") || GetKeyState("RWin", "P")) {
            this.SendOriginalKeyPassthrough(source)
            return
        }

        wasHolding := GetKeyState("LButton", "P")
        wasEnabled := this.State.Enabled
        this.State.RemapBusy := true

        try {
            if InventoryController.IsInventoryKey(target)
                this.Inventory.Toggle()
            if RuntimeConfiguration.IsAbilitySlot(target)
                this.AbilitySelection.Select(target)

            if isControlTrigger {
                SendEvent "{Ctrl up}"
                Sleep 10
                this.SendTarget(target, source)
            } else if isAltTrigger {
                SendEvent "{Alt up}"
                Sleep 10
                this.SendTarget(target, source)
            } else if isShiftTrigger {
                SendEvent "{Shift up}"
                Sleep 10
                this.SendTarget(target, source)
            } else {
                this.SendGameKey(target)
            }
        } catch as error {
            this.Logger.Error("Binding '" source "' -> '" target "' failed: " error.Message)
        } finally {
            Sleep 20
            this.State.RemapBusy := false
            if wasEnabled && wasHolding && this.Context.IsActive() {
                this.State.PhysicalLButtonDown := true
                this.State.LastPhysicalDownTick := A_TickCount - this.Inventory.Configuration.Autoclicker.HoldThresholdMs
            } else if !GetKeyState("LButton", "P") {
                this.State.PhysicalLButtonDown := false
                this.State.LastPhysicalDownTick := 0
            }
        }
    }

    SendTarget(target, source) {
        if this.ShouldHoldRemap(source, target)
            this.SendGameKeyHeldUntilReleased(target, source)
        else
            this.SendGameKey(target)
    }

    MacroKeybindsDisabled(source) {
        if !this.Configuration.Enabled || !this.State.Enabled || !this.Context.IsActive()
            return true
        if this.State.TypingPaused || this.State.RemapBusy
            return true
        if !this.IsAlt(source) && GetKeyState("Alt", "P")
            return true
        if !this.IsControl(source) && GetKeyState("Ctrl", "P")
            return true
        if !this.IsShift(source) && GetKeyState("Shift", "P")
            return true
        return false
    }

    SendOriginalKeyPassthrough(key) {
        if this.IsAlt(key) || this.IsControl(key) || this.IsShift(key) || this.IsWin(key) {
            SendEvent "{" key " down}"
            KeyWait key
            SendEvent "{" key " up}"
            return
        }
        this.SendOriginalKey(key)
    }

    SendOriginalKey(key) {
        SendEvent "{Blind}{" key "}"
    }

    SendGameKey(key) {
        SendEvent "{" key " down}"
        Sleep 12
        SendEvent "{" key " up}"
    }

    SendGameKeyHeldUntilReleased(target, source) {
        SendEvent "{" target " down}"
        KeyWait source
        SendEvent "{" target " up}"
    }

    ShouldHoldRemap(source, target) {
        return (this.IsShift(source) || this.IsControl(source) || this.IsAlt(source)) && target = "g"
    }

    IsControl(key) => key = "LControl" || key = "RControl" || key = "Control"
    IsAlt(key) => key = "LAlt" || key = "RAlt" || key = "Alt"
    IsShift(key) => key = "LShift" || key = "RShift" || key = "Shift"
    IsWin(key) => key = "LWin" || key = "RWin"
}
