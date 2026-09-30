# RL Macro Hub

RL Macro Hub is a native Windows desktop manager for Roblox-focused AutoHotkey macros and lightweight in-game overlays. The application manages configuration, keybinds, profiles, Roblox discovery, and a modular AutoHotkey v2 runtime. The original v1 macro is retained only as an archived behavioral reference.

## Current capabilities

- Dark WinUI 3 shell with dashboard and macro navigation
- Live Roblox process/window, focus, minimized-state, and bounds tracking
- JSON configuration with validation, atomic writes, malformed-file recovery, and defaults
- Autoclicker settings with the existing 120 CPS reference behavior, a configurable Roblox-relative inventory-panel exclusion region, and per-profile `1`–`=` ability policies with optional names
- Dynamic keybinding editor with validation and no fixed legacy row limit
- Profile-scoped Gate Macro editor with editable Gaia/Khei starter mappings and exact, case-insensitive chat shorthand expansion
- Profile-scoped Backwards Run macro with legacy `W` + `S`, independent double-tap `A`/`S`/`D`, and multi-directional `W`/`A`/`S`/`D` activation with opposite-direction transitions
- Local profile create, rename, activate, guarded delete, and reliable per-profile macro-setting restoration
- Single-process, shared-state AutoHotkey v2 runtime split into focused modules
- AutoHotkey v2 discovery, duplicate prevention, Dashboard lifecycle controls, graceful close, and forced termination fallback
- Focus-aware, click-through AHK overlays for autoclicker status, inventory calibration, and the supplied PNG mana guide
- Daily local file logging

Cooldown Indicators remain visible as a planned module, not a fake implementation. Backwards Run, Gate Macro, and Mana Overlay are configurable and available in the modular runtime.

## Requirements

- Windows 10 version 1809 or newer; Windows 11 is recommended for the best Mica appearance
- Visual Studio 2022/compatible MSBuild with Desktop C++/Windows SDK and WinUI tooling, or the .NET CLI
- .NET 9 SDK in the current initialization environment; retarget to .NET 10 when that SDK is installed
- Windows App SDK 2.4.0 stable (restored from NuGet and included self-contained in the app output)
- AutoHotkey **v2.0** for the modular runtime

RL Macro Hub only launches the modular v2 entry point. The untouched v1 script under `legacy/` is not staged, configured, or exposed as a runnable fallback.

## Build and test

```powershell
dotnet restore RLMacroHub.sln
dotnet build RLMacroHub.sln -c Debug -p:Platform=x64
dotnet test tests/RLMacroHub.Tests/RLMacroHub.Tests.csproj -c Debug

# Optional AHK v2 validation; does not register hooks or send input
AutoHotkey.exe /ErrorStdOut src/RLMacroHub.Runtime/RLMacroHub.Runtime.ahk --self-test
```

To run from Visual Studio, select `RLMacroHub.App` as the startup project and the `x64` target. For command-line development, build first and launch the generated executable/MSIX deployment target appropriate to your local WinUI setup.

User data is stored under `%LOCALAPPDATA%\RLMacroHub\`:

```text
config.json
profiles\
logs\
runtime\
```

The runtime directory's `modern/` staging area receives all AHK modules and `RLMacroHub.Runtime.ini`. JSON remains the source of truth.

## Project layout

```text
src/
  RLMacroHub.App/             WinUI windows, pages, view models, styles, overlay
  RLMacroHub.Core/            Platform-independent models and service contracts
  RLMacroHub.Infrastructure/  JSON/INI, profiles, AHK, Roblox/Win32, logging
  RLMacroHub.Runtime/         Modular AutoHotkey v2 runtime and self-tests
tests/
  RLMacroHub.Tests/           Non-UI xUnit tests
legacy/                       Untouched, non-runnable AHK v1 reference source
docs/                         Architecture, audit, and roadmap
```

See [Architecture](docs/ARCHITECTURE.md), [modern runtime](docs/MODERN_AHK_RUNTIME.md), [mana running](docs/MANA_RUNNING.md), [legacy audit](docs/LEGACY_MACRO_AUDIT.md), [roadmap](docs/ROADMAP.md), and [project status](PROJECT_STATUS.md).
