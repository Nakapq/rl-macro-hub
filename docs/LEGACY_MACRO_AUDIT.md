# Legacy macro audit

Audited file: `Forvaynes_God_Clicker_game_style_overlay.ahk` (1,262 lines, AutoHotkey v1). The root source and `legacy/` reference copy are byte-identical with SHA-256 `09A3D003E6421F726E67D937CEDA351D64F59C62F6D93663D15804DB97464455` at initialization. Neither was edited.

## Major runtime states

- `ToggleKeys`: master macro/autoclick enable state; selecting the configured weapon also turns it on.
- `TypingPaused`: set by `/`, cleared by Enter/Escape; blocks autoclicking and remaps.
- `InventoryOpen`: toggled from physical scan code `SC029` and from remaps whose target is the inventory key.
- `InventoryWeaponOverride`: permits clicking while inventory is still marked open after the weapon slot is selected.
- `PhysicalLButtonDown`, `LastPhysicalDownTick`, `FastClickLoopRunning`: physical-hold detection and scheduler ownership.
- `RemapBusy`: prevents clicking/reentrant remaps while a synthetic key is being sent.
- `SettingsVisible`: owns the F8 settings window state.
- CPS sample/counter state and multimedia timer-resolution ownership.

The intended state rules are present: Roblox must be foreground; inventory suppresses clicks but not otherwise-valid remaps; weapon selection enables the macro and inventory override; closing inventory forces the macro on and resumes a held LMB; chat suppresses clicking; modifier chords are passed through; missed scheduled clicks reset the schedule rather than bursting.

## Configurable values and INI schema

Only hotkeys are persisted. CPS, hold threshold, timer yield, and overlay offsets are globals in the script, not INI settings.

```ini
[General]
ToggleHotkey=XButton1
WeaponSlot=1

[Remaps]
Remap1_From=x
Remap1_To=0
...
Remap10_From=
Remap10_To=
```

The compiled-in mapping defaults are `x→0`, `c→-`, `z→9`, `t→8`, and `Tab→7`. There are inconsistent default sources: initial globals use `XButton1`/slot `1`, while `IniRead` missing-value defaults and Reset use `XButton2`/slot `2`; later normalization falls back to `XButton1` for an empty toggle but slot `2` for an empty weapon. The new JSON defaults use the current/reference `XButton1` and slot `1` consistently.

## Hotkeys

- `F8` globally shows/hides the AHK settings GUI.
- Within `RobloxPlayerBeta.exe`: `/` begins typing suppression; Enter ends it; Escape ends typing and stops clicking.
- `SC029` toggles tracked inventory state and waits for physical release to prevent repeat.
- Physical LMB down/up owns hold detection and hard stop.
- `1` through `0`, `-`, and `=` detect weapon selection.
- The configured toggle and up to ten configured source remaps are registered dynamically and scoped to Roblox.

Modifier-aware handling intentionally preserves ordinary chords such as Alt+Tab, Ctrl+C, Shift+Tab, and Windows-key combinations. Modifier keys used as remap sources are released before output; a modifier mapped to `g` holds `g` until physical release.

## Roblox assumptions

- The desktop client process is exactly `RobloxPlayerBeta.exe`.
- Focus is tested using `WinActive`; clicking and remaps do not operate in background Roblox windows.
- Inventory state is inferred from the grave/tilde physical key or an equivalent remap, rather than observed from the game. It can desynchronize if UI state changes another way.
- Typing/chat state is inferred from `/`, Enter, and Escape. Other ways to focus/leave chat are not detected.
- Weapon slots are expected among the number-row hotkeys including `-` and `=`.

## Autoclick scheduler

The scheduler uses `QueryPerformanceFrequency`/`QueryPerformanceCounter`, a 30 ms physical-hold threshold, and a current `MaxCPS` of 120. It emits at most one click for each check and moves a late deadline forward from the current counter, preventing catch-up bursts. `timeBeginPeriod(1)` improves Windows wait resolution; `Sleep, 0.1` is used only as a yield.

The local `ElapsedMs` calculation is unused. `SafeGameClick` and `LastClickTick` also appear to be remnants of an older scheduler.

## Overlay behavior

AHK GUI 2 is a 94×39 always-on-top, captionless, tool, click-through HUD. It uses two parchment-colored rows for ON/OFF and sampled CPS. Every 500 ms it finds the active Roblox window, hides for unfocused/minimized Roblox, and positions at `RobloxRight - 373`, `RobloxTop + 96`.

The settings GUI is a separate always-on-top tool window containing fixed rows and Save/Reset controls.

## Shutdown behavior

`OnExit("CleanupBeforeExit")` balances a successful `timeBeginPeriod(1)` with `timeEndPeriod(1)`. This makes graceful window-close shutdown important; immediate process termination can skip cleanup. The C# runtime therefore posts `WM_CLOSE`, waits, and uses forced tree termination only as a logged fallback.

## Verified issues and inconsistencies

1. **Confirmed:** `SaveSettings` writes `Remap5_To` as `IniWrite, value, file, Remap5_To`, omitting the `Remaps` section. It does not match the intended schema.
2. **Confirmed:** `LoadSettings` reads `Remap8_To` as `IniRead, output, file, Remap8_To`, also omitting the `Remaps` section.
3. **Confirmed:** the scheduler banner and inline comments repeatedly describe a 100 CPS cap and 10 ms interval, but executable code sets `MaxCPS := 120` and calculates `1000.0 / MaxCPS` (about 8.33 ms). Behavior is 120; comments are stale.
4. Default toggle/weapon values vary between globals, Reset, `IniRead`, and post-read fallback as described above.
5. Inventory and chat state are heuristic and can become out of sync with Roblox.
6. No validation prevents duplicate/invalid remap hotkey registrations; AHK runtime errors may surface during registration.
7. The fixed ten-row UI and handler set constrain only the legacy implementation, not the new domain model.

## Migration boundary

Move to C# first: canonical settings and validation, profiles, app UI, macro metadata/availability, AHK executable discovery and process ownership, logging/error presentation, Roblox window state, overlay placement/presentation, and eventually IPC/telemetry.

Keep in AHK initially: input hooks, physical LMB semantics, QPC click scheduling, no-burst behavior, chat/inventory/weapon state transitions, modifier-aware remaps, dynamic hotkey registration, and timer-resolution cleanup. These behaviors should only move after native equivalents have focused regression tests and real Roblox validation.

The issues above are retained in the untouched reference source for audit accuracy. RL Macro Hub no longer contains a v1 INI adapter or launch path; only the modular v2 runtime is staged under local app data.
