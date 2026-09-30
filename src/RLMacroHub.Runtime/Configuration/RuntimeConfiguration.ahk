class RuntimeConfiguration {
    static CurrentSchemaVersion := 8
    static MaximumGateMappings := 100
    static MaximumGateNotationLength := 20
    static MaximumGateLocationLength := 120
    static AbilitySlotKeys := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="]
    static ReservedBindingSources := [
        "/", "Enter", "Esc", "Escape", "SC029", "LButton", "w", "a", "s", "d",
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="
    ]

    static CreateDefault() {
        abilitySlotActions := Map()
        abilitySlotActions.CaseSense := "Off"
        for slot in this.AbilitySlotKeys
            abilitySlotActions[slot] := true
        gateMappings := Map()
        gateMappings.CaseSense := "Off"

        return {
            SchemaVersion: this.CurrentSchemaVersion,
            General: {
                ToggleHotkey: "XButton1"
            },
            Autoclicker: {
                Enabled: true,
                MaximumCps: 120,
                HoldThresholdMs: 30,
                ForceEnabledWhenInventoryCloses: true
            },
            InventoryPanel: {
                SuppressAutoclicks: true,
                ShowBorder: false,
                NormalizedLeft: 479.0 / 1920.0,
                NormalizedTop: 458.0 / 1080.0,
                NormalizedRight: 1442.0 / 1920.0,
                NormalizedBottom: 1000.0 / 1080.0
            },
            AbilitySlots: {
                AutoclickerEnabled: abilitySlotActions
            },
            Keybinds: {
                Enabled: true,
                Bindings: [
                    { Source: "x", Target: "0" },
                    { Source: "c", Target: "-" },
                    { Source: "z", Target: "9" },
                    { Source: "t", Target: "8" },
                    { Source: "Tab", Target: "7" }
                ]
            },
            BackwardsRun: {
                Enabled: true,
                Mode: "Legacy"
            },
            GateMacro: {
                Enabled: true,
                Mappings: gateMappings
            },
            ManaOverlay: {
                Enabled: true,
                NormalizedX: 0.0,
                NormalizedY: 0.0,
                Scale: 1.0,
                Opacity: 1.0
            },
            Overlay: {
                Enabled: true,
                ShowAutoclickerStatus: true,
                ClickThrough: true,
                Width: 56,
                Height: 39,
                RightOffset: 348,
                TopOffset: 96
            }
        }
    }

    static Load(path, logger := "") {
        configuration := this.CreateDefault()
        if !FileExist(path) {
            if IsObject(logger)
                logger.Warn("Runtime configuration was not found; using defaults: " path)
            return configuration
        }

        try {
            configuration.SchemaVersion := this.ReadInteger(path, "Runtime", "SchemaVersion", 1, 1, this.CurrentSchemaVersion)
            configuration.General.ToggleHotkey := this.ReadRequired(path, "General", "ToggleHotkey", "XButton1")
            normalizedToggleHotkey := this.NormalizeKeyName(configuration.General.ToggleHotkey)
            if normalizedToggleHotkey = "w"
                || normalizedToggleHotkey = "s"
                || normalizedToggleHotkey = "a"
                || normalizedToggleHotkey = "d" {
                configuration.General.ToggleHotkey := "XButton1"
                if IsObject(logger)
                    logger.Warn("Toggle hotkeys W, A, S, and D are reserved for Backwards Run; restored XButton1.")
            }

            configuration.Autoclicker.Enabled := this.ReadBoolean(path, "Autoclicker", "Enabled", true)
            configuration.Autoclicker.MaximumCps := this.ReadInteger(path, "Autoclicker", "MaximumCps", 120, 1, 120)
            configuration.Autoclicker.HoldThresholdMs := this.ReadInteger(path, "Autoclicker", "HoldThresholdMs", 30, 0, 1000)
            configuration.Autoclicker.ForceEnabledWhenInventoryCloses := this.ReadBoolean(path, "Autoclicker", "ForceEnabledWhenInventoryCloses", true)

            configuration.InventoryPanel.SuppressAutoclicks := this.ReadBoolean(path, "InventoryPanel", "SuppressAutoclicks", true)
            configuration.InventoryPanel.ShowBorder := this.ReadBoolean(path, "InventoryPanel", "ShowBorder", false)
            configuration.InventoryPanel.NormalizedLeft := this.ReadNumber(path, "InventoryPanel", "NormalizedLeft", configuration.InventoryPanel.NormalizedLeft, 0, 1)
            configuration.InventoryPanel.NormalizedTop := this.ReadNumber(path, "InventoryPanel", "NormalizedTop", configuration.InventoryPanel.NormalizedTop, 0, 1)
            configuration.InventoryPanel.NormalizedRight := this.ReadNumber(path, "InventoryPanel", "NormalizedRight", configuration.InventoryPanel.NormalizedRight, 0, 1)
            configuration.InventoryPanel.NormalizedBottom := this.ReadNumber(path, "InventoryPanel", "NormalizedBottom", configuration.InventoryPanel.NormalizedBottom, 0, 1)
            if configuration.InventoryPanel.NormalizedRight <= configuration.InventoryPanel.NormalizedLeft
                || configuration.InventoryPanel.NormalizedBottom <= configuration.InventoryPanel.NormalizedTop {
                defaults := this.CreateDefault().InventoryPanel
                configuration.InventoryPanel.NormalizedLeft := defaults.NormalizedLeft
                configuration.InventoryPanel.NormalizedTop := defaults.NormalizedTop
                configuration.InventoryPanel.NormalizedRight := defaults.NormalizedRight
                configuration.InventoryPanel.NormalizedBottom := defaults.NormalizedBottom
                if IsObject(logger)
                    logger.Warn("Invalid inventory panel bounds were reset to defaults.")
            }

            abilitySlotCount := this.ReadInteger(path, "AbilitySlots", "SlotCount", 0, 0, this.AbilitySlotKeys.Length)
            seenAbilitySlots := Map()
            seenAbilitySlots.CaseSense := "Off"
            loop abilitySlotCount {
                slot := Trim(IniRead(path, "AbilitySlots", "Slot" A_Index "_Key", ""))
                if !this.IsAbilitySlot(slot) || seenAbilitySlots.Has(slot) {
                    if IsObject(logger)
                        logger.Warn("Skipped invalid or duplicate ability slot: " slot)
                    continue
                }

                configuration.AbilitySlots.AutoclickerEnabled[slot] := this.ReadBoolean(
                    path,
                    "AbilitySlots",
                    "Slot" A_Index "_AutoclickerEnabled",
                    true)
                seenAbilitySlots[slot] := true
            }

            configuration.Keybinds.Enabled := this.ReadBoolean(path, "Keybinds", "Enabled", true)
            configuration.Keybinds.Bindings := []
            bindingCount := this.ReadInteger(path, "Keybinds", "BindingCount", 0, 0, 250)
            seenSources := Map()
            seenSources.CaseSense := "Off"
            loop bindingCount {
                source := Trim(IniRead(path, "Bindings", "Binding" A_Index "_Source", ""))
                target := Trim(IniRead(path, "Bindings", "Binding" A_Index "_Target", ""))
                if source = "" || target = "" {
                    if IsObject(logger)
                        logger.Warn("Skipped incomplete binding " A_Index ".")
                    continue
                }

                normalizedSource := this.NormalizeKeyName(source)
                normalizedToggleHotkey := this.NormalizeKeyName(configuration.General.ToggleHotkey)
                if seenSources.Has(normalizedSource)
                    || normalizedSource = normalizedToggleHotkey
                    || this.IsReservedBindingSource(normalizedSource) {
                    if IsObject(logger)
                        logger.Warn("Skipped duplicate or reserved binding source: " source)
                    continue
                }

                seenSources[normalizedSource] := true
                configuration.Keybinds.Bindings.Push({ Source: source, Target: target })
            }

            configuration.BackwardsRun.Enabled := this.ReadBoolean(path, "BackwardsRun", "Enabled", true)
            backwardsRunMode := StrLower(this.ReadRequired(path, "BackwardsRun", "Mode", "Legacy"))
            if backwardsRunMode = "multidirectional" {
                configuration.BackwardsRun.Mode := "MultiDirectional"
            } else if backwardsRunMode = "doubletap" {
                configuration.BackwardsRun.Mode := "DoubleTap"
            } else {
                configuration.BackwardsRun.Mode := "Legacy"
                if backwardsRunMode != "legacy" && IsObject(logger)
                    logger.Warn("Invalid Backwards Run mode was reset to Legacy.")
            }

            configuration.GateMacro.Enabled := this.ReadBoolean(path, "GateMacro", "Enabled", true)
            configuration.GateMacro.Mappings := Map()
            configuration.GateMacro.Mappings.CaseSense := "Off"
            mappingCount := this.ReadInteger(path, "GateMacro", "MappingCount", 0, 0, this.MaximumGateMappings)
            loop mappingCount {
                notation := StrLower(Trim(IniRead(path, "GateMappings", "Mapping" A_Index "_Notation", "")))
                location := Trim(IniRead(path, "GateMappings", "Mapping" A_Index "_Location", ""))
                if !this.IsValidGateNotation(notation)
                    || location = ""
                    || configuration.GateMacro.Mappings.Has(notation) {
                    if IsObject(logger)
                        logger.Warn("Skipped invalid, incomplete, or duplicate gate mapping " A_Index ".")
                    continue
                }

                if StrLen(location) > this.MaximumGateLocationLength
                    location := SubStr(location, 1, this.MaximumGateLocationLength)
                configuration.GateMacro.Mappings[notation] := location
            }

            configuration.ManaOverlay.Enabled := this.ReadBoolean(path, "ManaOverlay", "Enabled", true)
            configuration.ManaOverlay.NormalizedX := this.ReadNumber(path, "ManaOverlay", "NormalizedX", configuration.ManaOverlay.NormalizedX, -1, 2)
            configuration.ManaOverlay.NormalizedY := this.ReadNumber(path, "ManaOverlay", "NormalizedY", configuration.ManaOverlay.NormalizedY, -1, 2)
            configuration.ManaOverlay.Scale := this.ReadNumber(path, "ManaOverlay", "Scale", 1, 0.25, 3)
            configuration.ManaOverlay.Opacity := this.ReadNumber(path, "ManaOverlay", "Opacity", 1, 0.1, 1)
            if configuration.SchemaVersion = 4 {
                configuration.ManaOverlay.NormalizedX -= (13.0 / 1920.0) * configuration.ManaOverlay.Scale
                configuration.ManaOverlay.NormalizedY -= (549.0 / 1080.0) * configuration.ManaOverlay.Scale
            }

            configuration.Overlay.Enabled := this.ReadBoolean(path, "Overlay", "Enabled", true)
            configuration.Overlay.ShowAutoclickerStatus := this.ReadBoolean(path, "Overlay", "ShowAutoclickerStatus", true)
            configuration.Overlay.ClickThrough := this.ReadBoolean(path, "Overlay", "ClickThrough", true)
            configuration.Overlay.Width := this.ReadInteger(path, "Overlay", "Width", 56, 40, 1000)
            configuration.Overlay.Height := this.ReadInteger(path, "Overlay", "Height", 39, 20, 1000)
            configuration.Overlay.RightOffset := this.ReadInteger(path, "Overlay", "RightOffset", 348, -5000, 5000)
            configuration.Overlay.TopOffset := this.ReadInteger(path, "Overlay", "TopOffset", 96, -5000, 5000)
        } catch as error {
            if IsObject(logger)
                logger.Error("Configuration load failed; using validated defaults. " error.Message)
            return this.CreateDefault()
        }

        return configuration
    }

    static IsReservedBindingSource(source) {
        normalizedSource := this.NormalizeKeyName(source)
        for reserved in this.ReservedBindingSources {
            if normalizedSource = this.NormalizeKeyName(reserved)
                return true
        }
        return false
    }

    static NormalizeKeyName(keyName) => StrLower(Trim(keyName))

    static IsAbilitySlot(slot) {
        for supportedSlot in this.AbilitySlotKeys {
            if slot = supportedSlot
                return true
        }
        return false
    }

    static IsValidGateNotation(notation) {
        return RegExMatch(notation, "^[A-Za-z0-9_-]{1," this.MaximumGateNotationLength "}$")
    }

    static ReadRequired(path, section, key, fallback) {
        value := Trim(IniRead(path, section, key, fallback))
        return value = "" ? fallback : value
    }

    static ReadBoolean(path, section, key, fallback) {
        defaultValue := fallback ? "1" : "0"
        value := StrLower(Trim(IniRead(path, section, key, defaultValue)))
        return value = "1" || value = "true" || value = "yes" || value = "on"
    }

    static ReadInteger(path, section, key, fallback, minimum, maximum) {
        raw := Trim(IniRead(path, section, key, fallback))
        if !IsNumber(raw)
            return fallback

        value := Round(raw)
        return Min(maximum, Max(minimum, value))
    }

    static ReadNumber(path, section, key, fallback, minimum, maximum) {
        raw := Trim(IniRead(path, section, key, fallback))
        if !IsNumber(raw)
            return fallback

        return Min(maximum, Max(minimum, Number(raw)))
    }
}
