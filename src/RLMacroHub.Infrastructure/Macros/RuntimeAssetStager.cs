using Microsoft.Extensions.Logging;

namespace RLMacroHub.Infrastructure.Macros;

public sealed class RuntimeAssetStager
{
    private readonly ILogger<RuntimeAssetStager> _logger;

    public RuntimeAssetStager(ILogger<RuntimeAssetStager> logger) => _logger = logger;

    public string StageModernRuntime(string sourceDirectory, string destinationDirectory)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(sourceDirectory);
        ArgumentException.ThrowIfNullOrWhiteSpace(destinationDirectory);
        string sourceRoot = Path.GetFullPath(sourceDirectory);
        string destinationRoot = Path.GetFullPath(destinationDirectory);
        string sourceEntryPoint = Path.Combine(sourceRoot, "RLMacroHub.Runtime.ahk");
        if (!File.Exists(sourceEntryPoint))
        {
            throw new FileNotFoundException("The modular runtime entry point was not found.", sourceEntryPoint);
        }

        Directory.CreateDirectory(destinationRoot);
        foreach (string sourceFile in Directory.EnumerateFiles(sourceRoot, "*", SearchOption.AllDirectories))
        {
            string relativePath = Path.GetRelativePath(sourceRoot, sourceFile);
            string destinationFile = Path.Combine(destinationRoot, relativePath);
            Directory.CreateDirectory(Path.GetDirectoryName(destinationFile)!);
            File.Copy(sourceFile, destinationFile, true);
        }

        string stagedEntryPoint = Path.Combine(destinationRoot, "RLMacroHub.Runtime.ahk");
        _logger.LogInformation("Staged modular AHK runtime at {RuntimeDirectory}.", destinationRoot);
        return stagedEntryPoint;
    }
}
