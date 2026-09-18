#Requires AutoHotkey v2.0+
#SingleInstance Force
#Include "Configuration\RuntimeConfiguration.ahk"
#Include "Infrastructure\RuntimeLogger.ahk"
#Include "Infrastructure\HighResolutionWaiter.ahk"
#Include "Infrastructure\TimerResolutionLease.ahk"
#Include "Shared\RuntimeState.ahk"
#Include "Shared\RuntimePolicy.ahk"
#Include "Modules\RobloxContext.ahk"
#Include "Modules\InventoryPanelGuard.ahk"
#Include "Modules\InventoryPanelOverlay.ahk"
#Include "Modules\InventoryController.ahk"
#Include "Modules\AutoclickerModule.ahk"
#Include "Modules\AbilitySelectionController.ahk"
#Include "Modules\InputCoordinator.ahk"
#Include "Modules\KeybindModule.ahk"
#Include "Modules\ManaOverlay.ahk"
#Include "Modules\StatusOverlay.ahk"
#Include "Testing\RuntimeSelfTest.ahk"

Persistent
InstallMouseHook
InstallKeybdHook
SetTitleMatchMode 2
SetKeyDelay 0, 0
SetMouseDelay -1
SendMode "Event"
SetStoreCapsLockMode false

if HasCommandLineArgument("--self-test") {
    RuntimeSelfTest.Run()
    ExitApp 0
}

global RLMacroRuntime := MacroRuntime(A_ScriptDir)
RLMacroRuntime.Start()
if HasCommandLineArgument("--smoke-test")
    SetTimer SmokeTestExit, -1000

HasCommandLineArgument(expected) {
    for argument in A_Args {
        if argument = expected
            return true
    }

    return false
}

SmokeTestExit() {
    FileAppend "RL Macro Hub runtime smoke test completed.`n", "*"
    ExitApp 0
}

class MacroRuntime {
    __New(baseDirectory) {
        this.BaseDirectory := baseDirectory
        this.Logger := RuntimeLogger(baseDirectory "\runtime.log")
        this.ConfigurationPath := baseDirectory "\RLMacroHub.Runtime.ini"
        this.Configuration := RuntimeConfiguration.Load(this.ConfigurationPath, this.Logger)
        this.State := RuntimeState(this.Configuration.Autoclicker.Enabled)
        this.Context := RobloxContext()
        this.TimerResolution := TimerResolutionLease(1, this.Logger)
        this.InventoryPanel := InventoryPanelGuard(this.State, this.Configuration.InventoryPanel, this.Context)
        this.InventoryPanelOverlay := InventoryPanelOverlay(this.Configuration.InventoryPanel, this.Context, this.InventoryPanel, this.Logger)
        this.Inventory := InventoryController(this.State, this.Configuration, this.Context, this.Logger)
        this.Autoclicker := AutoclickerModule(this.State, this.Configuration.Autoclicker, this.Context, this.InventoryPanel, this.Logger)
        this.AbilitySelection := AbilitySelectionController(this.State, this.Configuration.AbilitySlots, this.Context, this.Autoclicker, this.Logger)
        this.Inventory.AttachAutoclicker(this.Autoclicker)
        this.Input := InputCoordinator(this.State, this.Configuration, this.Context, this.Inventory, this.AbilitySelection, this.Autoclicker, this.Logger)
        this.Keybinds := KeybindModule(this.State, this.Configuration.Keybinds, this.Context, this.Inventory, this.AbilitySelection, this.Logger)
        this.ManaOverlay := ManaOverlay(this.Configuration.ManaOverlay, this.Context, this.Logger, baseDirectory "\Assets\ManaOverlay.png")
        this.Overlay := StatusOverlay(this.State, this.Configuration.Overlay, this.Context, this.Logger)
        this.MainTimer := ObjBindMethod(this.Autoclicker, "Tick")
        this.CpsTimer := ObjBindMethod(this.Autoclicker, "UpdateCps")
        this.OverlayTimer := ObjBindMethod(this, "TickOverlays")
        this.ExitHandler := ObjBindMethod(this, "Shutdown")
        this.Started := false
    }

    Start() {
        if this.Started
            return

        this.Started := true
        this.TimerResolution.Acquire()
        this.Input.Register()
        this.Keybinds.Register()
        this.Overlay.Create()
        this.ManaOverlay.Create()
        this.InventoryPanelOverlay.Create()
        SetTimer this.MainTimer, 10
        SetTimer this.CpsTimer, 250
        SetTimer this.OverlayTimer, 250
        OnExit this.ExitHandler
        this.ConfigureTrayMenu()
        this.Logger.Info("Runtime started with " this.Configuration.Keybinds.Bindings.Length " binding(s).")
    }

    ConfigureTrayMenu() {
        A_TrayMenu.Delete()
        A_TrayMenu.Add("Reload runtime", (*) => Reload())
        A_TrayMenu.Add()
        A_TrayMenu.Add("Exit RL Macro Runtime", (*) => ExitApp())
        A_TrayMenu.Default := "Reload runtime"
        A_TrayMenu.ClickCount := 1
        A_IconTip := "RL Macro Hub Runtime"
    }

    TickOverlays(*) {
        this.Overlay.Tick()
        this.ManaOverlay.Tick()
        this.InventoryPanelOverlay.Tick()
    }

    Shutdown(exitReason, exitCode) {
        if !this.Started
            return 0

        this.Started := false
        this.Logger.Info("Runtime stopping (" exitReason ", code " exitCode ").")

        try SetTimer this.MainTimer, 0
        try SetTimer this.CpsTimer, 0
        try SetTimer this.OverlayTimer, 0
        try this.Input.Unregister()
        try this.Keybinds.Unregister()
        try this.Overlay.Destroy()
        try this.ManaOverlay.Destroy()
        try this.InventoryPanelOverlay.Destroy()
        try this.Autoclicker.Dispose()
        try this.TimerResolution.Dispose()
        return 0
    }
}
