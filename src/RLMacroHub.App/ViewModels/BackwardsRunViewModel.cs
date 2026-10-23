using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using RLMacroHub.Core.Models;
using RLMacroHub.Core.Services;
using RLMacroHub.Infrastructure.Configuration;

namespace RLMacroHub.App.ViewModels;

public sealed partial class BackwardsRunViewModel : ObservableObject
{
    private readonly ISettingsService _settings;
    private readonly IProfileService _profiles;
    private readonly RuntimeIniAdapter _runtimeIniAdapter;
    private readonly AppPaths _paths;
    private readonly SynchronizationContext? _synchronizationContext;

    [ObservableProperty] private bool _enabled;
    [ObservableProperty] private int _selectedModeIndex;
    [ObservableProperty] private string _selectedResetHotkey = "Unbound";
    [ObservableProperty] private string _saveStatus = string.Empty;

    public BackwardsRunViewModel(
        ISettingsService settings,
        IProfileService profiles,
        RuntimeIniAdapter runtimeIniAdapter,
        AppPaths paths)
    {
        _settings = settings;
        _profiles = profiles;
        _runtimeIniAdapter = runtimeIniAdapter;
        _paths = paths;
        _synchronizationContext = SynchronizationContext.Current;
        LoadFrom(settings.Current.BackwardsRun);
        settings.SettingsChanged += OnSettingsChanged;
    }

    [RelayCommand]
    private async Task SaveAsync()
    {
        string resetHotkey = SelectedResetHotkey == "Unbound" ? string.Empty : SelectedResetHotkey;
        string? error = BackwardsRunConfiguration.GetResetHotkeyError(resetHotkey,
            _settings.Current.Autoclicker.ToggleHotkey, _settings.Current.Keybinds.Bindings);
        if (error is not null)
        {
            SaveStatus = error;
            return;
        }
        _settings.Current.BackwardsRun.ResetHotkey = resetHotkey;
        _settings.Current.BackwardsRun.Enabled = Enabled;
        _settings.Current.BackwardsRun.Mode = SelectedModeIndex switch
        {
            1 => BackwardsRunMode.Legacy,
            _ => BackwardsRunMode.MultiDirectional
        };
        await _settings.SaveAsync(_settings.Current);
        await _profiles.SaveActiveSettingsAsync();
        await _runtimeIniAdapter.ExportAsync(_settings.Current, _paths.ModernRuntimeConfigurationFile);
        LoadFrom(_settings.Current.BackwardsRun);
        SaveStatus = "Backwards Run saved to the active profile — reload a running AHK runtime to apply.";
    }

    private void LoadFrom(BackwardsRunConfiguration configuration)
    {
        Enabled = configuration.Enabled;
        SelectedResetHotkey = ResetHotkeyOptions.FirstOrDefault(key =>
            string.Equals(key, configuration.ResetHotkey, StringComparison.OrdinalIgnoreCase)) ?? "Unbound";
        SelectedModeIndex = configuration.Mode switch
        {
            BackwardsRunMode.Legacy => 1,
            _ => 0
        };
    }

    public IReadOnlyList<string> ResetHotkeyOptions { get; } =
        new[] { "Unbound" }.Concat(BackwardsRunConfiguration.ResetHotkeys).ToArray();

    private void OnSettingsChanged(object? sender, AppConfiguration configuration)
    {
        void Reload() => LoadFrom(configuration.BackwardsRun);
        if (_synchronizationContext is null)
        {
            Reload();
        }
        else
        {
            _synchronizationContext.Post(_ => Reload(), null);
        }
    }
}
