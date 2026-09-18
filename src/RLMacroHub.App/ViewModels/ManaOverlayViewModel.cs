using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using RLMacroHub.Core.Models;
using RLMacroHub.Core.Services;
using RLMacroHub.Infrastructure.Configuration;

namespace RLMacroHub.App.ViewModels;

public sealed partial class ManaOverlayViewModel : ObservableObject
{
    private readonly ISettingsService _settings;
    private readonly IProfileService _profiles;
    private readonly RuntimeIniAdapter _runtimeIniAdapter;
    private readonly AppPaths _paths;
    private readonly SynchronizationContext? _synchronizationContext;

    [ObservableProperty] private bool _enabled;
    [ObservableProperty] private double _horizontalPositionPercent;
    [ObservableProperty] private double _verticalPositionPercent;
    [ObservableProperty] private double _scalePercent;
    [ObservableProperty] private double _opacityPercent;
    [ObservableProperty] private string _saveStatus = string.Empty;

    public ManaOverlayViewModel(
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
        LoadFrom(settings.Current.ManaOverlay);
        settings.SettingsChanged += OnSettingsChanged;
    }

    [RelayCommand]
    private async Task SaveAsync()
    {
        ManaOverlayConfiguration configuration = _settings.Current.ManaOverlay;
        configuration.Enabled = Enabled;
        configuration.NormalizedX = HorizontalPositionPercent / 100d;
        configuration.NormalizedY = VerticalPositionPercent / 100d;
        configuration.Scale = ScalePercent / 100d;
        configuration.Opacity = OpacityPercent / 100d;
        await _settings.SaveAsync(_settings.Current);
        await _profiles.SaveActiveSettingsAsync();
        await _runtimeIniAdapter.ExportAsync(_settings.Current, _paths.ModernRuntimeConfigurationFile);
        LoadFrom(_settings.Current.ManaOverlay);
        SaveStatus = "Saved — reload a running AHK runtime to apply.";
    }

    [RelayCommand]
    private void RestoreReferencePosition()
    {
        HorizontalPositionPercent = ManaOverlayConfiguration.DefaultNormalizedX * 100d;
        VerticalPositionPercent = ManaOverlayConfiguration.DefaultNormalizedY * 100d;
        ScalePercent = ManaOverlayConfiguration.DefaultScale * 100d;
        OpacityPercent = ManaOverlayConfiguration.DefaultOpacity * 100d;
    }

    private void LoadFrom(ManaOverlayConfiguration configuration)
    {
        Enabled = configuration.Enabled;
        HorizontalPositionPercent = configuration.NormalizedX * 100d;
        VerticalPositionPercent = configuration.NormalizedY * 100d;
        ScalePercent = configuration.Scale * 100d;
        OpacityPercent = configuration.Opacity * 100d;
    }

    private void OnSettingsChanged(object? sender, AppConfiguration configuration)
    {
        void Reload() => LoadFrom(configuration.ManaOverlay);
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
