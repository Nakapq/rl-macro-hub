class InputCoordinator {
    __New(state, configuration, context, inventory, abilitySelection, gateMacro, autoclicker, logger) {
        this.State := state
        this.Configuration := configuration
        this.Context := context
        this.Inventory := inventory
        this.AbilitySelection := abilitySelection
        this.GateMacro := gateMacro
        this.Autoclicker := autoclicker
        this.Logger := logger
        this.RegisteredHotkeys := []
        this.AbilityKeysDown := Map()
        this.ToggleHotkey := ""
        this.ChatStartCallback := ObjBindMethod(this, "OnChatStart")
        this.ChatEndCallback := ObjBindMethod(this, "OnChatEnd")
        this.EscapeCallback := ObjBindMethod(this, "OnEscape")
        this.InventoryCallback := ObjBindMethod(this, "OnInventoryKey")
        this.LeftDownCallback := ObjBindMethod(this, "OnPhysicalLeftDown")
        this.LeftUpCallback := ObjBindMethod(this, "OnPhysicalLeftUp")
        this.AbilityCallback := ObjBindMethod(this, "OnAbilityKey")
        this.AbilityUpCallback := ObjBindMethod(this, "OnAbilityKeyUp")
        this.ToggleCallback := ObjBindMethod(this, "OnToggle")
    }

    Register() {
        HotIfWinActive RobloxContext.WindowSelector
        this.RegisterOne("~/", this.ChatStartCallback)
        this.RegisterOne("$*Enter", this.ChatEndCallback)
        this.RegisterOne("~Esc", this.EscapeCallback)
        this.RegisterOne("*~SC029", this.InventoryCallback)
        this.RegisterOne("$*~LButton", this.LeftDownCallback)
        this.RegisterOne("$*~LButton Up", this.LeftUpCallback)
        for key in RuntimeConfiguration.AbilitySlotKeys {
            this.RegisterOne("*~" key, this.AbilityCallback)
            this.RegisterOne("*~" key " Up", this.AbilityUpCallback)
        }

        this.ToggleHotkey := "$*" this.Configuration.General.ToggleHotkey
        this.RegisterOne(this.ToggleHotkey, this.ToggleCallback)
        HotIfWinActive
    }

    RegisterOne(hotkeyName, callback) {
        try {
            Hotkey hotkeyName, callback, "On"
            this.RegisteredHotkeys.Push(hotkeyName)
        } catch as error {
            this.Logger.Error("Could not register hotkey '" hotkeyName "': " error.Message)
        }
    }

    Unregister() {
        HotIfWinActive RobloxContext.WindowSelector
        for hotkeyName in this.RegisteredHotkeys {
            try Hotkey hotkeyName, "Off"
        }
        HotIfWinActive
        this.RegisteredHotkeys := []
        this.AbilityKeysDown := Map()
        this.GateMacro.CancelCapture()
    }

    OnChatStart(*) {
        this.State.TypingPaused := true
        this.Autoclicker.HardStop()
        this.GateMacro.BeginChatCapture()
    }

    OnChatEnd(*) {
        this.GateMacro.SubmitCapture()
        SendEvent "{Blind}{Enter}"
        if this.State.TypingPaused
            this.State.TypingPaused := false
    }

    OnEscape(*) {
        this.GateMacro.CancelCapture()
        this.State.TypingPaused := false
        this.Autoclicker.HardStop()
    }

    OnInventoryKey(*) {
        this.Inventory.Toggle()
        KeyWait "SC029"
    }

    OnPhysicalLeftDown(*) {
        ; A click can move focus away from chat. Do not let that capture survive
        ; into ordinary gameplay even if Roblox never exposes the focus change.
        this.GateMacro.CancelCapture()
        this.State.TypingPaused := false
        this.State.PhysicalLButtonDown := true
        this.State.LastPhysicalDownTick := A_TickCount
        this.Autoclicker.Start()
    }

    OnPhysicalLeftUp(*) {
        this.State.PhysicalLButtonDown := false
        this.State.LastPhysicalDownTick := 0
        this.Autoclicker.HardStop()
    }

    OnAbilityKey(thisHotkey) {
        pressedKey := InputCoordinator.AbilityKeyFromHotkey(thisHotkey)
        if this.AbilityKeysDown.Get(pressedKey, false)
            return

        this.AbilityKeysDown[pressedKey] := true
        if this.State.TypingPaused || this.State.RemapBusy
            return

        this.AbilitySelection.Select(pressedKey)
    }

    OnAbilityKeyUp(thisHotkey) {
        releasedKey := InputCoordinator.AbilityKeyFromHotkey(thisHotkey)
        this.AbilityKeysDown[releasedKey] := false
    }

    static AbilityKeyFromHotkey(hotkeyName) => RegExReplace(
        RegExReplace(hotkeyName, "i) Up$"),
        "^[*~$#!^+<>]+")

    OnToggle(*) {
        this.State.Enabled := !this.State.Enabled
        if !this.State.Enabled {
            this.Autoclicker.HardStop()
            this.Logger.Info("Runtime toggled off.")
            return
        }

        if this.Context.IsActive() && GetKeyState("LButton", "P") {
            this.State.PhysicalLButtonDown := true
            this.State.LastPhysicalDownTick := A_TickCount - this.Configuration.Autoclicker.HoldThresholdMs
        }
        this.Logger.Info("Runtime toggled on.")
    }
}
