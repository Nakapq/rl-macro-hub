# Modern AutoHotkey runtime

## Design goal

The runtime is modular in source but singular in execution. `RLMacroHub.Runtime.ahk` is the only entry point and creates exactly one shared `RuntimeState`. This preserves the legacy behavioral coupling without growing another monolithic script.

```text
RLMacroHub.Runtime.ahk
├── Configuration/RuntimeConfiguration.ahk
├── Shared/
│   ├── RuntimeState.ahk
│   └── RuntimePolicy.ahk
├── Modules/
│   ├── RobloxContext.ahk
│   ├── InventoryPanelGuard.ahk
│   ├── InventoryPanelOverlay.ahk
│   ├── ManaOverlay.ahk
│   ├── InventoryController.ahk
│   ├── AbilitySelectionController.ahk
│   ├── BackwardsRunModule.ahk
│   ├── GateMacroModule.ahk
│   ├── InputCoordinator.ahk
│   ├── KeybindModule.ahk
│   ├── AutoclickerModule.ahk
│   └── StatusOverlay.ahk
├── Infrastructure/
│   ├── RuntimeLogger.ahk
│   ├── HighResolutionWaiter.ahk
│   └── TimerResolutionLease.ahk
└── Testing/
    ├── RuntimeSelfTest.ahk
    ├── ManaOverlayProbe.ahk
    └── SchedulerProbe.ahk
```

## State ownership and invariants

`RuntimeState` contains transient facts: master enabled state, selected ability slot, ability-level autoclick permission, physical LMB state/timestamp, inventory state, typing suppression, remap ownership, scheduler ownership, and CPS counters. Configuration objects contain desired settings but no changing input state.

All modules receive the same state object. The important invariants remain:

- Autoclicking requires foreground Roblox, master enabled state, permission from the selected ability, a physical LMB hold beyond the threshold, no typing, and no active remap.
- Every `1`–`=` slot has an explicit enabled/disabled autoclick policy. Switching to a different slot with the same policy updates selected-slot identity but performs no redundant stop or restart. Pressing the currently selected disabled slot again is treated as unequipping it, clears the selection, and restores autoclick permission.
- Physical slot presses and keybinds targeting a slot both use the same `AbilitySelectionController`.
- Inventory state alone does not suppress autoclicking. When the inventory is open, only a pointer inside the configured inventory panel rectangle blocks generated clicks.
- Remaps remain available in inventory and update inventory state when their target is the inventory key.
- Closing inventory can force the master state enabled and resumes an already-held LMB only when the selected ability permits it.
- Modifier chords pass through instead of being needlessly remapped.
- Backwards Run preserves physical directional input and offers three profile-scoped modes. Legacy retains the held-`W`/`S` arrow sequence. Double Tap retains independent 200 ms `A`/`S`/`D` activation. Multi-Directional accepts a 200 ms double tap on `W`, `A`, `S`, or `D`, establishes the neutral mana-run state with Up Arrow, and keeps one axis active. `W`/`S` transitions swap held Up/Down Arrow output; `A`/`D` transitions temporarily release the previously held physical direction so the two keys do not cancel. During a lateral session, physical `W` is held as synthetic Up Arrow input so it cannot disturb the synthetic `W` foundation. Releasing the newer direction falls back to the opposite direction when that key is still physically held, and the session ends when neither axis key remains held. Remap activity blocks new activation without interrupting an active session; chat, focus loss, and the master runtime toggle cancel active output. See [Mana running](MANA_RUNNING.md) for the state model.
- Chat typing suppression is independent of the Gate Macro setting. `/` marks the runtime as typing-paused, so autoclicking stops and bound sources pass through unchanged; Enter or Escape clears the pause without changing the master enabled state.
- Gate notation capture begins only when `/` opens Roblox chat. Enter compares the current token against the configured map without case sensitivity, replaces an exact match, and only then sends Enter to Roblox. Escape, Enter, a physical click, or loss of Roblox focus ends the capture so it cannot span ordinary gameplay. Unmatched chat text is submitted unchanged.
- The QPC scheduler emits at most one due click and resets a late deadline, never replaying missed clicks as a burst.
- Scheduler waits use a reusable Windows high-resolution waitable timer. This avoids the approximately 15.4 ms effective `Sleep 1` interval observed on the development machine, which had limited a nominal 120 CPS setting to roughly 65 CPS.

## Configuration contract

The app's JSON document remains canonical. `RuntimeIniAdapter` creates `RLMacroHub.Runtime.ini` in the staged runtime directory with these sections:

- `[Runtime]`: schema version
- `[General]`: toggle hotkey
- `[Autoclicker]`: enabled state, CPS, hold threshold, and inventory-close policy
- `[InventoryPanel]`: whether the exclusion is active, whether its border is shown, and its normalized client-relative left/top/right/bottom edges
- `[AbilitySlots]`: the twelve fixed slot keys and their boolean autoclick policies
- `[Keybinds]`: enabled state and dynamic binding count
- `[Bindings]`: numbered source/target pairs with no legacy ten-row limit
- `[GateMacro]`: enabled state and mapping count
- `[GateMappings]`: numbered notation/location pairs used for exact chat expansion
- `[BackwardsRun]`: enabled state and `Legacy`/`DoubleTap`/`MultiDirectional` activation mode
- `[Overlay]`: transitional HUD visibility, click-through behavior, size, and Roblox-relative offsets
- `[ManaOverlay]`: visibility, normalized client position, scale, and opacity for the PNG mana guide

The status HUD defaults to `56 × 39` pixels and starts at `RobloxRight - 348`, `RobloxTop + 96`. On the supplied 1920 × 1080 reference this gives it approximately the Roblox Menu button's width and aligns its left edge beneath that button. Configurations and profiles still carrying the prior untouched `94 × 39` / `373`-pixel defaults are normalized to the new placement; non-default customized coordinates are preserved.

The inventory defaults were measured from [`Screenshot 2026-09-05 214417.png`](Screenshot%202026-09-05%20214417.png): `(479, 458)` through `(1442, 1000)` in a `1920 × 1080` Roblox client. They are stored as normalized ratios, then projected into the current Roblox client rectangle. This makes the guard resolution- and window-position-aware, while keeping all four edges configurable in the WinUI autoclicker page. The optional cyan border is a non-activating, click-through overlay using the same projected bounds; it appears only while Roblox is active.

The mana overlay renders the complete [`improvedmanabar.png`](improvedmanabar.png) transparent `1920 × 1080` canvas over the Roblox client. The runtime asset is a byte-for-byte copy of that source and uses a GDI+ layered window so the PNG's per-pixel alpha and original colors are preserved. Preserving the source canvas also preserves its authored alignment; optional position and scale values adjust the whole canvas. Like the autoclicker HUD, it is non-activating, click-through, and hidden unless Roblox is focused.

The client rectangle is cached for 100 ms while the inventory is open; cursor hit-testing remains fast enough to stop before the next scheduled generated click. If Roblox bounds cannot be obtained, the guard fails open so a stale rectangle cannot suppress unrelated screen areas.

Ability display names intentionally stay in canonical JSON/profile files and are never exported to AHK. Slot keys are the stable identity; names are optional organizational labels. All slots default to allowing autoclicking so an older configuration preserves its behavior until the user opts specific abilities out.

Gate notations accept 1–20 ASCII letters, digits, hyphens, or underscores and are unique without regard to case. Default mappings include both numbered locations and their unnumbered base aliases, such as `d` for `desert`, `s` for `shore`, and `fo` for `forge`. Prefix pairs such as `d5` and `d50` may coexist because lookup happens only on Enter. Locations accept up to 120 characters. After `/` opens chat, a visible `InputHook` keeps the most recent notation-shaped token; non-notation characters and a five-second typing gap reset the token. Submission requires both the active capture and the chat typing guard. On Enter, an exact match is selected and replaced through a temporary clipboard paste, the original clipboard contents are restored, and Enter is sent afterward. The capture is cancelled on Enter, Escape, physical click, Roblox focus loss, shutdown, or hook failure. This avoids character-level remaps interfering with location names while preventing gameplay input from reaching the replacement path.

The loader validates ranges, skips incomplete/duplicate/conflicting bindings and gate mappings, and restores defaults if parsing fails. Runtime configuration is read once at startup; the tray's Reload command restarts the process. Live configuration reload should arrive with structured IPC.

State-observer sources are currently reserved: `/`, Enter/Escape, `SC029`, LMB, `W`, `A`, `S`, `D`, and the number-row ability keys. The WinUI editor rejects these as remap sources so a dynamic registration cannot replace a state-critical observer. They remain valid remap targets. A future centralized multi-subscriber hotkey router can relax this restriction safely.

## Adding a module

1. Create one focused class under `Modules/`; inject only the state, configuration, context, logger, and collaborators it needs.
2. Include it from the entry point and construct it in `MacroRuntime.__New`.
3. Register timers/hotkeys in `Start` and always unregister them in `Shutdown`.
4. Add new persistent settings to the C# model and `RuntimeIniAdapter`, then validate/default them in `RuntimeConfiguration.ahk`.
5. Put pure eligibility/state-transition rules in `Shared/RuntimePolicy.ahk` so `--self-test` can exercise them without hooks or input.
6. Never create another independent AHK process for a module that shares input state.

## Validation modes

`--self-test` validates parsing and policy without hooks, timer-resolution changes, windows, or input. `--smoke-test` performs normal startup and exits after one second through `OnExit`. `Testing/ManaOverlayProbe.ahk` creates the per-pixel-alpha layered window off-screen and tears it down immediately. `Testing/SchedulerProbe.ahk` exercises the real precision waiter and QPC no-burst schedule for one second without sending mouse input. None of these modes launches Roblox or simulates clicks.

The untouched v1 script remains under `legacy/` solely for regression and behavioral reference. RL Macro Hub does not stage, configure, or launch it.
