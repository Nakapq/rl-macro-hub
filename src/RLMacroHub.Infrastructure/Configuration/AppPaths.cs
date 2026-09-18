namespace RLMacroHub.Infrastructure.Configuration;

public sealed class AppPaths
{
    public AppPaths(string? rootDirectory = null)
    {
        RootDirectory = rootDirectory ?? Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "RLMacroHub");
    }

    public string RootDirectory { get; }
    public string ConfigurationFile => Path.Combine(RootDirectory, "config.json");
    public string ProfilesDirectory => Path.Combine(RootDirectory, "profiles");
    public string LogsDirectory => Path.Combine(RootDirectory, "logs");
    public string RuntimeDirectory => Path.Combine(RootDirectory, "runtime");
    public string ModernRuntimeDirectory => Path.Combine(RuntimeDirectory, "modern");
    public string ModernRuntimeConfigurationFile => Path.Combine(ModernRuntimeDirectory, "RLMacroHub.Runtime.ini");

    public void EnsureCreated()
    {
        Directory.CreateDirectory(RootDirectory);
        Directory.CreateDirectory(ProfilesDirectory);
        Directory.CreateDirectory(LogsDirectory);
        Directory.CreateDirectory(RuntimeDirectory);
        Directory.CreateDirectory(ModernRuntimeDirectory);
    }

    public string? FindModernRuntimeDirectory()
    {
        const string entryPoint = "RLMacroHub.Runtime.ahk";
        foreach (string start in new[] { AppContext.BaseDirectory, Environment.CurrentDirectory })
        {
            DirectoryInfo? directory = new(start);
            for (int depth = 0; directory is not null && depth < 8; depth++, directory = directory.Parent)
            {
                string candidate = Path.Combine(directory.FullName, "src", "RLMacroHub.Runtime");
                if (File.Exists(Path.Combine(candidate, entryPoint)))
                {
                    return candidate;
                }
            }
        }

        return null;
    }
}
