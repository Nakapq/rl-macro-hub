using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using RLMacroHub.Core.Models;
using RLMacroHub.Core.Services;
using RLMacroHub.Infrastructure.Configuration;

namespace RLMacroHub.App.ViewModels;

public sealed partial class KeybindsViewModel : ObservableObject
{
    private static readonly HashSet<string> ReservedRuntimeSources = new(StringComparer.OrdinalIgnoreCase)
    {
        "/", "Enter", "Esc", "Escape", "SC029", "LButton", "s", "a", "d",
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="
    };

    private readonly ISettingsService _settings;
    private readonly IProfileService _profiles;
    private readonly RuntimeIniAdapter _runtimeIniAdapter;
    private readonly AppPaths _paths;
    private readonly SynchronizationContext? _synchronizationContext;

    [ObservableProperty] private bool _enabled;
    [ObservableProperty] private string _statusMessage = string.Empty;
    [ObservableProperty] private bool _hasValidationError;

    public KeybindsViewModel(
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
        LoadFrom(settings.Current.Keybinds);
        settings.SettingsChanged += OnSettingsChanged;
    }

    public ObservableCollection<KeyBindingItemViewModel> Bindings { get; } = [];

    [RelayCommand]
    private void AddBinding()
    {
        Bindings.Add(CreateRow(string.Empty, string.Empty));
        Validate();
    }

    [RelayCommand]
    private async Task SaveAsync()
    {
        if (!Validate())
        {
            return;
        }

        _settings.Current.Keybinds.Enabled = Enabled;
        _settings.Current.Keybinds.Bindings = new ObservableCollection<KeyBinding>(
            Bindings.Select(row => new KeyBinding(row.Source.Trim(), row.Target.Trim())));
        await _settings.SaveAsync(_settings.Current);
        await _profiles.SaveActiveSettingsAsync();
        await _runtimeIniAdapter.ExportAsync(_settings.Current, _paths.ModernRuntimeConfigurationFile);
        StatusMessage = "Bindings saved to the active profile — reload a running AHK runtime to apply.";
    }

    private KeyBindingItemViewModel CreateRow(string source, string target) =>
        new(source, target, RemoveBinding, Validate);

    private void RemoveBinding(KeyBindingItemViewModel row)
    {
        Bindings.Remove(row);
        Validate();
    }

    private bool Validate()
    {
        HashSet<string> sources = new(StringComparer.OrdinalIgnoreCase);
        bool valid = true;
        foreach (KeyBindingItemViewModel row in Bindings)
        {
            row.Error = string.Empty;
            if (string.IsNullOrWhiteSpace(row.Source) || string.IsNullOrWhiteSpace(row.Target))
            {
                row.Error = "Both keys are required.";
                valid = false;
            }
            else if (!sources.Add(row.Source.Trim()))
            {
                row.Error = "Source key is duplicated.";
                valid = false;
            }
            else if (ReservedRuntimeSources.Contains(row.Source.Trim()))
            {
                row.Error = "This source is reserved for runtime state tracking.";
                valid = false;
            }
            else if (string.Equals(row.Source.Trim(), _settings.Current.Autoclicker.ToggleHotkey, StringComparison.OrdinalIgnoreCase))
            {
                row.Error = "Source conflicts with the toggle hotkey.";
                valid = false;
            }
        }

        HasValidationError = !valid;
        StatusMessage = valid ? string.Empty : "Fix the highlighted bindings before saving.";
        return valid;
    }

    private void LoadFrom(KeybindConfiguration configuration)
    {
        Enabled = configuration.Enabled;
        Bindings.Clear();
        foreach (KeyBinding binding in configuration.Bindings)
        {
            Bindings.Add(CreateRow(binding.Source, binding.Target));
        }

        HasValidationError = false;
        StatusMessage = string.Empty;
    }

    private void OnSettingsChanged(object? sender, AppConfiguration configuration) =>
        Post(() => LoadFrom(configuration.Keybinds));

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

public sealed partial class KeyBindingItemViewModel : ObservableObject
{
    private readonly Action<KeyBindingItemViewModel> _remove;
    private readonly Func<bool> _validate;

    [ObservableProperty] private string _source;
    [ObservableProperty] private string _target;
    [ObservableProperty] private string _error = string.Empty;

    public KeyBindingItemViewModel(string source, string target, Action<KeyBindingItemViewModel> remove, Func<bool> validate)
    {
        _source = source;
        _target = target;
        _remove = remove;
        _validate = validate;
    }

    [RelayCommand]
    private void Remove() => _remove(this);

    partial void OnSourceChanged(string value) => _validate();
    partial void OnTargetChanged(string value) => _validate();
}
