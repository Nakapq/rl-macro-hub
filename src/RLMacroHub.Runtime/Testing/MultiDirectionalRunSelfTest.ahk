; Exercise the real state machine with fake physical keys and captured output.
; No hooks, window capture, or foreground input is needed.
class MultiDirectionalRunSelfTest {
    static Run() {
        this.TestMouseClicksDuringAutoclickHold()
        this.TestHeldSDash()
        this.TestWalkingDash()
        this.TestRunRecovery()
        this.TestRunResetBinding()
        for direction in ["w", "a", "s", "d"] {
            run := this.CreateRun()
            this.DoubleTap(run, direction)
            this.Assert(run.Activated && run.State.BackwardsRunActive, direction " double tap starts a run")
            this.Assert(run.ActiveDirection = direction, "activation selects " direction)
            run.Press(direction)
            this.Assert(run.ActiveDirection = direction, "key repeat leaves direction unchanged")
            run.Release(direction)
            this.AssertReleased(run, "final " direction " release")
            run.Unregister()
        }

        for direction in ["w", "a", "s", "d"] {
            run := this.CreateRun()
            opposite := BackwardsRunModule.OppositeDirection(direction)
            this.DoubleTap(run, direction)
            run.Press(opposite)
            this.Assert(run.ActiveDirection = opposite, "opposite press takes priority")
            run.Release(opposite)
            this.Assert(run.Activated && run.ActiveDirection = direction, "opposite release falls back to held original")
            run.Release(direction)
            this.AssertReleased(run, "opposite transition cleanup")
            run.Unregister()
        }

        run := this.CreateRun()
        this.DoubleTap(run, "w")
        run.Press("a")
        run.Release("w")
        this.Assert(run.Activated && run.SyntheticWHeld, "released native W transfers to a remaining direction")
        run.Release("a")
        this.AssertReleased(run, "transferred W final release")
        run.Unregister()

        run := this.CreateRun()
        this.DoubleTap(run, "s")
        run.Press("w")
        run.Release("s")
        this.Assert(run.WPressForwarded && !run.SyntheticWHeld && run.ArrowHeld = "Up", "S-to-W transfers ownership back to physical W")
        run.Release("w")
        this.AssertReleased(run, "S-to-W final release")
        run.Unregister()

        run := this.CreateRun()
        this.DoubleTap(run, "a")
        run.Press("w")
        this.Assert(run.ArrowHeld = "Up" && !run.WPressForwarded, "lateral W is an arrow rebind")
        run.HeldKeys.Delete("w") ; Simulate a missed key-up callback.
        run.Tick()
        this.Assert(run.Activated && run.SyntheticWHeld && run.ArrowHeld = "", "missed lateral W release removes only the forward arrow")
        run.Release("a")
        this.AssertReleased(run, "lateral missed-release cleanup")
        run.Unregister()

        run := this.CreateRun()
        this.DoubleTap(run, "w")
        run.Press("d")
        run.HeldKeys.Delete("w")
        run.Tick()
        this.Assert(run.Activated && run.SyntheticWHeld && !run.WPressForwarded, "missed native W release transfers ownership")
        run.Release("d")
        this.AssertReleased(run, "missed native W final release")
        run.Unregister()

        for direction in ["w", "s"] {
            run := this.CreateRun()
            this.DoubleTap(run, direction)
            run.OnRunCancel()
            this.Assert(!run.Activated && run.ArrowHeld != "", "cancel preserves the held walking arrow")
            run.HeldKeys.Delete(direction)
            run.Tick()
            this.AssertReleased(run, "cancelled walking arrow missed key-up")
            run.ResumeWalkingMovement()
            this.AssertReleased(run, "late walking resume after key release")
            run.Unregister()
        }

        for reason in ["focus", "chat", "runtime", "module", "shutdown"] {
            run := this.CreateRun()
            this.DoubleTap(run, "s")
            run.Press("w")
            ; An unobserved W release would normally fall back to S. Cleanup
            ; must run first, without starting fresh movement in another app.
            run.HeldKeys.Delete("w")
            run.Sent := []
            switch reason {
                case "focus": run.Context.Active := false
                case "chat": run.State.TypingPaused := true
                case "runtime": run.State.Enabled := false
                case "module": run.Configuration.Enabled := false
            }
            if reason = "shutdown"
                run.Unregister()
            else
                run.Tick()
            this.AssertReleased(run, reason " cleanup")
            for keys in run.Sent
                this.Assert(!InStr(keys, " down}"), reason " cleanup must not start new movement")
            run.Unregister()
        }

        run := this.CreateRun()
        run.Press("s")
        run.Release("s")
        run.ResetTap("s") ; Deterministically simulate expiry of the tap window.
        run.Press("s")
        this.Assert(!run.Activated, "expired taps cannot activate")
        run.Release("s")
        run.State.RemapBusy := true
        this.DoubleTap(run, "a")
        this.Assert(!run.Activated, "remap blocks new activation")
        run.Release("a")
        run.State.RemapBusy := false
        this.DoubleTap(run, "a")
        run.State.RemapBusy := true
        run.Tick()
        this.Assert(run.Activated, "remap does not interrupt an existing run")
        run.Release("a")
        run.Unregister()

        run := this.CreateRun()
        this.DoubleTap(run, "a")
        run.OnRunCancel()
        run.Release("a")
        this.DoubleTap(run, "s")
        run.Sent := []
        run.ResumeWalkingMovement()
        this.Assert(run.Activated && run.Sent.Length = 0, "late walking resume cannot overwrite a newly activated run")
        run.Release("s")
        run.Unregister()
        FileAppend "Multi-directional movement regressions passed.`n", "*"
    }

    static TestRunRecovery() {
        for direction in ["w", "a", "s", "d"] {
            run := this.CreateRun()
            this.DoubleTap(run, direction)
            keepAlive := BackwardsRunModule.AxisForDirection(direction) = "vertical" ? "a" : "s"
            run.Press(keepAlive)
            run.Release(direction)
            run.Press(direction)
            run.Press(direction) ; OS repeat, without a physical release.
            this.Assert(run.RecoveryCount = 0, "held key repeat must not recover")
            run.Release(direction)
            run.ScheduleWalkingResume()
            run.Clock += 100
            run.Press(direction)
            this.Assert(run.RecoveryCount = 1 && run.ActivationCount = 2
                && run.Activated && run.ActiveDirection = direction,
                "same-direction double tap restarts " direction " exactly once")
            this.Assert(!run.ResumePending, "recovery cancels pending walking restoration")
            run.Release(direction)
            run.Release(keepAlive)
            this.AssertReleased(run, direction " recovery final release")
            run.Unregister()
        }

        run := this.CreateRun()
        this.DoubleTap(run, "w")
        this.DoubleTap(run, "a")
        this.Assert(run.RecoveryCount = 0 && run.SessionAxis = "vertical", "cross-axis taps cannot replace the run")
        run.Release("a")
        run.Press("s")
        this.Assert(run.ActiveDirection = "s" && run.RecoveryCount = 0, "single opposite press switches without restart")
        run.Release("s")
        run.Clock += 201
        run.Press("s")
        this.Assert(run.RecoveryCount = 0, "slow taps cannot recover")
        run.Release("s")
        run.Clock += 100
        run.Press("s")
        this.Assert(run.RecoveryCount = 1 && run.ActiveDirection = "s", "recovery follows the requested current direction, not initial W")
        run.Release("s")
        run.Release("w")
        this.AssertReleased(run, "opposite recovery cleanup")
        run.Unregister()

        for reason in ["chat", "focus", "disabled", "remap"] {
            run := this.CreateRun()
            this.DoubleTap(run, "s")
            run.Press("a")
            run.Release("s")
            run.Press("s")
            run.Release("s")
            switch reason {
                case "chat": run.State.TypingPaused := true
                case "focus": run.Context.Active := false
                case "disabled": run.State.Enabled := false
                case "remap": run.State.RemapBusy := true
            }
            run.Press("s")
            this.Assert(run.RecoveryCount = 0, reason " blocks recovery")
            run.Unregister()
        }

        run := this.CreateRun()
        this.DoubleTap(run, "s")
        run.HeldKeys.Delete("s") ; Missed S-up, then a new press before Tick.
        run.Press("a")
        this.Assert(!run.Activated && run.TapCounts["a"] = 1,
            "a new press after all old keys were released must clear the stale session")
        run.Release("a")
        run.Press("a")
        this.Assert(run.Activated && run.SessionAxis = "horizontal", "fast fresh double tap can activate another axis")
        run.Release("a")
        this.AssertReleased(run, "fresh axis cleanup")
        run.Unregister()
    }

    static TestRunResetBinding() {
        configuration := RuntimeConfiguration.CreateDefault()
        this.Assert(configuration.BackwardsRun.ResetHotkey = "", "reset key defaults unbound")
        this.Assert(RuntimeConfiguration.IsValidRunResetHotkey("F8", configuration), "unused reset key is accepted")
        for invalid in ["w", "q", "LButton", "XButton1", "F25", "^F8"]
            this.Assert(!RuntimeConfiguration.IsValidRunResetHotkey(invalid, configuration), "invalid or conflicting reset is rejected: " invalid)
        configuration.Keybinds.Bindings.Push({Source: "F8", Target: "2"})
        this.Assert(!RuntimeConfiguration.IsValidRunResetHotkey("F8", configuration), "reset must not replace a remap")

        run := this.CreateRun()
        configuration := RuntimeConfiguration.CreateDefault()
        input := RunResetRegistrationFixture(run.State, configuration, run.Context,
            "", "", "", "", run, RuntimeSelfTestLogger())
        input.Register()
        this.Assert(!input.Captured.Has("$*~F8"), "unbound reset registers no key")
        configuration.BackwardsRun.ResetHotkey := "F8"
        input.Register()
        this.Assert(input.Captured.Has("$*~F8"), "configured reset registers its observer")
        this.DoubleTap(run, "s")
        run.ScheduleWalkingResume()
        run.TapCounts["a"] := 1
        input.Captured["$*~F8"].Call()
        this.AssertReleased(run, "explicit reset")
        this.Assert(!run.ResumePending && run.TapCounts["a"] = 0, "reset clears pending timers and taps")
        run.Press("s")
        this.Assert(!run.Activated, "held-key repeat after reset cannot reactivate")
        run.Release("s")
        this.DoubleTap(run, "d")
        this.Assert(run.Activated && run.ActiveDirection = "d", "reset permits a fresh run on another axis")
        run.State.TypingPaused := true
        run.ResetRun()
        this.Assert(run.Activated, "reset binding is inactive while typing")
        run.State.TypingPaused := false
        run.Release("d")
        run.Unregister()
    }

    static TestHeldSDash() {
        for running in [false, true] {
            configuration := RuntimeConfiguration.CreateDefault()
            run := this.CreateRun()
            if running
                this.DoubleTap(run, "s")
            else
                run.Press("s")
            input := HeldSDashTestInput(run.State, configuration, run.Context,
                "", "", "", "", run, RuntimeSelfTestLogger())
            run.Sent := []
            input.OnDashDown()
            this.Assert(!run.Activated && !run.State.BackwardsRunActive, "S dash ends macro run state")
            for keys in run.Sent
                this.Assert(!InStr(keys, "{s down}") && !InStr(keys, "{s up}")
                    && !InStr(keys, "{Down up}"), "Q-down must never interrupt or re-press backward movement")
            this.Assert(run.ArrowHeld = (running ? "Down" : ""),
                "S dash preserves an existing backward arrow without creating one while walking")
            run.Sent := []
            input.OnDashUp()
            this.Assert(run.Sent.Length = 1 && run.Sent[1] = "{Blind}{q up}",
                "Q-up must leave S and its existing arrow hold untouched")
            run.Sent := []
            if run.ResumeScheduleCount > 0
                run.ResumeWalkingMovement()
            this.Assert(run.Sent.Length = 0,
                "dash timer must not re-press the continuously held S key")
            this.Assert(run.ResumeScheduleCount = (running ? 1 : 0),
                "Q must schedule movement restoration only when leaving an active run")
            run.Release("s")
            this.AssertReleased(run, "physical S release after dash")
            run.Sent := []
            input.OnDashUp()
            run.ResumeWalkingMovement()
            this.Assert(run.Sent.Length = 1 && run.Sent[1] = "{Blind}{q up}",
                "releasing S before Q prevents both immediate and delayed S restoration")
            run.Unregister()
        }

        for reason in ["focus", "chat", "runtime", "module", "legacy", "newrun"] {
            configuration := RuntimeConfiguration.CreateDefault()
            run := this.CreateRun()
            run.Press("s")
            switch reason {
                case "focus": run.Context.Active := false
                case "chat": run.State.TypingPaused := true
                case "runtime": run.State.Enabled := false
                case "module": run.Configuration.Enabled := false
                case "legacy": run.Configuration.Mode := "Legacy"
                case "newrun": run.SetActivated(true)
            }
            input := HeldSDashTestInput(run.State, configuration, run.Context,
                "", "", "", "", run, RuntimeSelfTestLogger())
            run.Sent := []
            input.OnDashUp()
            this.Assert(run.Sent.Length = 1 && run.Sent[1] = "{Blind}{q up}",
                "Q release must not restore S during " reason)
            run.Unregister()
        }
    }

    static TestWalkingDash() {
        for heldKeys in [["a"], ["s"], ["a", "s"], ["w", "a"], ["w", "s"]] {
            configuration := RuntimeConfiguration.CreateDefault()
            run := this.CreateRun()
            for key in heldKeys
                run.Press(key)
            input := HeldSDashTestInput(run.State, configuration, run.Context,
                "", "", "", "", run, RuntimeSelfTestLogger())
            pendingTaps := run.TapCounts["a"] + run.TapCounts["s"]
            ; Also cover a walking arrow retained from an earlier cancellation.
            if run.IsDirectionHeld("s")
                run.HoldDirectionalArrow("s")
            arrow := run.ArrowHeld
            run.Sent := []
            input.OnDashDown()
            input.OnDashDown() ; Q repeat must also stay ordinary outside a run.
            input.OnDashUp()
            this.Assert(run.Sent.Length = 3
                && run.Sent[1] = "{Blind}{q down}"
                && run.Sent[2] = "{Blind}{q down}"
                && run.Sent[3] = "{Blind}{q up}",
                "walking A/S dash must emit only Q, with no directional input")
            this.Assert(run.ResumeScheduleCount = 0 && run.ArrowHeld = arrow
                && run.TapCounts["a"] + run.TapCounts["s"] = pendingTaps,
                "walking Q must leave arrows, pending taps, and movement timers untouched")
            for key in heldKeys
                run.Release(key)
            this.AssertReleased(run, "walking dash cleanup")
            run.Unregister()
        }
    }

    static TestMouseClicksDuringAutoclickHold() {
        for direction in ["w", "a", "s", "d"] {
            configuration := RuntimeConfiguration.CreateDefault()
            configuration.AbilitySlots.AutoclickerEnabled["2"] := false
            run := this.CreateRun()
            autoclicker := RuntimeSelfTestAutoclicker(configuration.Autoclicker)
            gate := RuntimeSelfTestGateMacro()
            ; Inactive context avoids reading real mouse state when unequipping.
            selection := AbilitySelectionController(run.State, configuration.AbilitySlots,
                RuntimeSelfTestContext(), autoclicker, RuntimeSelfTestLogger())
            input := InputCoordinator(run.State, configuration, run.Context, "",
                selection, gate, autoclicker, run, RuntimeSelfTestLogger())
            this.DoubleTap(run, direction)
            selection.Select("2")
            this.Assert(!run.State.AbilityAutoclickEnabled, "paused ability enters autoclick HOLD")
            run.Sent := []
            run.State.TypingPaused := true
            input.OnPhysicalLeftDown()
            this.Assert(run.Activated && run.State.BackwardsRunActive
                && run.ActiveDirection = direction && run.Sent.Length = 0,
                "M1 during HOLD preserves " direction " run and movement output")
            this.Assert(run.State.PhysicalLButtonDown && !run.State.TypingPaused
                && gate.CancelCaptureCount = 1 && autoclicker.StartCount = 1,
                "HOLD click still tracks physical input and clears chat capture")
            input.OnPhysicalLeftUp()
            this.Assert(run.Activated && !run.State.PhysicalLButtonDown
                && run.State.LastPhysicalDownTick = 0,
                "HOLD mouse release preserves run and clears mouse tracking")

            selection.Select("2")
            this.Assert(run.State.AbilityAutoclickEnabled, "unequipping leaves HOLD")
            input.OnPhysicalLeftDown()
            this.Assert(!run.Activated && !run.State.BackwardsRunActive,
                "M1 after leaving HOLD cancels the run")
            input.OnPhysicalLeftUp()
            run.Release(direction)
            this.AssertReleased(run, "M1 normal cancellation cleanup")

            this.DoubleTap(run, direction)
            selection.Select("2")
            run.Sent := []
            startCount := autoclicker.StartCount
            input.MouseRunCancelCallback.Call()
            this.Assert(run.Activated && run.State.BackwardsRunActive
                && run.ActiveDirection = direction && run.Sent.Length = 0,
                "M2 during HOLD preserves " direction " run and movement output")
            this.Assert(!run.State.PhysicalLButtonDown && autoclicker.StartCount = startCount,
                "M2 must not change M1 tracking or start autoclicking")
            selection.Select("2")
            input.MouseRunCancelCallback.Call()
            this.Assert(!run.Activated && !run.State.BackwardsRunActive,
                "M2 after leaving HOLD cancels the run")
            run.Release(direction)
            this.AssertReleased(run, "M2 normal cancellation cleanup")

            this.DoubleTap(run, direction)
            selection.Select("2")
            input.OnRunCancelInput()
            this.Assert(!run.Activated, "G/V cancellation still works during HOLD")
            run.Release(direction)
            this.AssertReleased(run, "other cancellation cleanup during HOLD")
            run.Unregister()
        }
    }

    static CreateRun() => MultiDirectionalRunFixture(RuntimeState(true),
        RuntimeConfiguration.CreateDefault().BackwardsRun,
        MultiDirectionalRunTestContext(), MultiDirectionalRunTestLogger())

    static DoubleTap(run, key) {
        run.Press(key)
        run.Release(key)
        run.Press(key)
    }

    static AssertReleased(run, reason) {
        this.Assert(!run.Activated && !run.State.BackwardsRunActive
            && !run.SyntheticWHeld && run.ArrowHeld = ""
            && !run.UpHeld && !run.DownHeld && run.SuppressedDirection = "",
            reason " must release macro output and HUD state")
        for key in ["w", "Up", "Down"]
            this.Assert(!run.OutputHeld.Get(key, false), reason " must emit the matching " key " release")
    }

    static Assert(condition, message) => RuntimeSelfTest.Assert(condition, message)
}

class MultiDirectionalRunFixture extends BackwardsRunModule {
    __New(args*) {
        super.__New(args*)
        this.HeldKeys := Map()
        this.Sent := []
        this.OutputHeld := Map()
        this.ResumeScheduleCount := 0
        this.ResumePending := false
        this.Clock := 1000
        this.ActivationCount := 0
        this.RecoveryCount := 0
    }

    IsDirectionHeld(key) => this.HeldKeys.Get(key, false)

    CurrentTick() => this.Clock

    ActivateMultiDirectional(direction, restart := false) {
        this.ActivationCount += 1
        if restart
            this.RecoveryCount += 1
        super.ActivateMultiDirectional(direction, restart)
    }

    CancelWalkingResume() {
        this.ResumePending := false
        super.CancelWalkingResume()
    }

    SendMovementInput(keys) {
        this.Sent.Push(keys)
        position := 1
        while position := RegExMatch(keys, "\{(w|Up|Down) (down|up)\}", &match, position) {
            this.OutputHeld[match[1]] := match[2] = "down"
            position += match.Len
        }
    }

    ScheduleWalkingResume(skipS := false) {
        this.ResumeScheduleCount += 1
        this.ResumePending := true
        this.WalkingResumeSkipS := skipS
        ; The test explicitly advances this callback, without a live timer.
    }

    Press(key) {
        this.HeldKeys[key] := true
        this.OnDirectionDown(key)
    }

    Release(key) {
        this.HeldKeys.Delete(key)
        this.OnDirectionUp(key)
    }
}

class MultiDirectionalRunTestContext {
    Active := true
    IsActive() => this.Active
}

class HeldSDashTestInput extends InputCoordinator {
    SendDashInput(keys) => this.BackwardsRun.Sent.Push(keys)
}

class MultiDirectionalRunTestLogger {
    Error(message) => RuntimeSelfTest.Assert(false, message)
}

class RunResetRegistrationFixture extends InputCoordinator {
    Captured := Map()
    RegisterOne(name, callback) => this.Captured[name] := callback
}
