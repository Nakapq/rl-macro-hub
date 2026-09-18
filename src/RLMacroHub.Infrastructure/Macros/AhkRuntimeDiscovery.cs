using System.Diagnostics;
using System.Globalization;

namespace RLMacroHub.Infrastructure.Macros;

public sealed class AhkRuntimeDiscovery
{
    public string? ResolveExecutable(string? explicitPath = null)
    {
        IEnumerable<string> candidates = BuildCandidates(explicitPath);
        foreach (string candidate in candidates.Distinct(StringComparer.OrdinalIgnoreCase))
        {
            if (File.Exists(candidate) && GetMajorVersion(candidate) == 2)
            {
                return Path.GetFullPath(candidate);
            }
        }

        return null;
    }

    private static IEnumerable<string> BuildCandidates(string? explicitPath)
    {
        if (!string.IsNullOrWhiteSpace(explicitPath))
        {
            yield return Environment.ExpandEnvironmentVariables(explicitPath.Trim(' ', '"'));
        }

        string programFiles = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles);
        string programFilesX86 = Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86);
        foreach (string root in new[] { programFiles, programFilesX86 })
        {
            yield return Path.Combine(root, "AutoHotkey", "v2", "AutoHotkey64.exe");
            yield return Path.Combine(root, "AutoHotkey", "v2", "AutoHotkey32.exe");
            yield return Path.Combine(root, "AutoHotkey", "AutoHotkey.exe");
        }

        string? path = Environment.GetEnvironmentVariable("PATH");
        if (path is not null)
        {
            foreach (string part in path.Split(Path.PathSeparator, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            {
                yield return Path.Combine(part, "AutoHotkey.exe");
                yield return Path.Combine(part, "AutoHotkey64.exe");
            }
        }
    }

    private static int? GetMajorVersion(string path)
    {
        try
        {
            FileVersionInfo information = FileVersionInfo.GetVersionInfo(path);
            string? version = information.ProductVersion ?? information.FileVersion;
            if (string.IsNullOrWhiteSpace(version))
            {
                return null;
            }

            char firstDigit = version.FirstOrDefault(char.IsAsciiDigit);
            return firstDigit == default ? null : int.Parse(firstDigit.ToString(), CultureInfo.InvariantCulture);
        }
        catch (FileNotFoundException)
        {
            return null;
        }
    }
}
