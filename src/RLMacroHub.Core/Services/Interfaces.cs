using RLMacroHub.Core.Models;

namespace RLMacroHub.Core.Services;

public interface ISettingsService
{
    AppConfiguration Current { get; }
    event EventHandler<AppConfiguration>? SettingsChanged;
    Task<AppConfiguration> LoadAsync(CancellationToken cancellationToken = default);
    Task SaveAsync(AppConfiguration configuration, CancellationToken cancellationToken = default);
}

public interface IMacroRuntimeService : IAsyncDisposable
{
    MacroRuntimeState State { get; }
    string? LastError { get; }
    event EventHandler<MacroRuntimeState>? StateChanged;
    Task StartAsync(string scriptPath, string? explicitExecutablePath = null, CancellationToken cancellationToken = default);
    Task StopAsync(CancellationToken cancellationToken = default);
}

public interface IRobloxWindowService : IAsyncDisposable
{
    RobloxWindowState Current { get; }
    event EventHandler<RobloxWindowState>? StateChanged;
    Task StartAsync(CancellationToken cancellationToken = default);
    Task StopAsync(CancellationToken cancellationToken = default);
}

public interface IOverlayService
{
    bool IsVisible { get; }
    Task ShowAsync(CancellationToken cancellationToken = default);
    Task HideAsync(CancellationToken cancellationToken = default);
    Task SetEditModeAsync(bool enabled, CancellationToken cancellationToken = default);
}

public interface IProfileService
{
    Task<IReadOnlyList<ProfileConfiguration>> GetProfilesAsync(CancellationToken cancellationToken = default);
    Task<ProfileConfiguration> CreateAsync(string name, CancellationToken cancellationToken = default);
    Task RenameAsync(string id, string name, CancellationToken cancellationToken = default);
    Task DeleteAsync(string id, CancellationToken cancellationToken = default);
    Task SelectAsync(string id, CancellationToken cancellationToken = default);
    Task SaveActiveSettingsAsync(CancellationToken cancellationToken = default);
}
