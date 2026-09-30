using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Extensions.Logging;
using RLMacroHub.Core.Models;
using RLMacroHub.Core.Services;
using RLMacroHub.Infrastructure.Configuration;
using RLMacroHub.Infrastructure.Macros;

namespace RLMacroHub.App.ViewModels;

public sealed partial class DashboardViewModel : ObservableObject
{
    private readonly ISettingsService _settings;
    private readonly IMacroRuntimeService _runtime;
    private readonly RuntimeIniAdapter _runtimeIniAdapter;
    private readonly RuntimeAssetStager _runtimeStager;
    private readonly AppPaths _paths;
    private readonly ILogger<DashboardViewModel> _logger;
    private readonly SynchronizationContext? _synchronizationContext;

    [ObservableProperty]
    private string _robloxStatus = "Not detected";

    [ObservableProperty]
    private string _robloxIndicator = "○";

    [ObservableProperty]
    private string _robloxDetail = "Launch Roblox and detection will update automatically.";

    [ObservableProperty]
    private string _runtimeStatus = "Stopped";

    [ObservableProperty]
    private string _runtimeIndicator = "○";

    [ObservableProperty]
    private string _runtimeDetail = "AutoHotkey is not running.";

    [ObservableProperty]
    private string _runtimeActionMessage = string.Empty;

    [ObservableProperty]
    private bool _canStartRuntime = true;

    [ObservableProperty]
    private bool _canStopRuntime;

    [ObservableProperty]
    private string _autoclickerSummary = "120 CPS max";

    [ObservableProperty]
    private string _keybindSummary = "5 bindings";

    [ObservableProperty]
    private string _gateMacroSummary = "0 mappings";

    public DashboardViewModel(
        ISettingsService settings,
        IRobloxWindowService roblox,
        IMacroRuntimeService runtime,
        RuntimeIniAdapter runtimeIniAdapter,
        RuntimeAssetStager runtimeStager,
        AppPaths paths,
        ILogger<DashboardViewModel> logger)
    {
        _settings = settings;
        _runtime = runtime;
        _runtimeIniAdapter = runtimeIniAdapter;
        _runtimeStager = runtimeStager;
        _paths = paths;
        _logger = logger;
        _synchronizationContext = SynchronizationContext.Current;
        ApplyRobloxState(roblox.Current);
        ApplyRuntimeState(runtime.State, runtime.LastError);
        RefreshSettings(settings.Current);
        roblox.StateChanged += (_, state) => Post(() => ApplyRobloxState(state));
        runtime.StateChanged += (_, state) => Post(() => ApplyRuntimeState(state, runtime.LastError));
        settings.SettingsChanged += (_, configuration) => Post(() => RefreshSettings(configuration));
    }

    public event Action<string>? NavigationRequested;

    public string AutoclickerState => _settings.Current.Autoclicker.Enabled ? "Enabled" : "Disabled";
    public string KeybindState => _settings.Current.Keybinds.Enabled ? "Enabled" : "Disabled";
    public string BackwardsRunState => _settings.Current.BackwardsRun.Enabled ? "Enabled" : "Disabled";
    public string GateMacroState => _settings.Current.GateMacro.Enabled ? "Enabled" : "Disabled";
    public string ManaOverlayState => _settings.Current.ManaOverlay.Enabled ? "Enabled" : "Disabled";

    [RelayCommand]
    private void Configure(string page) => NavigationRequested?.Invoke(page);

    [RelayCommand]
    private async Task StartRuntimeAsync()
    {
        string? sourceDirectory = _paths.FindModernRuntimeDirectory();
        if (sourceDirectory is null)
        {
            RuntimeActionMessage = "The modular AHK v2 runtime source is missing.";
            return;
        }

        try
        {
            _paths.EnsureCreated();
            string runtimeScript = _runtimeStager.StageModernRuntime(sourceDirectory, _paths.ModernRuntimeDirectory);
            await _runtimeIniAdapter.ExportAsync(_settings.Current, _paths.ModernRuntimeConfigurationFile);
            await _runtime.StartAsync(runtimeScript, _settings.Current.General.AutoHotkeyExecutablePath);
            RuntimeActionMessage = _runtime.LastError ?? "Runtime started with the active profile configuration.";
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
            _logger.LogError(exception, "Could not prepare the modular AHK runtime.");
            RuntimeActionMessage = "The runtime could not be prepared. See the application log.";
        }
    }

    [RelayCommand]
    private async Task StopRuntimeAsync()
    {
        await _runtime.StopAsync();
        RuntimeActionMessage = "Runtime stopped cleanly.";
    }

    private void ApplyRobloxState(RobloxWindowState state)
    {
        RobloxIndicator = state.IsRunning ? "●" : "○";
        RobloxStatus = state.IsRunning ? (state.IsForeground ? "Connected · focused" : "Connected") : "Not detected";
        RobloxDetail = state.IsRunning
            ? state.IsMinimized ? "Roblox is minimized." : $"{state.Bounds.Width} × {state.Bounds.Height} window"
            : "Launch Roblox and detection will update automatically.";
    }

    private void ApplyRuntimeState(MacroRuntimeState state, string? error)
    {
        RuntimeIndicator = state == MacroRuntimeState.Running ? "●" : "○";
        RuntimeStatus = state.ToString();
        CanStartRuntime = state is MacroRuntimeState.Stopped or MacroRuntimeState.Faulted or MacroRuntimeState.Unavailable;
        CanStopRuntime = state is MacroRuntimeState.Starting or MacroRuntimeState.Running;
        RuntimeDetail = error ?? state switch
        {
            MacroRuntimeState.Running => "Macro runtime process is owned by RL Macro Hub.",
            MacroRuntimeState.Starting => "Starting AutoHotkey runtime…",
            MacroRuntimeState.Stopping => "Closing the macro cleanly…",
            _ => "AutoHotkey is not running."
        };
    }

    private void RefreshSettings(AppConfiguration configuration)
    {
        AutoclickerSummary = $"{configuration.Autoclicker.MaximumCps} CPS max";
        KeybindSummary = $"{configuration.Keybinds.Bindings.Count} bindings";
        GateMacroSummary = $"{configuration.GateMacro.Mappings.Count} mappings";
        OnPropertyChanged(nameof(AutoclickerState));
        OnPropertyChanged(nameof(KeybindState));
        OnPropertyChanged(nameof(BackwardsRunState));
        OnPropertyChanged(nameof(GateMacroState));
        OnPropertyChanged(nameof(ManaOverlayState));
    }

    private void Post(Action action)
    {
        if (_synchronizationContext is null)
        {
            action();
        }
        else
        {
            _synchronizationContext.Post(_ => action(), null);
        }
    }
}
