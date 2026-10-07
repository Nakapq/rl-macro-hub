class BackwardsRunModule {
    static DoubleTapWindowMs := 200
    static WalkingResumeDelayMs := 30

    __New(state, configuration, context, logger) {
        this.State := state
        this.Configuration := configuration
        this.Context := context
        this.Logger := logger
        this.DirectionKeys := ["w", "a", "s", "d"]
        this.DoubleTapDirectionKeys := ["s", "d", "a"]
        this.DownHotkeyNames := Map()
        this.UpHotkeyNames := Map()
        this.DownCallbacks := Map()
        this.UpCallbacks := Map()
        this.TapResetCallbacks := Map()
        this.KeyPressed := Map()
        this.TapCounts := Map()
        for key in this.DirectionKeys {
            this.DownHotkeyNames[key] := key = "w" ? "$*w" : "$*~" key
            this.UpHotkeyNames[key] := key = "w" ? "$*w Up" : "$*~" key " Up"
            this.DownCallbacks[key] := ObjBindMethod(this, "OnDirectionDown", key)
            this.UpCallbacks[key] := ObjBindMethod(this, "OnDirectionUp", key)
            this.TapResetCallbacks[key] := ObjBindMethod(this, "ResetTap", key)
            this.KeyPressed[key] := false
            this.TapCounts[key] := 0
        }

        this.ForwardUpHotkeyName := "$*~w Up"
        this.ForwardUpCallback := ObjBindMethod(this, "OnWUp")
        this.WalkingResumeCallback := ObjBindMethod(this, "ResumeWalkingMovement")
        this.RegisteredKeys := []
        this.ForwardUpRegistered := false
        this.Activated := false
        this.State.BackwardsRunActive := false
        this.ActiveDirection := ""
        this.SessionAxis := ""
        this.ArrowHeld := ""
        this.SuppressedDirection := ""
        this.DownHeld := false
        this.UpHeld := false
        this.SyntheticWHeld := false
        this.WPressForwarded := false
        this.LegacyStarted := false
    }

    Register() {
        if !this.Configuration.Enabled
            return

        keysToRegister := this.Configuration.Mode = "MultiDirectional"
            ? this.DirectionKeys
            : (this.Configuration.Mode = "DoubleTap" ? this.DoubleTapDirectionKeys : ["s"])
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
        try SetTimer this.WalkingResumeCallback, 0
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
        } else if this.Configuration.Mode = "MultiDirectional" {
            this.MaintainMultiDirectionalSession()
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
            return

        this.ResetTaps()
        this.LegacyStarted := false
        this.ReleaseOutputs()
    }

    OnDirectionDown(key, *) {
        if this.KeyPressed[key]
            return
        this.KeyPressed[key] := true

        if this.Configuration.Mode = "MultiDirectional" {
            if key = "w" {
                useWAsArrowRebind := BackwardsRunModule.ShouldUseWAsArrowRebind(
                    this.Activated,
                    this.SessionAxis,
                    this.SyntheticWHeld,
                    GetKeyState("s", "P"))
                this.WPressForwarded := !useWAsArrowRebind
                if this.WPressForwarded
                    SendInput "{Blind}{w down}"
                else if this.SessionAxis = "horizontal" {
                    ; Keep the lateral session's synthetic W foundation intact.
                    ; Physical W controls forward movement through Up Arrow.
                    this.HoldDirectionalArrow("w")
                }
            }

            if this.Activated {
                if BackwardsRunModule.AxisForDirection(key) = this.SessionAxis
                    && key != this.ActiveDirection
                    this.SwitchMultiDirectionalDirection(key)
                return
            }

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
                this.ActivateMultiDirectional(key)
            }
            return
        }

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
        directionsRemainHeld := false
        if this.Configuration.Mode = "MultiDirectional" && this.Activated
            directionsRemainHeld := this.HasHeldDirection()

        wPressWasForwarded := false
        if key = "w" && this.Configuration.Mode = "MultiDirectional" {
            wPressWasForwarded := this.WPressForwarded
            this.WPressForwarded := false
            if BackwardsRunModule.ShouldTransferForwardedW(
                this.Activated,
                wPressWasForwarded,
                directionsRemainHeld) {
                ; Keep the existing logical W-down uninterrupted. Ownership
                ; changes from the released physical key to the session, which
                ; will emit the matching W-up when the final WASD key is released.
                this.SyntheticWHeld := true
            } else if wPressWasForwarded {
                try SendInput "{Blind}{w up}"
            }
        }

        if !this.Activated {
            if key = "w" && this.ArrowHeld = "Up"
                this.ReleaseDirectionalArrow()
            else if key = "s" && this.ArrowHeld = "Down"
                this.ReleaseDirectionalArrow()
            return
        }

        if this.Configuration.Mode = "MultiDirectional" {
            if key = "s"
                && this.SessionAxis = "vertical"
                && this.SyntheticWHeld
                && GetKeyState("w", "P") {
                ; W was consumed as an arrow rebind while S owned the run.
                ; Transfer the existing logical W-down to that physical press
                ; so its eventual key-up is forwarded exactly once.
                this.SyntheticWHeld := false
                this.WPressForwarded := true
            }

            if !directionsRemainHeld {
                this.ReleaseOutputs()
                return
            }

            if key = "w" && this.SessionAxis = "horizontal" {
                if this.ArrowHeld = "Up"
                    this.ReleaseDirectionalArrow()
                return
            }

            if key = this.SuppressedDirection
                this.SuppressedDirection := ""

            if BackwardsRunModule.AxisForDirection(key) != this.SessionAxis
                return

            if this.ActiveDirection != key
                return

            oppositeDirection := BackwardsRunModule.OppositeDirection(key)
            if GetKeyState(oppositeDirection, "P")
                this.SwitchMultiDirectionalDirection(oppositeDirection)
            else {
                this.ActiveDirection := ""
                if this.SessionAxis = "vertical"
                    this.ReleaseDirectionalArrow()
            }
            return
        }

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

    OnRunCancel(*) {
        this.ResetToWalkingState()
        SetTimer this.WalkingResumeCallback, -BackwardsRunModule.WalkingResumeDelayMs
    }

    ResetToWalkingState() {
        walkingArrowDirection := ""
        if this.Configuration.Mode = "MultiDirectional"
            && (this.Activated || this.ArrowHeld != "") {
            walkingArrowDirection := BackwardsRunModule.WalkingArrowDirection(
                this.ArrowHeld,
                GetKeyState("w", "P"),
                GetKeyState("s", "P"))
        }

        this.ResetTaps()
        this.LegacyStarted := false
        this.ReleaseOutputs(true, walkingArrowDirection != "")
        if walkingArrowDirection != ""
            this.HoldDirectionalArrow(walkingArrowDirection)
    }

    ResumeWalkingMovement(*) {
        if this.Activated
            return
        if !this.Configuration.Enabled
            || !this.State.Enabled
            || !this.Context.IsActive()
            || this.State.TypingPaused
            return

        for key in this.DirectionKeys {
            if !GetKeyState(key, "P")
                continue

            try SendInput "{Blind}{" key " down}"
            if key = "w" && this.Configuration.Mode = "MultiDirectional"
                this.WPressForwarded := true
        }
    }

    ActivateLegacy() {
        this.SetActivated(true)
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
        this.SetActivated(true)
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

    ActivateMultiDirectional(direction) {
        Critical "On"
        try {
            this.ReleaseOutputs()
            this.ResetTaps()
            this.SetActivated(true)
            this.ActiveDirection := direction
            this.SessionAxis := BackwardsRunModule.AxisForDirection(direction)

            ; W's second physical press starts the native mana run. The other
            ; directions reproduce that setup with a synthetic W tap and hold.
            if direction != "w" {
                SendInput "{w}"
                Sleep 10
                this.SyntheticWHeld := true
                SendInput "{w down}"
            }

            Sleep 10
            SendInput "{Up}"

            if this.SessionAxis = "vertical" {
                if direction = "s"
                    SendInput "{Down}"
                this.HoldDirectionalArrow(direction)
            } else {
                oppositeDirection := BackwardsRunModule.OppositeDirection(direction)
                if GetKeyState(oppositeDirection, "P") {
                    SendInput "{" oppositeDirection " up}"
                    this.SuppressedDirection := oppositeDirection
                }
            }
        } catch as error {
            this.Logger.Error("Multi-directional '" direction "' run input failed: " error.Message)
            this.ReleaseOutputs()
        } finally {
            Critical "Off"
        }
    }

    MaintainMultiDirectionalSession() {
        for key in this.DirectionKeys {
            if !GetKeyState(key, "P")
                this.KeyPressed[key] := false
        }

        if !this.Activated
            return

        if this.SessionAxis = ""
            return this.ReleaseOutputs()

        if !this.HasHeldDirection()
            return this.ReleaseOutputs()

        if this.ActiveDirection = ""
            return

        if GetKeyState(this.ActiveDirection, "P")
            return

        oppositeDirection := BackwardsRunModule.OppositeDirection(this.ActiveDirection)
        if GetKeyState(oppositeDirection, "P")
            this.SwitchMultiDirectionalDirection(oppositeDirection)
        else {
            this.ActiveDirection := ""
            if this.SessionAxis = "vertical"
                this.ReleaseDirectionalArrow()
        }
    }

    SwitchMultiDirectionalDirection(direction) {
        if !this.Activated
            || BackwardsRunModule.AxisForDirection(direction) != this.SessionAxis
            || direction = this.ActiveDirection
            return

        Critical "On"
        try {
            if this.SessionAxis = "vertical" {
                this.HoldDirectionalArrow(direction)
            } else {
                previousDirection := this.ActiveDirection
                if this.SuppressedDirection = direction {
                    SendInput "{" direction " down}"
                    this.SuppressedDirection := ""
                }

                if previousDirection != "" && GetKeyState(previousDirection, "P") {
                    SendInput "{" previousDirection " up}"
                    this.SuppressedDirection := previousDirection
                }
            }
            this.ActiveDirection := direction
        } catch as error {
            this.Logger.Error("Multi-directional transition to '" direction "' failed: " error.Message)
            this.ReleaseOutputs()
        } finally {
            Critical "Off"
        }
    }

    HoldDirectionalArrow(direction) {
        arrow := direction = "w" ? "Up" : "Down"
        if this.ArrowHeld = arrow
            return

        if this.ArrowHeld != ""
            SendInput "{" this.ArrowHeld " up}"

        this.ArrowHeld := arrow
        SendInput "{" arrow " down}"
    }

    ReleaseDirectionalArrow() {
        if this.ArrowHeld = ""
            return

        arrow := this.ArrowHeld
        this.ArrowHeld := ""
        try SendInput "{" arrow " up}"
    }

    HasHeldDirection() => BackwardsRunModule.AnyDirectionHeld(
        GetKeyState("w", "P"),
        GetKeyState("a", "P"),
        GetKeyState("s", "P"),
        GetKeyState("d", "P"))

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

    ReleaseOutputs(preservePhysicalMovement := false, preserveDirectionalArrow := false) {
        this.SetActivated(false)
        this.ActiveDirection := ""
        this.SessionAxis := ""
        if !preserveDirectionalArrow
            this.ReleaseDirectionalArrow()

        if this.SuppressedDirection != "" {
            suppressedDirection := this.SuppressedDirection
            this.SuppressedDirection := ""
            if GetKeyState(suppressedDirection, "P")
                try SendInput "{" suppressedDirection " down}"
        }

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
            if BackwardsRunModule.ShouldReturnWToPhysicalInput(
                preservePhysicalMovement,
                GetKeyState("w", "P")) {
                ; G has already returned Roblox to walking. Keep the existing
                ; logical W-down and let the physical W-up release it normally.
                this.WPressForwarded := true
            } else {
                try SendInput "{w up}"
            }
        }
    }

    ResetTap(key, *) => this.TapCounts[key] := 0

    SetActivated(activated) {
        this.Activated := activated
        this.State.BackwardsRunActive := activated
    }

    ResetTaps() {
        for key in this.DirectionKeys
            this.TapCounts[key] := 0
    }

    static AxisForDirection(direction) => direction = "w" || direction = "s"
        ? "vertical"
        : (direction = "a" || direction = "d" ? "horizontal" : "")

    static OppositeDirection(direction) {
        switch direction {
            case "w": return "s"
            case "s": return "w"
            case "a": return "d"
            case "d": return "a"
            default: return ""
        }
    }

    static AnyDirectionHeld(wHeld, aHeld, sHeld, dHeld) =>
        wHeld || aHeld || sHeld || dHeld

    static ShouldTransferForwardedW(activated, wPressWasForwarded, directionRemainsHeld) =>
        activated && wPressWasForwarded && directionRemainsHeld

    static ShouldReturnWToPhysicalInput(preservePhysicalMovement, physicalWHeld) =>
        preservePhysicalMovement && physicalWHeld

    static WalkingArrowDirection(arrowHeld, wHeld, sHeld) {
        if arrowHeld = "Up" && wHeld
            return "w"
        if arrowHeld = "Down" && sHeld
            return "s"
        if wHeld
            return "w"
        if sHeld
            return "s"
        return ""
    }

    static ShouldUseWAsArrowRebind(activated, sessionAxis, syntheticWHeld, isSHeld) =>
        activated
        && (sessionAxis = "horizontal"
            || (sessionAxis = "vertical"
                && syntheticWHeld
                && isSHeld))

    static CanActivate(state, configuration, isRobloxActive, isWPressed, requireW := true) =>
        configuration.Enabled
        && state.Enabled
        && isRobloxActive
        && (!requireW || isWPressed)
        && !state.TypingPaused
        && !state.RemapBusy
}
