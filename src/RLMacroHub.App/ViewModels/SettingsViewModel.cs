using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using RLMacroHub.Core.Services;
using RLMacroHub.Infrastructure.Configuration;

namespace RLMacroHub.App.ViewModels;

public sealed partial class SettingsViewModel : ObservableObject
{
    private readonly ISettingsService _settings;
    private readonly RuntimeIniAdapter _runtimeIniAdapter;
    private readonly AppPaths _paths;

    [ObservableProperty] private bool _startWithWindows;
    [ObservableProperty] private bool _minimizeToTray;
    [ObservableProperty] private string _autoHotkeyExecutablePath = string.Empty;
    [ObservableProperty] private string _statusMessage = string.Empty;
    [ObservableProperty] private bool _hasActionableError;

    public SettingsViewModel(ISettingsService settings, RuntimeIniAdapter runtimeIniAdapter, AppPaths paths)
    {
        _settings = settings;
        _runtimeIniAdapter = runtimeIniAdapter;
        _paths = paths;
        StartWithWindows = settings.Current.General.StartWithWindows;
        MinimizeToTray = settings.Current.General.MinimizeToTray;
        AutoHotkeyExecutablePath = settings.Current.General.AutoHotkeyExecutablePath ?? string.Empty;
    }

    public string DataDirectory => _paths.RootDirectory;

    [RelayCommand]
    private async Task SaveAsync()
    {
        _settings.Current.General.StartWithWindows = StartWithWindows;
        _settings.Current.General.MinimizeToTray = MinimizeToTray;
        _settings.Current.General.AutoHotkeyExecutablePath = string.IsNullOrWhiteSpace(AutoHotkeyExecutablePath)
            ? null
            : AutoHotkeyExecutablePath.Trim();
        await _settings.SaveAsync(_settings.Current);
        StatusMessage = "Application settings saved.";
        HasActionableError = false;
    }

    [RelayCommand]
    private async Task ExportRuntimeIniAsync()
    {
        await _runtimeIniAdapter.ExportAsync(_settings.Current, _paths.ModernRuntimeConfigurationFile);
        StatusMessage = $"Runtime configuration exported to {_paths.ModernRuntimeConfigurationFile}";
        HasActionableError = false;
    }
}
