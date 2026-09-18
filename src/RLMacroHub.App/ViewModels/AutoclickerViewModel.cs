using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using RLMacroHub.Core.Models;
using RLMacroHub.Core.Services;
using RLMacroHub.Infrastructure.Configuration;

namespace RLMacroHub.App.ViewModels;

public sealed partial class AutoclickerViewModel : ObservableObject
{
    private readonly ISettingsService _settings;
    private readonly IProfileService _profiles;
    private readonly RuntimeIniAdapter _runtimeIniAdapter;
    private readonly AppPaths _paths;
    private readonly SynchronizationContext? _synchronizationContext;

    [ObservableProperty] private bool _enabled;
    [ObservableProperty] private string _toggleHotkey = string.Empty;
    [ObservableProperty] private double _maximumCps;
    [ObservableProperty] private double _holdThresholdMs;
    [ObservableProperty] private bool _suppressOverInventoryPanel;
    [ObservableProperty] private bool _showInventoryExclusionBorder;
    [ObservableProperty] private double _inventoryLeftPercent;
    [ObservableProperty] private double _inventoryTopPercent;
    [ObservableProperty] private double _inventoryRightPercent;
    [ObservableProperty] private double _inventoryBottomPercent;
    [ObservableProperty] private bool _forceEnabledWhenInventoryCloses;
    [ObservableProperty] private bool _showOverlayStatus;
    [ObservableProperty] private string _saveStatus = string.Empty;

    public AutoclickerViewModel(
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
        LoadFrom(settings.Current.Autoclicker);
        settings.SettingsChanged += OnSettingsChanged;
    }

    public ObservableCollection<AbilitySlotConfiguration> AbilitySlots { get; } = [];

    [RelayCommand]
    private async Task SaveAsync()
    {
        var configuration = _settings.Current.Autoclicker;
        configuration.Enabled = Enabled;
        configuration.ToggleHotkey = ToggleHotkey;
        configuration.MaximumCps = (int)Math.Round(MaximumCps);
        configuration.HoldThresholdMs = (int)Math.Round(HoldThresholdMs);
        configuration.InventoryPanel.SuppressAutoclicks = SuppressOverInventoryPanel;
        configuration.InventoryPanel.ShowBorder = ShowInventoryExclusionBorder;
        configuration.InventoryPanel.NormalizedLeft = InventoryLeftPercent / 100d;
        configuration.InventoryPanel.NormalizedTop = InventoryTopPercent / 100d;
        configuration.InventoryPanel.NormalizedRight = InventoryRightPercent / 100d;
        configuration.InventoryPanel.NormalizedBottom = InventoryBottomPercent / 100d;
        configuration.ForceEnabledWhenInventoryCloses = ForceEnabledWhenInventoryCloses;
        configuration.ShowOverlayStatus = ShowOverlayStatus;
        configuration.AbilitySlots = new ObservableCollection<AbilitySlotConfiguration>(
            AbilitySlots.Select(slot => new AbilitySlotConfiguration(slot.Slot, slot.Name, slot.AutoclickerEnabled)));
        await _settings.SaveAsync(_settings.Current);
        await _profiles.SaveActiveSettingsAsync();
        await _runtimeIniAdapter.ExportAsync(_settings.Current, _paths.ModernRuntimeConfigurationFile);
        LoadFrom(_settings.Current.Autoclicker);
        SaveStatus = "Saved — reload a running AHK runtime to apply.";
    }

    private void LoadFrom(AutoclickerConfiguration configuration)
    {
        Enabled = configuration.Enabled;
        ToggleHotkey = configuration.ToggleHotkey;
        MaximumCps = configuration.MaximumCps;
        HoldThresholdMs = configuration.HoldThresholdMs;
        SuppressOverInventoryPanel = configuration.InventoryPanel.SuppressAutoclicks;
        ShowInventoryExclusionBorder = configuration.InventoryPanel.ShowBorder;
        InventoryLeftPercent = configuration.InventoryPanel.NormalizedLeft * 100d;
        InventoryTopPercent = configuration.InventoryPanel.NormalizedTop * 100d;
        InventoryRightPercent = configuration.InventoryPanel.NormalizedRight * 100d;
        InventoryBottomPercent = configuration.InventoryPanel.NormalizedBottom * 100d;
        ForceEnabledWhenInventoryCloses = configuration.ForceEnabledWhenInventoryCloses;
        ShowOverlayStatus = configuration.ShowOverlayStatus;
        AbilitySlots.Clear();
        foreach (AbilitySlotConfiguration slot in configuration.AbilitySlots)
        {
            AbilitySlots.Add(new AbilitySlotConfiguration(slot.Slot, slot.Name, slot.AutoclickerEnabled));
        }
    }

    private void OnSettingsChanged(object? sender, AppConfiguration configuration)
    {
        void Reload() => LoadFrom(configuration.Autoclicker);
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
