class BackwardsRunModule {
    static DoubleTapWindowMs := 200

    __New(state, configuration, context, logger) {
        this.State := state
        this.Configuration := configuration
        this.Context := context
        this.Logger := logger
        this.DirectionKeys := ["s", "d", "a"]
        this.DownHotkeyNames := Map()
        this.UpHotkeyNames := Map()
        this.DownCallbacks := Map()
        this.UpCallbacks := Map()
        this.TapResetCallbacks := Map()
        this.KeyPressed := Map()
        this.TapCounts := Map()
        for key in this.DirectionKeys {
            this.DownHotkeyNames[key] := "$*~" key
            this.UpHotkeyNames[key] := "$*~" key " Up"
            this.DownCallbacks[key] := ObjBindMethod(this, "OnDirectionDown", key)
            this.UpCallbacks[key] := ObjBindMethod(this, "OnDirectionUp", key)
            this.TapResetCallbacks[key] := ObjBindMethod(this, "ResetTap", key)
            this.KeyPressed[key] := false
            this.TapCounts[key] := 0
        }

        this.ForwardUpHotkeyName := "$*~w Up"
        this.ForwardUpCallback := ObjBindMethod(this, "OnWUp")
        this.RegisteredKeys := []
        this.ForwardUpRegistered := false
        this.Activated := false
        this.ActiveDirection := ""
        this.DownHeld := false
        this.UpHeld := false
        this.SyntheticWHeld := false
        this.LegacyStarted := false
    }

    Register() {
        if !this.Configuration.Enabled
            return

        keysToRegister := this.Configuration.Mode = "DoubleTap" ? this.DirectionKeys : ["s"]
        HotIfWinActive RobloxContext.WindowSelector
        for key in keysToRegister {
            try {
                Hotkey this.DownHotkeyNames[key], this.DownCallbacks[key], "On"
                Hotkey this.UpHotkeyNames[key], this.UpCallbacks[key], "On"
                this.RegisteredKeys.Push(key)
            } catch as error {
                try Hotkey this.DownHotkeyNames[key], "Off"
                try Hotkey this.UpHotkeyNames[key], "Off"
                this.Logger.Error("Could not register backwards-run direction '" key "': " error.Message)
            }
        }

        if this.Configuration.Mode = "Legacy" {
            try {
                Hotkey this.ForwardUpHotkeyName, this.ForwardUpCallback, "On"
                this.ForwardUpRegistered := true
            } catch as error {
                this.Logger.Error("Could not register the backwards-run W release: " error.Message)
            }
        }
        HotIfWinActive
    }

    Unregister() {
        HotIfWinActive RobloxContext.WindowSelector
        for key in this.RegisteredKeys {
            try Hotkey this.DownHotkeyNames[key], "Off"
            try Hotkey this.UpHotkeyNames[key], "Off"
        }
        if this.ForwardUpRegistered
            try Hotkey this.ForwardUpHotkeyName, "Off"
        HotIfWinActive

        this.RegisteredKeys := []
        this.ForwardUpRegistered := false
        for key in this.DirectionKeys {
            try SetTimer this.TapResetCallbacks[key], 0
            this.KeyPressed[key] := false
        }
        this.ResetTaps()
        this.LegacyStarted := false
        this.ReleaseOutputs()
    }

    Tick() {
        if this.Configuration.Mode = "Legacy" {
            isWPressed := GetKeyState("w", "P")
            if !isWPressed {
                this.LegacyStarted := false
                this.ReleaseOutputs()
            }

            if !GetKeyState("s", "P") {
                this.KeyPressed["s"] := false
                if this.Activated
                    this.CompleteLegacyActivation()
            }
        } else {
            for key in this.DirectionKeys {
                if !GetKeyState(key, "P")
                    this.KeyPressed[key] := false
            }
            if this.Activated
                && this.ActiveDirection != ""
                && !GetKeyState(this.ActiveDirection, "P")
                this.ReleaseOutputs()
        }

        if this.Context.IsActive()
            && this.Configuration.Enabled
            && this.State.Enabled
            && !this.State.TypingPaused
            && !this.State.RemapBusy
            return

        this.ResetTaps()
        this.LegacyStarted := false
        this.ReleaseOutputs()
    }

    OnDirectionDown(key, *) {
        if this.KeyPressed[key]
            return
        this.KeyPressed[key] := true

        if this.Configuration.Mode = "DoubleTap" {
            if !BackwardsRunModule.CanActivate(
                this.State,
                this.Configuration,
                this.Context.IsActive(),
                false,
                false) {
                this.ResetTaps()
                return
            }

            this.TapCounts[key] += 1
            SetTimer this.TapResetCallbacks[key], -BackwardsRunModule.DoubleTapWindowMs
            if this.TapCounts[key] = 2 {
                try SetTimer this.TapResetCallbacks[key], 0
                this.ResetTap(key)
                this.ActivateDoubleTap(key)
            }
            return
        }

        if key != "s"
            return

        isWPressed := GetKeyState("w", "P")
        if !BackwardsRunModule.CanActivate(
            this.State,
            this.Configuration,
            this.Context.IsActive(),
            isWPressed) {
            if !isWPressed
                this.LegacyStarted := false
            this.ReleaseOutputs()
            return
        }

        this.ActivateLegacy()
    }

    OnDirectionUp(key, *) {
        this.KeyPressed[key] := false
        if !this.Activated
            return

        if this.Configuration.Mode = "DoubleTap" {
            if this.ActiveDirection = key
                this.ReleaseOutputs()
            return
        }

        if key = "s"
            this.CompleteLegacyActivation()
    }

    OnWUp(*) {
        if this.Configuration.Mode = "Legacy" {
            this.LegacyStarted := false
            this.ReleaseOutputs()
        }
    }

    ActivateLegacy() {
        this.Activated := true
        this.ActiveDirection := "s"
        try {
            if this.UpHeld {
                SendInput "{Up up}"
                this.UpHeld := false
            }
            if !this.LegacyStarted {
                SendInput "{Up}"
                this.LegacyStarted := true
            }
            this.DownHeld := true
            SendInput "{Down down}"
        } catch as error {
            this.Logger.Error("Legacy backwards run input failed: " error.Message)
            this.LegacyStarted := false
            this.ReleaseOutputs()
        }
    }

    ActivateDoubleTap(direction) {
        this.ReleaseOutputs()
        this.Activated := true
        this.ActiveDirection := direction
        try {
            SendInput "{w}"
            Sleep 10
            this.SyntheticWHeld := true
            SendInput "{w down}"
            Sleep 10
            SendInput "{Up}"
            if direction = "s" {
                SendInput "{Down}"
                this.DownHeld := true
                SendInput "{Down down}"
            }
        } catch as error {
            this.Logger.Error("Double-tap '" direction "' backwards-run input failed: " error.Message)
            this.ReleaseOutputs()
        }
    }

    CompleteLegacyActivation() {
        this.ReleaseOutputs()
        if BackwardsRunModule.CanActivate(
            this.State,
            this.Configuration,
            this.Context.IsActive(),
            GetKeyState("w", "P")) {
            try {
                this.UpHeld := true
                SendInput "{Up down}"
            } catch as error {
                this.Logger.Error("Legacy release input failed: " error.Message)
                this.ReleaseOutputs()
            }
        }
    }

    ReleaseOutputs() {
        this.Activated := false
        this.ActiveDirection := ""
        if this.DownHeld {
            this.DownHeld := false
            try SendInput "{Down up}"
        }

        if this.UpHeld {
            this.UpHeld := false
            try SendInput "{Up up}"
        }

        if this.SyntheticWHeld {
            this.SyntheticWHeld := false
            try SendInput "{w up}"
        }
    }

    ResetTap(key, *) => this.TapCounts[key] := 0

    ResetTaps() {
        for key in this.DirectionKeys
            this.TapCounts[key] := 0
    }

    static CanActivate(state, configuration, isRobloxActive, isWPressed, requireW := true) =>
        configuration.Enabled
        && state.Enabled
        && isRobloxActive
        && (!requireW || isWPressed)
        && !state.TypingPaused
        && !state.RemapBusy
}
