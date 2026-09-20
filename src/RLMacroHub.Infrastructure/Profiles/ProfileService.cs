using System.Text.Json;
using Microsoft.Extensions.Logging;
using RLMacroHub.Core.Models;
using RLMacroHub.Core.Services;
using RLMacroHub.Infrastructure.Configuration;

namespace RLMacroHub.Infrastructure.Profiles;

public sealed class ProfileService : IProfileService, IDisposable
{
    private static readonly JsonSerializerOptions SerializerOptions = new(JsonSerializerDefaults.Web) { WriteIndented = true };
    private readonly AppPaths _paths;
    private readonly ISettingsService _settings;
    private readonly ILogger<ProfileService> _logger;
    private readonly SemaphoreSlim _gate = new(1, 1);

    public ProfileService(AppPaths paths, ISettingsService settings, ILogger<ProfileService> logger)
    {
        _paths = paths;
        _settings = settings;
        _logger = logger;
    }

    public async Task<IReadOnlyList<ProfileConfiguration>> GetProfilesAsync(CancellationToken cancellationToken = default)
    {
        List<ProfileConfiguration> profiles = [];
        AppConfiguration? repairedConfiguration = null;

        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            _paths.EnsureCreated();
            await EnsureDefaultProfileAsync(cancellationToken).ConfigureAwait(false);
            foreach (string file in Directory.EnumerateFiles(_paths.ProfilesDirectory, "*.json"))
            {
                try
                {
                    await using FileStream stream = File.OpenRead(file);
                    ProfileConfiguration? profile = await JsonSerializer.DeserializeAsync<ProfileConfiguration>(stream, SerializerOptions, cancellationToken)
                        .ConfigureAwait(false);
                    if (profile is not null)
                    {
                        string fileId = Path.GetFileNameWithoutExtension(file);
                        if (!string.Equals(profile.Id, fileId, StringComparison.Ordinal))
                        {
                            _logger.LogWarning("Ignoring profile whose stored ID {ProfileId} does not match file {ProfileFile}.", profile.Id, file);
                            continue;
                        }

                        profile.IsDefault = string.Equals(profile.Id, "default", StringComparison.Ordinal);
                        profile.Settings.ValidateAndNormalize();
                        profiles.Add(profile);
                    }
                }
                catch (Exception exception) when (exception is JsonException or IOException or UnauthorizedAccessException)
                {
                    _logger.LogWarning(exception, "Ignoring unreadable profile {ProfileFile}.", file);
                }
            }

            if (profiles.All(profile => !string.Equals(profile.Id, "default", StringComparison.Ordinal)))
            {
                string defaultPath = ProfilePath("default");
                PreserveUnreadableProfile(defaultPath);
                ProfileConfiguration defaultProfile = new()
                {
                    Id = "default",
                    Name = "Default",
                    IsDefault = true,
                    Settings = Clone(_settings.Current)
                };
                await WriteProfileAsync(defaultProfile, cancellationToken).ConfigureAwait(false);
                profiles.Add(defaultProfile);
            }

            string activeProfileId = _settings.Current.General.ActiveProfileId;
            if (profiles.All(profile => !string.Equals(profile.Id, activeProfileId, StringComparison.Ordinal)))
            {
                ProfileConfiguration defaultProfile = profiles.Single(profile => string.Equals(profile.Id, "default", StringComparison.Ordinal));
                repairedConfiguration = BuildActiveConfiguration(defaultProfile, _settings.Current.General);
                _logger.LogWarning("Active profile {ProfileId} was unavailable; restored the default profile.", activeProfileId);
            }
        }
        finally
        {
            _gate.Release();
        }

        if (repairedConfiguration is not null)
        {
            await _settings.SaveAsync(repairedConfiguration, cancellationToken).ConfigureAwait(false);
        }

        return profiles
            .OrderByDescending(profile => profile.IsDefault)
            .ThenBy(profile => profile.Name, StringComparer.OrdinalIgnoreCase)
            .ToArray();
    }

    public async Task<ProfileConfiguration> CreateAsync(string name, CancellationToken cancellationToken = default)
    {
        string normalizedName = ValidateName(name);
        ProfileConfiguration profile = new() { Name = normalizedName, Settings = Clone(_settings.Current) };
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            _paths.EnsureCreated();
            await EnsureDefaultProfileAsync(cancellationToken).ConfigureAwait(false);
            await WriteProfileAsync(profile, cancellationToken).ConfigureAwait(false);
        }
        finally
        {
            _gate.Release();
        }

        return profile;
    }

    public async Task RenameAsync(string id, string name, CancellationToken cancellationToken = default)
    {
        string normalizedName = ValidateName(name);
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            ProfileConfiguration profile = await ReadRequiredAsync(id, cancellationToken).ConfigureAwait(false);
            profile.Name = normalizedName;
            await WriteProfileAsync(profile, cancellationToken).ConfigureAwait(false);
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task DeleteAsync(string id, CancellationToken cancellationToken = default)
    {
        AppConfiguration? replacementConfiguration = null;

        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            ProfileConfiguration profile = await ReadRequiredAsync(id, cancellationToken).ConfigureAwait(false);
            int count = Directory.EnumerateFiles(_paths.ProfilesDirectory, "*.json").Count();
            if (string.Equals(id, "default", StringComparison.Ordinal) || count <= 1)
            {
                throw new InvalidOperationException("The default or final profile cannot be deleted.");
            }

            bool deletingActive = string.Equals(_settings.Current.General.ActiveProfileId, id, StringComparison.Ordinal);
            File.Delete(ProfilePath(id));
            if (deletingActive)
            {
                ProfileConfiguration defaultProfile = await ReadRequiredAsync("default", cancellationToken).ConfigureAwait(false);
                replacementConfiguration = BuildActiveConfiguration(defaultProfile, _settings.Current.General);
            }
        }
        finally
        {
            _gate.Release();
        }

        if (replacementConfiguration is not null)
        {
            await _settings.SaveAsync(replacementConfiguration, cancellationToken).ConfigureAwait(false);
        }
    }

    public async Task SelectAsync(string id, CancellationToken cancellationToken = default)
    {
        AppConfiguration? selectedConfiguration = null;

        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            _paths.EnsureCreated();
            await EnsureDefaultProfileAsync(cancellationToken).ConfigureAwait(false);
            ProfileConfiguration selectedProfile = await ReadRequiredAsync(id, cancellationToken).ConfigureAwait(false);
            string currentId = _settings.Current.General.ActiveProfileId;

            if (string.Equals(currentId, id, StringComparison.Ordinal))
            {
                selectedProfile.Settings = Clone(_settings.Current);
                await WriteProfileAsync(selectedProfile, cancellationToken).ConfigureAwait(false);
                return;
            }

            string currentPath = ProfilePath(currentId);
            if (File.Exists(currentPath))
            {
                ProfileConfiguration currentProfile = await ReadRequiredAsync(currentId, cancellationToken).ConfigureAwait(false);
                currentProfile.Settings = Clone(_settings.Current);
                await WriteProfileAsync(currentProfile, cancellationToken).ConfigureAwait(false);
            }

            selectedConfiguration = BuildActiveConfiguration(selectedProfile, _settings.Current.General);
        }
        finally
        {
            _gate.Release();
        }

        await _settings.SaveAsync(selectedConfiguration!, cancellationToken).ConfigureAwait(false);
    }

    public async Task SaveActiveSettingsAsync(CancellationToken cancellationToken = default)
    {
        AppConfiguration? repairedConfiguration = null;

        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            _paths.EnsureCreated();
            await EnsureDefaultProfileAsync(cancellationToken).ConfigureAwait(false);
            string activeProfileId = _settings.Current.General.ActiveProfileId;
            string activePath = ProfilePath(activeProfileId);
            if (!File.Exists(activePath))
            {
                activeProfileId = "default";
                repairedConfiguration = Clone(_settings.Current);
                repairedConfiguration.General.ActiveProfileId = activeProfileId;
            }

            ProfileConfiguration profile = await ReadRequiredAsync(activeProfileId, cancellationToken).ConfigureAwait(false);
            profile.Settings = Clone(repairedConfiguration ?? _settings.Current);
            await WriteProfileAsync(profile, cancellationToken).ConfigureAwait(false);
        }
        finally
        {
            _gate.Release();
        }

        if (repairedConfiguration is not null)
        {
            await _settings.SaveAsync(repairedConfiguration, cancellationToken).ConfigureAwait(false);
        }
    }

    private async Task EnsureDefaultProfileAsync(CancellationToken cancellationToken)
    {
        string path = ProfilePath("default");
        if (!File.Exists(path))
        {
            await WriteProfileAsync(new ProfileConfiguration
            {
                Id = "default",
                Name = "Default",
                IsDefault = true,
                Settings = Clone(_settings.Current)
            }, cancellationToken).ConfigureAwait(false);
        }
    }

    private async Task<ProfileConfiguration> ReadRequiredAsync(string id, CancellationToken cancellationToken)
    {
        await using FileStream stream = File.OpenRead(ProfilePath(id));
        ProfileConfiguration profile = await JsonSerializer.DeserializeAsync<ProfileConfiguration>(stream, SerializerOptions, cancellationToken)
            .ConfigureAwait(false) ?? throw new InvalidDataException($"Profile '{id}' is empty.");
        profile.Settings.ValidateAndNormalize();
        return profile;
    }

    private async Task WriteProfileAsync(ProfileConfiguration profile, CancellationToken cancellationToken)
    {
        string path = ProfilePath(profile.Id);
        string temporaryPath = path + ".tmp";
        await using (FileStream stream = File.Create(temporaryPath))
        {
            await JsonSerializer.SerializeAsync(stream, profile, SerializerOptions, cancellationToken).ConfigureAwait(false);
            await stream.FlushAsync(cancellationToken).ConfigureAwait(false);
        }

        File.Move(temporaryPath, path, true);
    }

    private string ProfilePath(string id)
    {
        if (string.IsNullOrWhiteSpace(id) || id.Any(character => !char.IsAsciiLetterOrDigit(character) && character is not '-' and not '_'))
        {
            throw new ArgumentException("Profile ID is invalid.", nameof(id));
        }

        return Path.Combine(_paths.ProfilesDirectory, id + ".json");
    }

    private static AppConfiguration BuildActiveConfiguration(ProfileConfiguration profile, GeneralConfiguration currentGeneral)
    {
        AppConfiguration configuration = Clone(profile.Settings);
        configuration.General = new GeneralConfiguration
        {
            StartWithWindows = currentGeneral.StartWithWindows,
            MinimizeToTray = currentGeneral.MinimizeToTray,
            AutoHotkeyExecutablePath = currentGeneral.AutoHotkeyExecutablePath,
            ActiveProfileId = profile.Id
        };
        configuration.ValidateAndNormalize();
        return configuration;
    }

    private static string ValidateName(string name)
    {
        string normalized = name?.Trim() ?? string.Empty;
        if (normalized.Length is < 1 or > 80)
        {
            throw new ArgumentException("Profile names must be between 1 and 80 characters.", nameof(name));
        }

        return normalized;
    }

    private static AppConfiguration Clone(AppConfiguration source) =>
        JsonSerializer.Deserialize<AppConfiguration>(JsonSerializer.Serialize(source, SerializerOptions), SerializerOptions)!;

    private void PreserveUnreadableProfile(string path)
    {
        if (!File.Exists(path))
        {
            return;
        }

        try
        {
            string destination = path + $".corrupt.{DateTimeOffset.UtcNow:yyyyMMddHHmmssfff}";
            File.Move(path, destination, true);
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
            _logger.LogWarning(exception, "Unreadable default profile could not be preserved before recovery.");
            File.Delete(path);
        }
    }

    public void Dispose() => _gate.Dispose();
}
