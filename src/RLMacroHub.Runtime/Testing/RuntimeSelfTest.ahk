class RuntimeSelfTest {
    static Run() {
        configuration := RuntimeConfiguration.CreateDefault()
        state := RuntimeState(true)
        state.PhysicalLButtonDown := true
        state.LastPhysicalDownTick := 100

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

        this.Assert(InventoryController.IsInventoryKey("SC029"), "SC029 should be an inventory key")
        this.Assert(configuration.Autoclicker.MaximumCps = 120, "default CPS should remain 120")
        this.Assert(configuration.Keybinds.Bindings.Length = 5, "five default bindings should exist")
        this.Assert(configuration.GateMacro.Enabled, "gate expansion should default on")
        this.Assert(configuration.GateMacro.Mappings.Count = 0, "gate mappings should default empty")
        gateMappings := Map()
        gateMappings.CaseSense := "Off"
        gateMappings["d4"] := "desert 4"
        configuration.GateMacro.Mappings := gateMappings
        gateMacro := GateMacroModule(state, configuration.GateMacro, RuntimeSelfTestActiveContext(), RuntimeSelfTestLogger())
        gateMacro.OnObserverChar("", "D4")
        this.Assert(gateMacro.InputBuffer = "d4", "the Roblox-wide observer should collect notation characters")
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
        this.Assert(configuration.AbilitySlots.AutoclickerEnabled.Count = 12, "twelve default ability policies should exist")
        this.Assert(RuntimeConfiguration.IsReservedBindingSource("1"), "weapon slots should be reserved")
        this.Assert(RuntimeConfiguration.IsReservedBindingSource("LButton"), "physical click tracking should be reserved")
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
        this.Assert(loaded.SchemaVersion = 6, "example schema version should load")
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
        FileAppend "RL Macro Hub runtime self-test passed.`n", "*"
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
    }

    HardStop() {
        this.HardStopCount += 1
    }

    Start() {
    }
}

class RuntimeSelfTestLogger {
    Info(*) {
    }
}
