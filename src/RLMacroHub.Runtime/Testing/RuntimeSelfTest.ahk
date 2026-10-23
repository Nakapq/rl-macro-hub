class RuntimeSelfTest {
    static Run() {
        configuration := RuntimeConfiguration.CreateDefault()
        state := RuntimeState(true)
        state.PhysicalLButtonDown := true
        state.LastPhysicalDownTick := 100
        this.Assert(!state.BackwardsRunActive, "backwards-run HUD state should default off")
        this.Assert(StatusOverlay.TotalHeight(39) = 58, "the running HUD row should sit directly below the 39-pixel autoclicker HUD")

        this.Assert(
            RuntimePolicy.CanAutoClick(state, configuration.Autoclicker, true, true, false, 130),
            "eligible held click should be allowed")

        state.InventoryOpen := true
        this.Assert(
            RuntimePolicy.CanAutoClick(state, configuration.Autoclicker, true, true, false, 130),
            "inventory alone should not suppress autoclicking")

        this.Assert(
            !RuntimePolicy.CanAutoClick(state, configuration.Autoclicker, true, true, true, 130),
            "the inventory panel should suppress autoclicking while inventory is open")

        state.TypingPaused := true
        this.Assert(
            !RuntimePolicy.CanAutoClick(state, configuration.Autoclicker, true, true, false, 130),
            "typing should suppress autoclicking")

        state.TypingPaused := false
        configuration.AbilitySlots.AutoclickerEnabled["2"] := false
        configuration.AbilitySlots.AutoclickerEnabled["5"] := false
        testAutoclicker := RuntimeSelfTestAutoclicker(configuration.Autoclicker)
        abilitySelection := AbilitySelectionController(
            state,
            configuration.AbilitySlots,
            RuntimeSelfTestContext(),
            testAutoclicker,
            RuntimeSelfTestLogger())
        this.Assert(abilitySelection.Select("2"), "selecting a disabled slot should change ability state")
        this.Assert(!state.AbilityAutoclickEnabled, "disabled slot should pause autoclicking")
        this.Assert(testAutoclicker.HardStopCount = 1, "disabled slot should request one hard stop")
        this.Assert(!abilitySelection.Select("5"), "switching between disabled slots should be a backend no-op")
        this.Assert(state.SelectedAbilitySlot = "5", "disabled no-op should still update selected slot identity")
        this.Assert(testAutoclicker.HardStopCount = 1, "same-policy selection should not stop twice")
        this.Assert(abilitySelection.Select("5"), "pressing the selected disabled slot again should unequip it")
        this.Assert(state.AbilityAutoclickEnabled, "unequipping a paused ability should restore autoclick permission")
        this.Assert(state.SelectedAbilitySlot = "", "unequipping should clear selected ability identity")
        this.Assert(!abilitySelection.Select("3"), "an enabled slot should not restart an already allowed autoclicker")
        this.Assert(!abilitySelection.Select("4"), "switching between enabled slots should be a backend no-op")
        this.Assert(state.SelectedAbilitySlot = "4", "selected slot identity should still update on a no-op")
        this.Assert(InputCoordinator.AbilityKeyFromHotkey("*~1") = "1", "ability key-down hotkeys should normalize")
        this.Assert(InputCoordinator.AbilityKeyFromHotkey("*~= Up") = "=", "ability key-up hotkeys should normalize")
        testGateMacro := RuntimeSelfTestGateMacro()
        testBackwardsRunCancellation := RuntimeSelfTestBackwardsRunCancellation()
        inputHandler := InputCoordinator(
            state,
            configuration,
            "",
            "",
            abilitySelection,
            testGateMacro,
            testAutoclicker,
            testBackwardsRunCancellation,
            RuntimeSelfTestLogger())
        state.TypingPaused := true
        inputHandler.OnPhysicalLeftDown()
        this.Assert(!state.TypingPaused, "a physical click should clear stale chat suppression")
        this.Assert(testGateMacro.CancelCaptureCount = 1, "a physical click should cancel gate capture")
        this.Assert(testAutoclicker.StartCount = 1, "a physical click should attempt to start autoclicking")
        this.Assert(testBackwardsRunCancellation.CancelCount = 1, "a physical left click should reset backwards-run state")
        inputHandler.OnRunCancelInput()
        this.Assert(testBackwardsRunCancellation.CancelCount = 2, "other registered cancellation inputs should reset backwards-run state")
        this.Assert(inputHandler.RunCancelHotkeyNames.Length = 2, "V and G should use unconditional cancellation observers; M2 has its HOLD-aware callback")
        configuration.BackwardsRun.Mode := "Legacy"
        inputHandler.OnPhysicalLeftDown()
        inputHandler.MouseRunCancelCallback.Call()
        inputHandler.OnRunCancelInput()
        this.Assert(testBackwardsRunCancellation.CancelCount = 2, "clicks and cancellation keys must leave legacy run state alone")
        configuration.BackwardsRun.Mode := "MultiDirectional"
        this.TestLegacyRunCancellation()
        this.TestDirectionalDash()
        MultiDirectionalRunSelfTest.Run()

        this.Assert(InventoryController.IsInventoryKey("SC029"), "SC029 should be an inventory key")
        this.Assert(configuration.Autoclicker.MaximumCps = 120, "default CPS should remain 120")
        this.Assert(configuration.Keybinds.Bindings.Length = 5, "five default bindings should exist")
        this.Assert(configuration.BackwardsRun.Enabled, "backwards run should default on")
        this.Assert(configuration.BackwardsRun.Mode = "MultiDirectional", "backwards run should default to multi-directional mode")
        this.Assert(
            BackwardsRunModule.CanActivate(state, configuration.BackwardsRun, true, true),
            "backwards run should activate for W plus S in focused Roblox")
        state.TypingPaused := true
        this.Assert(
            !BackwardsRunModule.CanActivate(state, configuration.BackwardsRun, true, true),
            "backwards run should be suppressed while typing")
        state.TypingPaused := false
        this.Assert(
            !BackwardsRunModule.CanActivate(state, configuration.BackwardsRun, true, false),
            "backwards run should require physical W")
        state.RemapBusy := true
        this.Assert(
            !BackwardsRunModule.CanActivate(state, configuration.BackwardsRun, true, true),
            "remap output should block new backwards-run activation")
        state.RemapBusy := false
        this.Assert(BackwardsRunModule.DoubleTapWindowMs = 200, "directional double taps should use the reference 200 ms window")
        this.Assert(BackwardsRunModule.WalkingResumeDelayMs = 30, "G should reassert held walking input after Roblox processes the reset")
        this.Assert(BackwardsRunModule.AxisForDirection("w") = "vertical", "W should belong to the vertical run axis")
        this.Assert(BackwardsRunModule.AxisForDirection("d") = "horizontal", "D should belong to the horizontal run axis")
        this.Assert(BackwardsRunModule.OppositeDirection("w") = "s", "W should transition to S")
        this.Assert(BackwardsRunModule.OppositeDirection("s") = "w", "S should transition to W")
        this.Assert(BackwardsRunModule.OppositeDirection("a") = "d", "A should transition to D")
        this.Assert(BackwardsRunModule.OppositeDirection("d") = "a", "D should transition to A")
        this.Assert(
            BackwardsRunModule.AnyDirectionHeld(true, false, false, false),
            "a multi-directional run should continue while its original direction remains held")
        this.Assert(
            BackwardsRunModule.AnyDirectionHeld(false, true, false, false),
            "a multi-directional run should continue when another WASD direction remains held")
        this.Assert(
            !BackwardsRunModule.AnyDirectionHeld(false, false, false, false),
            "a multi-directional run should end after every WASD direction is released")
        this.Assert(
            BackwardsRunModule.ShouldTransferForwardedW(true, true, true),
            "a W-initiated run should transfer its logical W hold while another direction remains held")
        this.Assert(
            !BackwardsRunModule.ShouldTransferForwardedW(true, true, false),
            "the final W release should be forwarded when no other direction remains held")
        this.Assert(
            BackwardsRunModule.ShouldReturnWToPhysicalInput(true, true),
            "a G reset should return the logical W hold to a still-held physical W key")
        this.Assert(
            !BackwardsRunModule.ShouldReturnWToPhysicalInput(true, false),
            "a G reset should release synthetic W when physical W is not held")
        this.Assert(
            BackwardsRunModule.WalkingArrowDirection("Up", true, false) = "w",
            "a G reset should preserve Up Arrow while physical W remains held")
        this.Assert(
            BackwardsRunModule.WalkingArrowDirection("Down", false, true) = "s",
            "a G reset should preserve Down Arrow while physical S remains held")
        this.Assert(
            BackwardsRunModule.WalkingArrowDirection("Down", true, true) = "s",
            "a G reset should preserve the current vertical direction when both keys are held")
        this.Assert(
            BackwardsRunModule.WalkingArrowDirection("", false, false) = "",
            "a G reset should not preserve an arrow after both vertical keys are released")
        testBackwardsRun := MultiDirectionalRunFixture(
            state,
            configuration.BackwardsRun,
            RuntimeSelfTestContext(),
            RuntimeSelfTestLogger())
        testBackwardsRun.SetActivated(true)
        this.Assert(state.BackwardsRunActive, "activating a run should update shared HUD state")
        testBackwardsRun.ActiveDirection := "a"
        testBackwardsRun.SessionAxis := "horizontal"
        testBackwardsRun.LegacyStarted := true
        testBackwardsRun.TapCounts["w"] := 1
        testBackwardsRun.ResetToWalkingState()
        this.Assert(!testBackwardsRun.Activated, "G should reset the active backwards-run session")
        this.Assert(!state.BackwardsRunActive, "a G reset should turn off shared running HUD state")
        this.Assert(testBackwardsRun.ActiveDirection = "", "G should reset the active run direction")
        this.Assert(!testBackwardsRun.LegacyStarted, "G should clear legacy run state")
        this.Assert(testBackwardsRun.TapCounts["w"] = 0, "G should clear pending directional taps")
        this.Assert(
            BackwardsRunModule.ShouldUseWAsArrowRebind(true, "vertical", true, true),
            "W should be arrow-only while S owns the synthetic W foundation")
        this.Assert(
            !BackwardsRunModule.ShouldUseWAsArrowRebind(false, "vertical", true, true),
            "ordinary W input should pass through before activation")
        this.Assert(
            !BackwardsRunModule.ShouldUseWAsArrowRebind(true, "vertical", false, true),
            "native W-backed sessions should keep forwarding physical W")
        this.Assert(
            BackwardsRunModule.ShouldUseWAsArrowRebind(true, "horizontal", true, false),
            "lateral sessions should consume physical W as an Up Arrow rebind")
        this.Assert(
            !BackwardsRunModule.ShouldUseWAsArrowRebind(false, "horizontal", true, false),
            "ordinary W input should pass through outside a lateral session")
        this.Assert(
            BackwardsRunModule.CanActivate(state, configuration.BackwardsRun, true, false, false),
            "multi-directional mode should create W input without requiring physical W")
        this.Assert(configuration.GateMacro.Enabled, "gate expansion should default on")
        this.Assert(configuration.GateMacro.Mappings.Count = 0, "gate mappings should default empty")
        gateMappings := Map()
        gateMappings.CaseSense := "Off"
        gateMappings["d4"] := "desert 4"
        configuration.GateMacro.Mappings := gateMappings
        gateMacro := GateMacroModule(state, configuration.GateMacro, RuntimeSelfTestActiveContext(), RuntimeSelfTestLogger())
        gateMacro.OnObserverChar("", "D4")
        this.Assert(gateMacro.InputBuffer = "", "gate input should be ignored before chat activates capture")
        gateMacro.InputBuffer := "d4"
        state.TypingPaused := true
        this.Assert(!gateMacro.SubmitCapture(), "submit should not expand without an active chat capture")
        this.Assert(gateMacro.InputBuffer = "", "a rejected submit should clear stale gate input")
        gateMacro.CaptureActive := true
        gateMacro.InputBuffer := "d4"
        state.TypingPaused := false
        this.Assert(!gateMacro.SubmitCapture(), "submit should not expand after the chat typing guard ends")
        this.Assert(!gateMacro.CaptureActive, "a rejected submit should cancel gate capture")
        state.TypingPaused := true
        gateMacro.CaptureActive := true
        gateMacro.InputBuffer := "d4"
        gateMacro.LastInputTick := A_TickCount - GateMacroModule.InputResetIntervalMs - 1
        this.Assert(!gateMacro.SubmitCapture(), "submit should not expand an expired gate token")
        this.Assert(gateMacro.InputBuffer = "", "an expired submit should clear stale gate input")
        gateMacro.CaptureActive := true
        gateMacro.OnObserverChar("", "D4")
        this.Assert(gateMacro.InputBuffer = "d4", "an active chat capture should collect notation characters")
        gateMacro.OnObserverKeyDown("", 8, 0)
        this.Assert(gateMacro.InputBuffer = "d", "backspace should edit the pending notation")
        gateMacro.OnObserverChar("", "4")
        this.Assert(GateMacroModule.ResolveLocation(configuration.GateMacro, gateMacro.InputBuffer) = "desert 4", "the edited notation should resolve on submit")
        gateMacro.OnObserverChar("", " ")
        this.Assert(gateMacro.InputBuffer = "", "non-notation characters should reset the pending token")
        state.RemapBusy := true
        gateMacro.OnObserverChar("", "d4")
        this.Assert(gateMacro.InputBuffer = "", "remap output should not enter the notation buffer")
        state.RemapBusy := false
        gateMacro.CancelCapture()
        state.TypingPaused := false
        this.Assert(configuration.AbilitySlots.AutoclickerEnabled.Count = 12, "twelve default ability policies should exist")
        this.Assert(RuntimeConfiguration.IsReservedBindingSource("1"), "weapon slots should be reserved")
        this.Assert(RuntimeConfiguration.IsReservedBindingSource("LButton"), "physical click tracking should be reserved")
        this.Assert(RuntimeConfiguration.IsReservedBindingSource("w"), "the multi-directional W trigger should be reserved")
        this.Assert(RuntimeConfiguration.IsReservedBindingSource("s"), "the backwards-run S trigger should be reserved")
        this.Assert(RuntimeConfiguration.IsReservedBindingSource("a"), "the backwards-run A trigger should be reserved")
        this.Assert(RuntimeConfiguration.IsReservedBindingSource("d"), "the backwards-run D trigger should be reserved")
        this.Assert(RuntimeConfiguration.IsReservedBindingSource("W"), "uppercase W should be reserved")
        this.Assert(RuntimeConfiguration.IsReservedBindingSource("S"), "uppercase S should be reserved")
        this.Assert(RuntimeConfiguration.IsReservedBindingSource("A"), "uppercase A should be reserved")
        this.Assert(RuntimeConfiguration.IsReservedBindingSource("D"), "uppercase D should be reserved")
        this.Assert(RuntimeConfiguration.IsReservedBindingSource("g"), "the backwards-run cancel key should be reserved")
        this.Assert(RuntimeConfiguration.IsReservedBindingSource("G"), "uppercase G should be reserved")
        this.Assert(RuntimeConfiguration.IsReservedBindingSource("q"), "Q should be reserved for backwards-run cancellation")
        this.Assert(RuntimeConfiguration.IsReservedBindingSource("v"), "V should be reserved for backwards-run cancellation")
        this.Assert(RuntimeConfiguration.IsReservedBindingSource("RButton"), "right click should be reserved for backwards-run cancellation")
        this.Assert(!RuntimeConfiguration.IsReservedBindingSource("Tab"), "ordinary remap sources should remain available")
        this.Assert(InventoryPanelGuard.ContainsNormalizedPoint(configuration.InventoryPanel, 0.5, 0.5), "inventory center should be excluded")
        this.Assert(!InventoryPanelGuard.ContainsNormalizedPoint(configuration.InventoryPanel, 0.1, 0.5), "screen edge should remain clickable")

        manaBounds := ManaOverlay.CalculateBounds(configuration.ManaOverlay, 100, 200, 1920, 1080)
        this.Assert(manaBounds.X = 100, "mana overlay canvas should align to the client X")
        this.Assert(manaBounds.Y = 200, "mana overlay canvas should align to the client Y")
        this.Assert(manaBounds.Width = 1920, "mana overlay canvas should match client width")
        this.Assert(manaBounds.Height = 1080, "mana overlay canvas should match client height")

        examplePath := A_ScriptDir "\RLMacroHub.Runtime.example.ini"
        loaded := RuntimeConfiguration.Load(examplePath)
        this.Assert(loaded.SchemaVersion = 9, "example schema version should load")
        this.Assert(loaded.BackwardsRun.Enabled, "backwards run should load")
        this.Assert(loaded.BackwardsRun.ResetHotkey = "", "example reset key must remain unbound")
        this.Assert(loaded.BackwardsRun.Mode = "MultiDirectional", "multi-directional backwards run mode should load")
        this.Assert(loaded.ManaOverlay.Enabled, "mana overlay should load")
        this.Assert(loaded.ManaOverlay.Scale = 1, "mana overlay scale should load")
        this.Assert(loaded.Keybinds.Bindings.Length = 5, "example bindings should load")
        this.Assert(loaded.Keybinds.Bindings[5].Source = "Tab", "binding order should be preserved")
        this.Assert(loaded.GateMacro.Enabled, "gate macro should load")
        this.Assert(loaded.GateMacro.Mappings.Count = 1, "gate mappings should load")
        this.Assert(GateMacroModule.ResolveLocation(loaded.GateMacro, "D5") = "desert 5", "gate lookup should be case-insensitive")
        this.Assert(loaded.InventoryPanel.SuppressAutoclicks, "inventory exclusion should load")
        this.Assert(loaded.AbilitySlots.AutoclickerEnabled.Count = 12, "ability slot policies should load")
        this.Assert(loaded.AbilitySlots.AutoclickerEnabled.Has("="), "equals slot should survive INI parsing")
        try FileAppend "RL Macro Hub runtime self-test passed.`n", "*"
    }

    static TestLegacyRunCancellation() {
        for backwards in [true, false] {
            configuration := RuntimeConfiguration.CreateDefault()
            configuration.BackwardsRun.Mode := "Legacy"
            run := RuntimeSelfTestLegacyRun(RuntimeState(true), configuration.BackwardsRun,
                RuntimeSelfTestActiveContext(), RuntimeSelfTestLogger())
            run.SetActivated(true)
            run.LegacyStarted := true
            run.ActiveDirection := "s"
            run.DownHeld := backwards
            run.UpHeld := !backwards
            run.OnRunCancel()
            this.Assert(run.PrepareDash() = "", "legacy dash must not inject movement input")
            this.Assert(run.Activated && run.State.BackwardsRunActive && run.LegacyStarted,
                "cancellation inputs must preserve legacy activation and HUD state")
            this.Assert(run.ActiveDirection = "s" && run.DownHeld = backwards && run.UpHeld = !backwards,
                "cancellation inputs must preserve legacy forward and backward arrow holds")
        }
    }

    static TestDirectionalDash() {
        for heldKeys in [["a"], ["s"], ["a", "s"], ["w", "a"], ["w", "s"]] {
            configuration := RuntimeConfiguration.CreateDefault()
            run := RuntimeSelfTestDashRun(RuntimeState(true), configuration.BackwardsRun,
                RuntimeSelfTestActiveContext(), RuntimeSelfTestLogger())
            run.HeldKeys := Map()
            for key in heldKeys
                run.HeldKeys[key] := true
            run.SetActivated(true)
            run.SyntheticWHeld := true
            run.WPressForwarded := true
            run.ArrowHeld := "Up"
            run.MovementSent := []
            run.TapCounts["a"] := 1
            handler := RuntimeSelfTestDashInput(run.State, configuration, "", "", "", "", "", run, RuntimeSelfTestLogger())
            handler.SentKeys := []
            handler.OnDashDown()
            expected := "{Blind}{w up}" (run.IsDirectionHeld("a") ? "{a down}" : "") "{q down}"
            this.Assert(handler.SentKeys[1] = expected, "dash must release W without re-pressing physical S before Q-down; expected " expected ", got " handler.SentKeys[1])
            this.Assert(!run.Activated && !run.State.BackwardsRunActive, "dash should finish the run")
            this.Assert(!run.SyntheticWHeld && !run.WPressForwarded, "dash should relinquish synthetic and forwarded W ownership")
            this.Assert(!run.PreservedPhysicalMovement && !run.PreservedArrow, "dash cleanup must not preserve forward output")
            this.Assert(run.ArrowHeld = "" && run.MovementSent[1] = "{Up up}" && run.MovementSent[2] = "{w up}", "real cleanup should release the forward arrow and W")
            this.Assert(run.TapCounts["a"] = 0, "dash should clear pending double taps")
            this.Assert(run.ResumeScheduled, "dash should schedule physical walking input restoration")
            handler.OnDashUp()
            this.Assert(handler.SentKeys[2] = "{Blind}{q up}", "Q release must be forwarded")
            run.MovementSent := []
            run.ResumeWalkingMovement()
            this.Assert(run.MovementSent.Length = heldKeys.Length - (run.IsDirectionHeld("s") ? 1 : 0), "dash walking resume must leave the continuous physical S hold untouched")
            this.Assert(run.WPressForwarded = run.IsDirectionHeld("w"), "walking resume must not recreate synthetic W")
            run.HeldKeys := Map()
            run.MovementSent := []
            run.ResumeWalkingMovement()
            this.Assert(run.MovementSent.Length = 0, "keys released before the resume timer must stay released")
        }

        ; Ordinary Q, W/D-only runs, chat, disabled runtime, and Legacy mode
        ; must not receive the special A/S input prefix.
        for scenario in ["idle", "w", "d", "chat", "disabled", "legacy", "unfocused"] {
            configuration := RuntimeConfiguration.CreateDefault()
            context := scenario = "unfocused" ? RuntimeSelfTestContext() : RuntimeSelfTestActiveContext()
            run := RuntimeSelfTestDashRun(RuntimeState(true), configuration.BackwardsRun, context, RuntimeSelfTestLogger())
            run.HeldKeys := Map(scenario = "w" || scenario = "d" ? scenario : "a", true)
            run.SetActivated(scenario != "idle")
            run.State.TypingPaused := scenario = "chat"
            run.State.Enabled := scenario != "disabled"
            if scenario = "legacy"
                run.Configuration.Mode := "Legacy"
            handler := RuntimeSelfTestDashInput(run.State, configuration, "", "", "", "", "", run, RuntimeSelfTestLogger())
            handler.SentKeys := []
            handler.OnDashDown()
            handler.OnDashUp()
            this.Assert(handler.SentKeys[1] = "{Blind}{q down}" && handler.SentKeys[2] = "{Blind}{q up}", "ordinary Q should preserve down/up input: " scenario)
            if scenario = "legacy"
                this.Assert(!run.HasOwnProp("NormalCancelCalled") && run.Activated, "legacy Q must leave the run active")
            else if scenario = "idle"
                this.Assert(!run.HasOwnProp("NormalCancelCalled") && !run.HasOwnProp("ResumeScheduled"), "Q outside a run must not cancel movement or schedule restoration")
            else
                this.Assert(run.NormalCancelCalled, "ordinary Q should retain its existing cancellation path: " scenario)
        }
    }

    static Assert(condition, message) {
        if !condition
            throw Error("Self-test failed: " message)
    }
}

class RuntimeSelfTestContext {
    IsActive() => false
}

class RuntimeSelfTestActiveContext {
    IsActive() => true
}

class RuntimeSelfTestAutoclicker {
    __New(configuration) {
        this.Configuration := configuration
        this.HardStopCount := 0
        this.StartCount := 0
    }

    HardStop() {
        this.HardStopCount += 1
    }

    Start() {
        this.StartCount += 1
    }
}

class RuntimeSelfTestGateMacro {
    __New() {
        this.CancelCaptureCount := 0
    }

    CancelCapture() {
        this.CancelCaptureCount += 1
    }
}

class RuntimeSelfTestBackwardsRunCancellation {
    __New() {
        this.CancelCount := 0
    }

    OnRunCancel(*) {
        this.CancelCount += 1
    }
}

class RuntimeSelfTestLogger {
    Info(*) {
    }
}

; Capture input instead of injecting keys into the user's foreground app.
class RuntimeSelfTestDashInput extends InputCoordinator {
    SendDashInput(keys) {
        this.SentKeys.Push(keys)
    }
}

class RuntimeSelfTestLegacyRun extends BackwardsRunModule {
    SendMovementInput(keys) {
        throw Error("Legacy cancellation must not send movement input: " keys)
    }

    ScheduleWalkingResume(skipS := false) {
        throw Error("Legacy cancellation must not schedule walking restoration")
    }
}

class RuntimeSelfTestDashRun extends BackwardsRunModule {
    IsDirectionHeld(key) => this.HeldKeys.Get(key, false)

    ReleaseOutputs(preservePhysicalMovement := false, preserveDirectionalArrow := false) {
        this.PreservedPhysicalMovement := preservePhysicalMovement
        this.PreservedArrow := preserveDirectionalArrow
        super.ReleaseOutputs(preservePhysicalMovement, preserveDirectionalArrow)
    }

    SendMovementInput(keys) {
        this.MovementSent.Push(keys)
    }

    OnRunCancel(*) {
        this.NormalCancelCalled := true
    }

    ScheduleWalkingResume(skipS := false) {
        this.WalkingResumeSkipS := skipS
        this.ResumeScheduled := true
    }
}
