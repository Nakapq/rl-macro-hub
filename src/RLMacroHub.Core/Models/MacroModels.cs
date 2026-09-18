using System.Text.Json.Serialization;

namespace RLMacroHub.Core.Models;

public enum MacroRuntimeState
{
    Stopped,
    Starting,
    Running,
    Stopping,
    Faulted,
    Unavailable
}

public sealed record MacroDescriptor(
    string Id,
    string DisplayName,
    string Description,
    string Category,
    bool IsAvailable,
    bool IsEnabled,
    MacroRuntimeState RuntimeState,
    string? SettingsPage);

public sealed record WindowBounds(int X, int Y, int Width, int Height);

public sealed record RobloxWindowState(
    bool IsRunning,
    bool IsForeground,
    bool IsMinimized,
    nint Hwnd,
    WindowBounds Bounds)
{
    public static RobloxWindowState NotRunning { get; } =
        new(false, false, false, nint.Zero, new(0, 0, 0, 0));
}

public sealed class ProfileConfiguration
{
    public string Id { get; set; } = Guid.NewGuid().ToString("N");
    public string Name { get; set; } = "New profile";
    public bool IsDefault { get; set; }
    public AppConfiguration Settings { get; set; } = AppConfiguration.CreateDefault();

    [JsonIgnore]
    public string DefaultLabel => IsDefault ? "DEFAULT" : string.Empty;
}
