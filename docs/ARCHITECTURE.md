# Architecture

RL Macro Hub is a small layered desktop application. Dependencies point inward; UI state does not own process, filesystem, or raw Win32 behavior.

```text
WinUI UI (Windows, Pages, XAML)
             ↓
        ViewModels
             ↓
       Core interfaces
             ↓
      Infrastructure
      ├── JSON config / INI export
      ├── profiles / app paths / logs
      ├── Roblox window tracking / Win32
      └── AutoHotkey v2 runtime lifecycle
```

## Projects

`RLMacroHub.Core` targets plain `net9.0` and contains versioned configuration models, macro metadata, runtime/window state records, and the five application service contracts. It has no WinUI or Windows dependency.

`RLMacroHub.Infrastructure` implements durable configuration, profiles, logging, process ownership, and Windows integration. P/Invoke declarations are centralized in `Windows/NativeMethods.cs`; view models never use raw window handles directly.

`RLMacroHub.App` is the composition root. It constructs the dependency-injection container, loads configuration before showing the main window, starts Roblox tracking, and owns orderly shutdown. Pages use constructor-injected view models. Code-behind is limited to WinUI lifecycle/navigation and HWND-oriented window plumbing.

The app is still an MSIX/packaged project, but Windows App SDK native components are emitted self-contained. This permits local debug launch on development machines where the 2.4 runtime package has not been installed globally and avoids silently downgrading the selected stable SDK.

`RLMacroHub.Tests` exercises persistence, defaults, recovery, validation, runtime configuration output, and profile operations without loading WinUI.

## State and persistence

`AppConfiguration` is the canonical, versioned JSON document. `JsonSettingsService` serializes to a same-directory temporary file and replaces the destination only after serialization and flush complete. A malformed document is moved to a timestamped `config.corrupt.*.json` file and defaults are restored.

Profiles are separate JSON files. The active profile ID is stored in general configuration. Autoclicker and Keybind saves write validated state back to that profile and regenerate the staged runtime configuration. Before activation, the profile being left is persisted; the selected profile's macro settings are then published through `ISettingsService` so Dashboard and bound editors refresh. App-global preferences, including the explicit AHK executable path, are preserved across switches. The default/final profile cannot be deleted, and deleting the active non-default profile loads the default profile.

The INI file is a generated runtime artifact, never the application's source of truth. `RuntimeIniAdapter` exports every binding to the modular v2 runtime; the C# collection has no fixed row limit.

## Runtime boundaries

The C# app does not attempt to schedule high-frequency clicks. It stages `RLMacroHub.Runtime.ahk` and its modules, emits the v2 runtime configuration, resolves only an AutoHotkey v2 executable, and owns that child process. Shutdown first posts `WM_CLOSE` so the runtime's `OnExit` callback can restore timer resolution. Tree termination is a logged, timeout-based fallback. The audited v1 script is archival source and has no launch or configuration path in the app.

The v2 runtime is one process with multiple source modules and one `RuntimeState` instance. Input, inventory, remapping, selected-ability policy, and autoclick eligibility therefore transition synchronously without cross-process races. See `MODERN_AHK_RUNTIME.md` for its extension contract.

`RobloxWindowService` uses a one-second `PeriodicTimer`. It emits only when observable state changes, so the dashboard and dormant native overlay do no work on unchanged ticks. The interval handles launch, exit, movement, resize, minimize/restore, and foreground changes without busy polling.

The native overlay foundation remains a separate dormant WinUI window with tool/no-activate and click-through support. The Overlay page intentionally shows no simulated telemetry preview until structured runtime telemetry can drive it. For now, the live autoclicker/running-state HUD and PNG mana guide are rendered and positioned by the AHK runtime.

View models use CommunityToolkit.Mvvm field-based `[ObservableProperty]` generation. The .NET 9.0.200 compiler installed for this initialization does not provide the toolkit's generated implementation for its newer partial-property form, so diagnostic `MVVMTK0045` is scoped out until the planned .NET 10 retarget; the application is not NativeAOT-enabled.
