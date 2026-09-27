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
        _settings.Current.BackwardsRun.Enabled = Enabled;
        _settings.Current.BackwardsRun.Mode = SelectedModeIndex switch
        {
            1 => BackwardsRunMode.DoubleTap,
            2 => BackwardsRunMode.MultiDirectional,
            _ => BackwardsRunMode.Legacy
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
        SelectedModeIndex = configuration.Mode switch
        {
            BackwardsRunMode.DoubleTap => 1,
            BackwardsRunMode.MultiDirectional => 2,
            _ => 0
        };
    }

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
