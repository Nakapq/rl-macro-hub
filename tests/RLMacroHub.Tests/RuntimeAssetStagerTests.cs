using Microsoft.Extensions.Logging.Abstractions;
using RLMacroHub.Infrastructure.Macros;

namespace RLMacroHub.Tests;

public sealed class RuntimeAssetStagerTests
{
    [Fact]
    public void StagerCopiesEntryPointAndModules()
    {
        using TemporaryDirectory temporary = new();
        string source = Path.Combine(temporary.Path, "source");
        string destination = Path.Combine(temporary.Path, "destination");
        Directory.CreateDirectory(Path.Combine(source, "Modules"));
        Directory.CreateDirectory(Path.Combine(source, "Assets"));
        File.WriteAllText(Path.Combine(source, "RLMacroHub.Runtime.ahk"), "#Requires AutoHotkey v2.0+");
        File.WriteAllText(Path.Combine(source, "Modules", "Example.ahk"), "class Example {}");
        File.WriteAllBytes(Path.Combine(source, "Assets", "Overlay.png"), [1, 2, 3]);
        RuntimeAssetStager stager = new(NullLogger<RuntimeAssetStager>.Instance);

        string entryPoint = stager.StageModernRuntime(source, destination);

        Assert.True(File.Exists(entryPoint));
        Assert.True(File.Exists(Path.Combine(destination, "Modules", "Example.ahk")));
        Assert.True(File.Exists(Path.Combine(destination, "Assets", "Overlay.png")));
    }
}
