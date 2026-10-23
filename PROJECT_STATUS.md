# Project status

Last updated: 2026-10-23

## Current priority

Stabilize input-driven Multi-Directional running before adding a visual
detection variant. The [deferred design](docs/IMAGE_DETECTION.md) records the
animation-recognition approach, candidate libraries, camera-diverse training,
unknown-state handling, and evaluation gates. No image detector is implemented.

The 2026-10-22 stability pass reproduced and fixed missed-release arrow/ownership
cleanup and direction reconciliation occurring before focus/chat/disable cleanup.
Generated input and physical-key reads now use overridable boundaries so the
real movement state machine can be exercised without sending foreground input.
Keyboard/mouse hook installation happens after the self-test exit path.

M1/M2 now preserve Multi-Directional run state while the selected ability puts
autoclicking on HOLD. The next physical M1/M2 after leaving HOLD cancels normally;
other cancellation inputs keep their existing behavior. Regression coverage
checks all four run directions, ability equip/unequip transitions, mouse
tracking, and the shared G/V cancellation path during HOLD.

S dashes now leave the physical S hold untouched and preserve an existing
backward arrow until S is released. The dash sequence, Q release, and its
delayed callback do not synthesize S releases or re-presses. This applies to
running and walking; ordinary focus/chat/disable cleanup still releases macro
output. AHK regression tests pass; uninterrupted in-game backward movement
still needs confirmation in Roblox.

A/S dash adjustments now require an active macro run. Outside a run, Q emits
only its down/up events without resetting movement or scheduling restoration.
AHK regressions cover A/S and mixed held directions, retained walking arrows,
and Q repeats, alongside the existing active-run dash tests.

Latest verification:

- Full Debug x64 solution build into an isolated output directory: **passed**,
  0 warnings and 0 errors.
- .NET tests: **53/53 passed**, no failures or skips.
- AHK self-test including the new movement regression suite: **passed**.
- Isolated AHK startup/shutdown smoke test with macro features disabled:
  **passed**, exit code 0. This verifies lifecycle, not live movement hooks.
- Real Roblox [acceptance checklist](docs/MANA_RUNNING.md#stability-validation):
  **pending**. The baseline is not yet certified stable in-game. The Run HUD
  remains an input-derived estimate, including during climbing/game-driven stops.

## Created

- Four-project solution with WinUI app, platform-independent core, Windows infrastructure, and xUnit tests
- Packaged x64 WinUI 3 shell targeting stable Windows App SDK 2.4.0
- JSON settings, modular runtime projection, profile storage, AutoHotkey v2 runtime ownership, Roblox tracking, dormant native overlay foundation, logging, DI, and bound pages/view models
- Untouched, hash-verified legacy AHK reference copy and a detailed audit

## Working behavior

- Configuration defaults, validation, async atomic persistence, and malformed-file recovery
- Dashboard state changes from Roblox/runtime services, with prominent runtime Start/Stop controls
- Explicit-save autoclicker and mana-overlay settings, twelve named two-state ability slots, and dynamic validated bindings
- Profile-scoped Gate Macro settings with validated notation/location mappings and exact case-insensitive Roblox chat expansion
- Profile-scoped Backwards Run modes defaulting to Roblox-only, chat-safe multi-directional `W`/`A`/`S`/`D` activation with opposite-axis transitions and held-key fallback, with legacy `W` + `S` behavior available
- Default/profile CRUD safeguards, automatic activation on create, active-profile write-back for Autoclicker, Backwards Run, Gate Macro, Mana Overlay, and Keybinds, global-setting preservation, and UI refresh on profile switch
- AutoHotkey v2-only discovery, isolated staging/configuration, duplicate prevention, graceful shutdown, fallback termination
- Shared-state AHK v2 modules for input, inventory, ability selection, chat-safe slot handling, client-relative inventory-panel hit-testing and optional click-through border, remaps, QPC clicking, Roblox context, timer resolution, logging, autoclicker HUD, and PNG mana guide
- Re-selecting the currently equipped paused ability is treated as unequip and restores autoclick permission; different paused-to-paused selections remain no-op transitions
- Compact stacked AHK status HUD aligned beneath the Roblox Menu button reference, with a 56 × 39 autoclicker panel and attached 19-pixel running-state row
- Profile-aware full-canvas mana overlay with exact Roblox-client alignment, optional position/scale/opacity controls, click-through/no-activate behavior, and automatic focus/minimize hiding
- Native topmost/no-activate overlay foundation retained without exposing an inaccurate simulated autoclicker preview

## Actual verification

The following records the earlier project-wide verification. The latest
movement stability results and remaining acceptance gate are listed above.

- `dotnet restore RLMacroHub.sln`: **succeeded** for all four projects.
- Isolated `Release` x64 app build: **succeeded**, 0 warnings and 0 errors (the normal output was locked by the running app).
- Test project: **passed 53/53**, 0 failed/skipped, including default Multi-Directional Backwards Run behavior, removed Double Tap mode migration, persistence/INI projection, reserved-hotkey validation, Gate Macro normalization, profile switching, and existing recovery behavior.
- AutoHotkey v2 `--self-test`: **passed** using the installed v2 interpreter without registering hooks or sending input.
- AutoHotkey v2 `--smoke-test`: **passed**; normal modules/hooks/timers initialized, no Roblox/input was simulated, and `OnExit` logged clean shutdown with code 0.
- AutoHotkey v2 mana overlay probe: **passed**; the byte-identical PNG was decoded into an off-screen GDI+ layered window, scaled to 1920 × 1080, presented with per-pixel alpha, and cleaned up with code 0.
- AutoHotkey v2 scheduler probe: **passed at 121 scheduled events across a one-second inclusive boundary** (120 intervals/second) without sending mouse input; the previous `Sleep 1` implementation reproduced the reported limit at 65.
- Hidden desktop smoke launch from the normal x64 debug output: **succeeded**; the process created a main-window HWND, remained alive for five seconds, handled `CloseMainWindow`, logged startup/shutdown, and exited with code 0.
- Legacy preservation: the untouched reference under `legacy/` hashes to SHA-256 `09A3D003E6421F726E67D937CEDA351D64F59C62F6D93663D15804DB97464455`.
- Legacy execution removal: the app has no v1 discovery, staging, INI export, Settings command, or launch path.

The first launch attempt exposed that Windows App SDK 2.4 was not registered machine-wide (`REGDB_E_CLASSNOTREG`). Enabling the stable SDK's self-contained deployment resolved it; no preview API or alternate UI framework was introduced.

## Known limitations and environment blockers

- The workstation has .NET SDK 9.0.200, not the requested .NET 10 LTS SDK, so projects currently target .NET 9 and are ready to retarget when .NET 10 is installed.
- The modular runtime and mana overlay creation path have been executed locally, but real Roblox input behavior and overlay following still require an in-game validation session.
- The inventory panel defaults are calibrated from one supplied 1920 × 1080 screenshot. Normalized positioning should scale, but different game UI layouts may require adjusting the four percentages in Autoclicker settings.
- Start-with-Windows and minimize-to-tray controls are intentionally shown as planned/disabled.
- The AHK runtime has no structured IPC yet, so enabled state and CPS cannot drive a truthful WinUI preview; the Overlay page intentionally omits one for now.
- The native overlay window/service foundation is dormant until live elements and editor affordances are implemented.
- Because .NET 10 is absent, the .NET 9 compiler/toolkit combination uses field-based MVVM generation with `MVVMTK0045` scoped out; retargeting should adopt the newer partial-property form.

## Best next five tasks

1. Complete the Multi-Directional in-game acceptance checklist and fix reproducible failures before considering image detection.
2. Add structured IPC between the modular AHK v2 runtime and C# for enabled state, CPS, and actionable errors.
3. Build a keyboard/mouse capture dialog with conflict detection for the keybind editor.
4. Implement drag/edit/save behavior for overlay elements with per-monitor DPI conversion.
5. Add staged-runtime version metadata, stale-file cleanup/migration, and shutdown/orphan-process diagnostics.
