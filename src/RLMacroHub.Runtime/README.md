# RL Macro Hub Runtime

This is the modular AutoHotkey v2 runtime. `RLMacroHub.Runtime.ahk` is the only entry point; modules share one `RuntimeState` instance so inventory, ability selection, remapping, typing suppression, and autoclick eligibility cannot drift across processes.

While inventory is open, autoclicking remains available outside the configured inventory panel. `InventoryPanelGuard` maps normalized panel coordinates into the live Roblox client rectangle and blocks generated clicks only while the pointer is inside it.

`InventoryPanelOverlay` can display the same region as a cyan, click-through border whenever Roblox is active. Enable it from the Autoclicker page, save, and restart/reload the runtime until live configuration IPC is available.

`ManaOverlay` renders the supplied full-canvas transparent mana guide as a click-through HUD. The 1920 × 1080 reference canvas is stretched over the Roblox client to preserve its authored alignment, and it is visible only while Roblox is focused and not minimized. Enable and calibrate it from the Mana Overlay page, then restart/reload the runtime to apply changes.

## Ownership

- `Configuration/`: reads the app-generated runtime INI and applies safe defaults/ranges.
- `Shared/`: transient state and pure eligibility policy.
- `Modules/`: focused Roblox, inventory, input, keybind, autoclicker, mana overlay, and transitional HUD behavior.
- `Infrastructure/`: runtime logging and balanced multimedia timer-resolution ownership.
- `Testing/`: a side-effect-free self-test path.

The QPC scheduler preserves the legacy no-catch-up-burst rule. C# remains responsible for canonical JSON configuration, profiles, staging, process lifecycle, and user-facing errors.

The compact status HUD is 56 pixels wide by default and is aligned beneath the Roblox Menu button in the supplied 1920 × 1080 reference. Its internal rows and text widths derive from runtime configuration rather than assuming the former 94-pixel width.

The scheduler uses a reusable Windows high-resolution waitable timer rather than `Sleep 1`; on the development machine the latter only woke about 65 times per second. This keeps 120 CPS scheduling accurate without a busy spin.

## Standalone validation

```powershell
AutoHotkey.exe /ErrorStdOut RLMacroHub.Runtime.ahk --self-test
```

The self-test exits before registering hotkeys, requesting timer resolution, creating a HUD, or sending input.

`--smoke-test` performs normal startup, waits one second with no simulated input, and exits through `OnExit` to verify resource cleanup.

`Testing/ManaOverlayProbe.ahk` creates the layered PNG window off-screen to verify GDI+ decoding, scaling, per-pixel alpha presentation, and cleanup.

`Testing/SchedulerProbe.ahk` verifies the QPC schedule and precision waiter for one second without sending clicks.

The archived v1 script is not a runtime option. RL Macro Hub stages and launches only this v2 entry point and prevents ordinary duplicate launches within the runtime service.
