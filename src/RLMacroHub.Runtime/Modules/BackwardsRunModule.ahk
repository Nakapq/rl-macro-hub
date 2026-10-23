class BackwardsRunModule {
    static DoubleTapWindowMs := 200
    static WalkingResumeDelayMs := 30

    __New(state, configuration, context, logger) {
        this.State := state
        this.Configuration := configuration
        this.Context := context
        this.Logger := logger
        this.DirectionKeys := ["w", "a", "s", "d"]
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
        this.WalkingResumeSkipS := false
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
        this.RecoveryDirection := ""
        this.RecoveryTapTick := 0
        this.Restarting := false
    }

    Register() {
        if !this.Configuration.Enabled
            return

        keysToRegister := this.Configuration.Mode = "MultiDirectional"
            ? this.DirectionKeys
            : ["s"]
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
        ; Stop before reconciling directions: a missed release must not trigger
        ; a fresh arrow-down after focus loss, chat, or disablement.
        if !this.Context.IsActive()
            || !this.Configuration.Enabled
            || !this.State.Enabled
            || this.State.TypingPaused {
            try SetTimer this.WalkingResumeCallback, 0
            this.ResetTaps()
            this.LegacyStarted := false
            this.ReleaseOutputs()
            for key in this.DirectionKeys {
                if !this.IsDirectionHeld(key)
                    this.KeyPressed[key] := false
            }
            return
        }

        if this.Configuration.Mode = "Legacy" {
            isWPressed := this.IsDirectionHeld("w")
            if !isWPressed {
                this.LegacyStarted := false
                this.ReleaseOutputs()
            }

            if !this.IsDirectionHeld("s") {
                this.KeyPressed["s"] := false
                if this.Activated
                    this.CompleteLegacyActivation()
            }
        } else {
            this.MaintainMultiDirectionalSession()
        }
    }

    OnDirectionDown(key, *) {
        if this.KeyPressed[key] || this.Restarting
            return

        if this.Configuration.Mode = "MultiDirectional" {
            ; The current press is already physically down. Check the previous
            ; tracked keys before including it, rather than waiting for Tick.
            previousDirectionHeld := false
            for direction in this.DirectionKeys {
                if this.KeyPressed[direction] && this.IsDirectionHeld(direction)
                    previousDirectionHeld := true
            }
            if this.Activated && !previousDirectionHeld {
                this.ResetTaps()
                this.ReleaseOutputs(true)
            }
            for direction in this.DirectionKeys {
                if this.KeyPressed[direction] && !this.IsDirectionHeld(direction)
                    this.OnDirectionUp(direction)
            }
        }
        this.KeyPressed[key] := true

        if this.Configuration.Mode = "MultiDirectional" {
            if key = "w" {
                useWAsArrowRebind := BackwardsRunModule.ShouldUseWAsArrowRebind(
                    this.Activated,
                    this.SessionAxis,
                    this.SyntheticWHeld,
                    this.IsDirectionHeld("s"))
                this.WPressForwarded := !useWAsArrowRebind
                if this.WPressForwarded
                    this.SendMovementInput("{Blind}{w down}")
                else if this.SessionAxis = "horizontal" {
                    ; Keep the lateral session's synthetic W foundation intact.
                    ; Physical W controls forward movement through Up Arrow.
                    this.HoldDirectionalArrow("w")
                }
            }

            if this.Activated {
                if BackwardsRunModule.AxisForDirection(key) = this.SessionAxis {
                    if key != this.ActiveDirection
                        this.SwitchMultiDirectionalDirection(key)
                    this.TryRecoverDirection(key)
                } else {
                    this.RecoveryDirection := ""
                }
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

        if key != "s"
            return

        isWPressed := this.IsDirectionHeld("w")
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
                try this.SendMovementInput("{Blind}{w up}")
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
                && this.IsDirectionHeld("w") {
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
            if this.IsDirectionHeld(oppositeDirection)
                this.SwitchMultiDirectionalDirection(oppositeDirection)
            else {
                this.ActiveDirection := ""
                if this.SessionAxis = "vertical"
                    this.ReleaseDirectionalArrow()
            }
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

    ResetRun(*) {
        if this.Configuration.Mode != "MultiDirectional"
            || !this.Configuration.Enabled || !this.State.Enabled
            || !this.Context.IsActive() || this.State.TypingPaused
            return
        Critical "On"
        try {
            this.CancelWalkingResume()
            this.ResetTaps()
            this.LegacyStarted := false
            ; Keep real held movement, but discard all macro arrows and run
            ; ownership. A fresh double tap is required to start again.
            this.ReleaseOutputs(true)
        } finally {
            Critical "Off"
        }
    }

    TryRecoverDirection(key) {
        if !BackwardsRunModule.CanActivate(this.State, this.Configuration,
            this.Context.IsActive(), false, false) {
            this.RecoveryDirection := ""
            return
        }
        now := this.CurrentTick()
        if this.RecoveryDirection = key
            && now - this.RecoveryTapTick <= BackwardsRunModule.DoubleTapWindowMs {
            this.ActivateMultiDirectional(key, true)
            return
        }
        this.RecoveryDirection := key
        this.RecoveryTapTick := now
    }

    CurrentTick() => A_TickCount

    CancelWalkingResume() {
        SetTimer this.WalkingResumeCallback, 0
        this.WalkingResumeSkipS := false
    }

    OnRunCancel(skipS := false, *) {
        if this.Configuration.Mode != "MultiDirectional"
            return

        this.ResetToWalkingState()
        this.ScheduleWalkingResume(skipS)
    }

    PrepareDash() {
        if this.Configuration.Mode != "MultiDirectional"
            || !this.Activated
            return ""

        aHeld := this.IsDirectionHeld("a")
        sHeld := this.IsDirectionHeld("s")
        if !this.Configuration.Enabled
            || !this.State.Enabled
            || this.State.TypingPaused
            || !this.Context.IsActive()
            || (!aHeld && !sHeld) {
            this.OnRunCancel(sHeld)
            return ""
        }

        this.ResetTaps()
        this.LegacyStarted := false
        ; Do not transfer synthetic W back to a held physical W here: W wins
        ; over A/S when Roblox selects a dash direction. Keep an existing
        ; backward arrow continuously held until the physical S release.
        this.ReleaseOutputs(false, sHeld && this.ArrowHeld = "Down")
        this.WPressForwarded := false
        this.ScheduleWalkingResume(sHeld)
        ; The coordinator sends this prefix and Q-down in one ordered batch.
        ; S is already physically held and is never released or re-pressed.
        ; Other physical directions resume after the existing walking delay.
        return "{w up}" (aHeld ? "{a down}" : "")
    }

    IsDirectionHeld(key) => GetKeyState(key, "P")

    SendMovementInput(keys) => SendInput(keys)

    ScheduleWalkingResume(skipS := false) {
        this.WalkingResumeSkipS := skipS
        SetTimer this.WalkingResumeCallback, -BackwardsRunModule.WalkingResumeDelayMs
    }

    ResetToWalkingState() {
        walkingArrowDirection := ""
        if this.Configuration.Mode = "MultiDirectional"
            && (this.Activated || this.ArrowHeld != "") {
            walkingArrowDirection := BackwardsRunModule.WalkingArrowDirection(
                this.ArrowHeld,
                this.IsDirectionHeld("w"),
                this.IsDirectionHeld("s"))
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
            if key = "s" && this.WalkingResumeSkipS
                continue
            if !this.IsDirectionHeld(key)
                continue

            try this.SendMovementInput("{Blind}{" key " down}")
            if key = "w" && this.Configuration.Mode = "MultiDirectional"
                this.WPressForwarded := true
        }
    }

    ActivateLegacy() {
        this.SetActivated(true)
        this.ActiveDirection := "s"
        try {
            if this.UpHeld {
                this.SendMovementInput("{Up up}")
                this.UpHeld := false
            }
            if !this.LegacyStarted {
                this.SendMovementInput("{Up}")
                this.LegacyStarted := true
            }
            this.DownHeld := true
            this.SendMovementInput("{Down down}")
        } catch as error {
            this.Logger.Error("Legacy backwards run input failed: " error.Message)
            this.LegacyStarted := false
            this.ReleaseOutputs()
        }
    }

    ActivateMultiDirectional(direction, restart := false) {
        if this.Restarting
            return
        Critical "On"
        this.Restarting := true
        try {
            this.CancelWalkingResume()
            this.ReleaseOutputs()
            this.ResetTaps()
            this.SetActivated(true)
            this.ActiveDirection := direction
            this.SessionAxis := BackwardsRunModule.AxisForDirection(direction)

            ; W's second physical press starts the native mana run. The other
            ; directions reproduce that setup with a synthetic W tap and hold.
            if direction != "w" || restart {
                if restart
                    this.SendMovementInput("{w up}")
                this.SendMovementInput("{w}")
                Sleep 10
                this.SyntheticWHeld := direction != "w"
                this.SendMovementInput("{w down}")
                if direction = "w"
                    this.WPressForwarded := true
            }

            Sleep 10
            this.SendMovementInput("{Up}")

            if this.SessionAxis = "vertical" {
                if direction = "s"
                    this.SendMovementInput("{Down}")
                this.HoldDirectionalArrow(direction)
            } else {
                oppositeDirection := BackwardsRunModule.OppositeDirection(direction)
                if this.IsDirectionHeld(oppositeDirection) {
                    this.SendMovementInput("{" oppositeDirection " up}")
                    this.SuppressedDirection := oppositeDirection
                }
            }
        } catch as error {
            this.Logger.Error("Multi-directional '" direction "' run input failed: " error.Message)
            this.ReleaseOutputs()
        } finally {
            this.Restarting := false
            Critical "Off"
        }
    }

    MaintainMultiDirectionalSession() {
        for key in this.DirectionKeys {
            ; Recover the full ownership/arrow transition when a key-up event
            ; was missed, including walking arrows retained after cancellation.
            if this.KeyPressed[key] && !this.IsDirectionHeld(key)
                this.OnDirectionUp(key)
        }

        if !this.Activated
            return

        if this.SessionAxis = ""
            return this.ReleaseOutputs()

        if !this.HasHeldDirection()
            return this.ReleaseOutputs()

        if this.ActiveDirection = ""
            return

        if this.IsDirectionHeld(this.ActiveDirection)
            return

        oppositeDirection := BackwardsRunModule.OppositeDirection(this.ActiveDirection)
        if this.IsDirectionHeld(oppositeDirection)
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
                    this.SendMovementInput("{" direction " down}")
                    this.SuppressedDirection := ""
                }

                if previousDirection != "" && this.IsDirectionHeld(previousDirection) {
                    this.SendMovementInput("{" previousDirection " up}")
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
            this.SendMovementInput("{" this.ArrowHeld " up}")

        this.ArrowHeld := arrow
        this.SendMovementInput("{" arrow " down}")
    }

    ReleaseDirectionalArrow() {
        if this.ArrowHeld = ""
            return

        arrow := this.ArrowHeld
        this.ArrowHeld := ""
        try this.SendMovementInput("{" arrow " up}")
    }

    HasHeldDirection() => BackwardsRunModule.AnyDirectionHeld(
        this.IsDirectionHeld("w"),
        this.IsDirectionHeld("a"),
        this.IsDirectionHeld("s"),
        this.IsDirectionHeld("d"))

    CompleteLegacyActivation() {
        this.ReleaseOutputs()
        if BackwardsRunModule.CanActivate(
            this.State,
            this.Configuration,
            this.Context.IsActive(),
            this.IsDirectionHeld("w")) {
            try {
                this.UpHeld := true
                this.SendMovementInput("{Up down}")
            } catch as error {
                this.Logger.Error("Legacy release input failed: " error.Message)
                this.ReleaseOutputs()
            }
        }
    }

    ReleaseOutputs(preservePhysicalMovement := false, preserveDirectionalArrow := false) {
        this.RecoveryDirection := ""
        this.RecoveryTapTick := 0
        this.SetActivated(false)
        this.ActiveDirection := ""
        this.SessionAxis := ""
        if !preserveDirectionalArrow
            this.ReleaseDirectionalArrow()

        if this.SuppressedDirection != "" {
            suppressedDirection := this.SuppressedDirection
            this.SuppressedDirection := ""
            if this.IsDirectionHeld(suppressedDirection)
                try this.SendMovementInput("{" suppressedDirection " down}")
        }

        if this.DownHeld {
            this.DownHeld := false
            try this.SendMovementInput("{Down up}")
        }

        if this.UpHeld {
            this.UpHeld := false
            try this.SendMovementInput("{Up up}")
        }

        if this.SyntheticWHeld {
            this.SyntheticWHeld := false
            if BackwardsRunModule.ShouldReturnWToPhysicalInput(
                preservePhysicalMovement,
                this.IsDirectionHeld("w")) {
                ; G has already returned Roblox to walking. Keep the existing
                ; logical W-down and let the physical W-up release it normally.
                this.WPressForwarded := true
            } else {
                try this.SendMovementInput("{w up}")
            }
        }
    }

    ResetTap(key, *) => this.TapCounts[key] := 0

    SetActivated(activated) {
        this.Activated := activated
        this.State.BackwardsRunActive := activated
    }

    ResetTaps() {
        this.RecoveryDirection := ""
        this.RecoveryTapTick := 0
        for key in this.DirectionKeys {
            try SetTimer this.TapResetCallbacks[key], 0
            this.TapCounts[key] := 0
        }
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
