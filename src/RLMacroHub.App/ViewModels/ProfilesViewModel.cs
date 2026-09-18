using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using RLMacroHub.Core.Models;
using RLMacroHub.Core.Services;
using RLMacroHub.Infrastructure.Configuration;

namespace RLMacroHub.App.ViewModels;

public sealed partial class ProfilesViewModel : ObservableObject
{
    private readonly IProfileService _profiles;
    private readonly ISettingsService _settings;
    private readonly RuntimeIniAdapter _runtimeIniAdapter;
    private readonly AppPaths _paths;

    [ObservableProperty] private ProfileListItemViewModel? _selectedProfile;
    [ObservableProperty] private string _profileName = string.Empty;
    [ObservableProperty] private string _statusMessage = string.Empty;
    [ObservableProperty] private string _activeProfileName = "Default";

    public ProfilesViewModel(
        IProfileService profiles,
        ISettingsService settings,
        RuntimeIniAdapter runtimeIniAdapter,
        AppPaths paths)
    {
        _profiles = profiles;
        _settings = settings;
        _runtimeIniAdapter = runtimeIniAdapter;
        _paths = paths;
    }

    public ObservableCollection<ProfileListItemViewModel> Profiles { get; } = [];

    public Task InitializeAsync() => ReloadAsync(_settings.Current.General.ActiveProfileId);

    [RelayCommand]
    private async Task CreateAsync()
    {
        try
        {
            ProfileConfiguration profile = await _profiles.CreateAsync(ProfileName);
            await _profiles.SelectAsync(profile.Id);
            await ExportActiveRuntimeConfigurationAsync();
            ProfileName = string.Empty;
            await ReloadAsync(profile.Id);
            StatusMessage = $"{profile.Name} was created and is now active.";
        }
        catch (ArgumentException exception)
        {
            StatusMessage = exception.Message;
        }
    }

    [RelayCommand]
    private async Task RenameAsync()
    {
        if (SelectedProfile is null)
        {
            StatusMessage = "Select a profile to rename.";
            return;
        }

        try
        {
            string selectedId = SelectedProfile.Id;
            await _profiles.RenameAsync(selectedId, ProfileName);
            ProfileName = string.Empty;
            await ReloadAsync(selectedId);
            StatusMessage = "Profile renamed.";
        }
        catch (ArgumentException exception)
        {
            StatusMessage = exception.Message;
        }
    }

    [RelayCommand]
    private async Task DeleteAsync()
    {
        if (SelectedProfile is null)
        {
            StatusMessage = "Select a profile to delete.";
            return;
        }

        try
        {
            string removedName = SelectedProfile.Name;
            await _profiles.DeleteAsync(SelectedProfile.Id);
            await ExportActiveRuntimeConfigurationAsync();
            await ReloadAsync(_settings.Current.General.ActiveProfileId);
            StatusMessage = $"{removedName} was deleted.";
        }
        catch (InvalidOperationException exception)
        {
            StatusMessage = exception.Message;
        }
    }

    [RelayCommand]
    private async Task SelectAsync()
    {
        if (SelectedProfile is null)
        {
            StatusMessage = "Select a profile to activate.";
            return;
        }

        string selectedId = SelectedProfile.Id;
        await _profiles.SelectAsync(selectedId);
        await ExportActiveRuntimeConfigurationAsync();
        await ReloadAsync(selectedId);
        StatusMessage = $"{ActiveProfileName} is now active. Reload a running AHK runtime to apply it.";
    }

    private async Task ReloadAsync(string selectedId)
    {
        IReadOnlyList<ProfileConfiguration> profiles = await _profiles.GetProfilesAsync();
        string activeId = _settings.Current.General.ActiveProfileId;

        Profiles.Clear();
        foreach (ProfileConfiguration profile in profiles)
        {
            Profiles.Add(new ProfileListItemViewModel(
                profile.Id,
                profile.Name,
                profile.IsDefault,
                string.Equals(profile.Id, activeId, StringComparison.Ordinal)));
        }

        SelectedProfile = Profiles.FirstOrDefault(profile => profile.Id == selectedId)
            ?? Profiles.FirstOrDefault(profile => profile.IsActive)
            ?? Profiles.FirstOrDefault();
        ActiveProfileName = Profiles.FirstOrDefault(profile => profile.IsActive)?.Name ?? "Default";
    }

    private Task ExportActiveRuntimeConfigurationAsync() =>
        _runtimeIniAdapter.ExportAsync(_settings.Current, _paths.ModernRuntimeConfigurationFile);
}

public sealed class ProfileListItemViewModel
{
    public ProfileListItemViewModel(string id, string name, bool isDefault, bool isActive)
    {
        Id = id;
        Name = name;
        IsDefault = isDefault;
        IsActive = isActive;
    }

    public string Id { get; }
    public string Name { get; }
    public bool IsDefault { get; }
    public bool IsActive { get; }
    public string StatusLabel => IsActive ? "ACTIVE" : IsDefault ? "DEFAULT" : string.Empty;
    public double StatusOpacity => string.IsNullOrEmpty(StatusLabel) ? 0 : 1;
}
