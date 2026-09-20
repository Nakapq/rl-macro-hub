using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using RLMacroHub.Core.Models;
using RLMacroHub.Core.Services;
using RLMacroHub.Infrastructure.Configuration;

namespace RLMacroHub.App.ViewModels;

public sealed partial class GateMacroViewModel : ObservableObject
{
    private readonly ISettingsService _settings;
    private readonly IProfileService _profiles;
    private readonly RuntimeIniAdapter _runtimeIniAdapter;
    private readonly AppPaths _paths;
    private readonly SynchronizationContext? _synchronizationContext;

    [ObservableProperty] private bool _enabled;
    [ObservableProperty] private string _statusMessage = string.Empty;
    [ObservableProperty] private bool _hasValidationError;

    public GateMacroViewModel(
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
        LoadFrom(settings.Current.GateMacro);
        settings.SettingsChanged += OnSettingsChanged;
    }

    public ObservableCollection<GateMappingItemViewModel> Mappings { get; } = [];

    [RelayCommand]
    private void AddMapping()
    {
        if (Mappings.Count >= GateMacroConfiguration.MaximumMappings)
        {
            HasValidationError = true;
            StatusMessage = $"At most {GateMacroConfiguration.MaximumMappings} mappings are supported.";
            return;
        }

        Mappings.Add(CreateRow(string.Empty, string.Empty));
        Validate();
    }

    [RelayCommand]
    private void RestoreDefaults()
    {
        Mappings.Clear();
        foreach (GateLocationMapping mapping in GateMacroConfiguration.CreateDefaultMappings())
        {
            Mappings.Add(CreateRow(mapping.Notation, mapping.Location));
        }

        Validate();
        StatusMessage = "Default gate mappings restored — save mappings to apply.";
    }

    [RelayCommand]
    private async Task SaveAsync()
    {
        if (!Validate())
        {
            return;
        }

        _settings.Current.GateMacro.Enabled = Enabled;
        _settings.Current.GateMacro.Mappings = new ObservableCollection<GateLocationMapping>(
            Mappings.Select(row => new GateLocationMapping(row.Notation.Trim(), row.Location.Trim())));
        await _settings.SaveAsync(_settings.Current);
        await _profiles.SaveActiveSettingsAsync();
        await _runtimeIniAdapter.ExportAsync(_settings.Current, _paths.ModernRuntimeConfigurationFile);
        LoadFrom(_settings.Current.GateMacro);
        StatusMessage = "Gate mappings saved to the active profile — reload a running AHK runtime to apply.";
    }

    private GateMappingItemViewModel CreateRow(string notation, string location) =>
        new(notation, location, RemoveMapping, Validate);

    private void RemoveMapping(GateMappingItemViewModel row)
    {
        Mappings.Remove(row);
        Validate();
    }

    private bool Validate()
    {
        HashSet<string> notations = new(StringComparer.OrdinalIgnoreCase);
        bool valid = Mappings.Count <= GateMacroConfiguration.MaximumMappings;
        foreach (GateMappingItemViewModel row in Mappings)
        {
            row.Error = string.Empty;
            string notation = row.Notation.Trim();
            string location = row.Location.Trim();
            if (notation.Length == 0 || location.Length == 0)
            {
                row.Error = "Both notation and location are required.";
                valid = false;
            }
            else if (!GateLocationMapping.IsValidNotation(notation))
            {
                row.Error = $"Use 1–{GateLocationMapping.MaximumNotationLength} letters, numbers, hyphens, or underscores.";
                valid = false;
            }
            else if (location.Length > GateLocationMapping.MaximumLocationLength)
            {
                row.Error = $"Locations can contain at most {GateLocationMapping.MaximumLocationLength} characters.";
                valid = false;
            }
            else if (!notations.Add(notation))
            {
                row.Error = "Notation is duplicated.";
                valid = false;
            }
        }

        HasValidationError = !valid;
        StatusMessage = valid ? string.Empty : "Fix the highlighted gate mappings before saving.";
        return valid;
    }

    private void LoadFrom(GateMacroConfiguration configuration)
    {
        Enabled = configuration.Enabled;
        Mappings.Clear();
        foreach (GateLocationMapping mapping in configuration.Mappings)
        {
            Mappings.Add(CreateRow(mapping.Notation, mapping.Location));
        }

        HasValidationError = false;
        StatusMessage = string.Empty;
    }

    private void OnSettingsChanged(object? sender, AppConfiguration configuration) =>
        Post(() => LoadFrom(configuration.GateMacro));

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

public sealed partial class GateMappingItemViewModel : ObservableObject
{
    private readonly Action<GateMappingItemViewModel> _remove;
    private readonly Func<bool> _validate;

    [ObservableProperty] private string _notation;
    [ObservableProperty] private string _location;
    [ObservableProperty] private string _error = string.Empty;

    public GateMappingItemViewModel(
        string notation,
        string location,
        Action<GateMappingItemViewModel> remove,
        Func<bool> validate)
    {
        _notation = notation;
        _location = location;
        _remove = remove;
        _validate = validate;
    }

    [RelayCommand]
    private void Remove() => _remove(this);

    partial void OnNotationChanged(string value) => _validate();
    partial void OnLocationChanged(string value) => _validate();
}
