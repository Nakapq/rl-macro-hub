#Requires AutoHotkey v2.0+
#Include "..\Modules\ManaOverlay.ahk"

configuration := {
    Enabled: true,
    NormalizedX: 0.0,
    NormalizedY: 0.0,
    Scale: 1.0,
    Opacity: 1.0
}
overlay := ManaOverlay(
    configuration,
    ManaOverlayProbeContext(),
    ManaOverlayProbeLogger(),
    A_ScriptDir "\..\Assets\ManaOverlay.png")
overlay.Create()
if !IsObject(overlay.Window)
    throw Error("Mana overlay probe failed to create the layered window.")
overlay.Destroy()
ExitApp 0

class ManaOverlayProbeContext {
    IsActive() => true
    IsMinimized() => false

    TryGetClientBounds(&x, &y, &width, &height) {
        x := -10000
        y := -10000
        width := 1920
        height := 1080
        return true
    }
}

class ManaOverlayProbeLogger {
    Error(message) {
        throw Error(message)
    }
}
