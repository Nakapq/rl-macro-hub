using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Logging.Abstractions;
using RLMacroHub.Core.Models;
using RLMacroHub.Infrastructure.Configuration;
using RLMacroHub.Infrastructure.Logging;
using RLMacroHub.Infrastructure.Macros;

namespace RLMacroHub.Tests;

public sealed class InfrastructureServiceTests
{
    [Fact]
    public void AppPathsCreatesTheCompleteDirectoryLayout()
    {
        using TemporaryDirectory temporary = new();
        string root = Path.Combine(temporary.Path, "app-data");
        AppPaths paths = new(root);

        paths.EnsureCreated();

        Assert.Equal(Path.Combine(root, "config.json"), paths.ConfigurationFile);
        Assert.Equal(Path.Combine(root, "runtime", "modern", "RLMacroHub.Runtime.ini"), paths.ModernRuntimeConfigurationFile);
        Assert.True(Directory.Exists(paths.ProfilesDirectory));
        Assert.True(Directory.Exists(paths.LogsDirectory));
        Assert.True(Directory.Exists(paths.RuntimeDirectory));
        Assert.True(Directory.Exists(paths.ModernRuntimeDirectory));
    }

    [Fact]
    public async Task RuntimeReportsMissingEntryPointWithoutStartingAProcess()
    {
        using TemporaryDirectory temporary = new();
        await using AhkRuntimeService service = new(
            new AhkRuntimeDiscovery(),
            NullLogger<AhkRuntimeService>.Instance);
        List<MacroRuntimeState> states = [];
        service.StateChanged += (_, state) => states.Add(state);

        await service.StartAsync(Path.Combine(temporary.Path, "missing.ahk"));

        Assert.Equal(MacroRuntimeState.Unavailable, service.State);
        Assert.Equal("The AHK runtime entry point was not found.", service.LastError);
        Assert.Equal([MacroRuntimeState.Unavailable], states);
    }

    [Fact]
    public void FileLoggerWritesEnabledMessagesAndExceptions()
    {
        using TemporaryDirectory temporary = new();
        AppPaths paths = new(temporary.Path);
        using (FileLoggerProvider provider = new(paths))
        {
            ILogger logger = provider.CreateLogger("Tests.Category");
            logger.LogDebug("not written");
            logger.LogInformation(new EventId(42), new InvalidOperationException("details"), "message {Value}", 7);
        }

        string logFile = Assert.Single(Directory.GetFiles(paths.LogsDirectory, "*.log"));
        string contents = File.ReadAllText(logFile);
        Assert.Contains("[Information] Tests.Category (42): message 7", contents, StringComparison.Ordinal);
        Assert.Contains("InvalidOperationException: details", contents, StringComparison.Ordinal);
        Assert.DoesNotContain("not written", contents, StringComparison.Ordinal);
    }
}
