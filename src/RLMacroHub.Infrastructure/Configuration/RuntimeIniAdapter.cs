using System.Globalization;
using System.Text;
using Microsoft.Extensions.Logging;
using RLMacroHub.Core.Models;

namespace RLMacroHub.Infrastructure.Configuration;

public sealed class RuntimeIniAdapter
{
    private readonly ILogger<RuntimeIniAdapter> _logger;

    public RuntimeIniAdapter(ILogger<RuntimeIniAdapter> logger) => _logger = logger;

    public string Export(AppConfiguration configuration)
    {
        ArgumentNullException.ThrowIfNull(configuration);
        configuration.ValidateAndNormalize();
        OverlayElementConfiguration statusElement = configuration.Overlay.Elements
            .FirstOrDefault(element => element.Id == "autoclicker-status")
            ?? OverlayElementConfiguration.CreateDefaultAutoclickerStatus();

        StringBuilder output = new();
        output.AppendLine("[Runtime]");
        Append(output, "SchemaVersion", AppConfiguration.CurrentSchemaVersion);
        output.AppendLine();
        output.AppendLine("[General]");
        Append(output, "ToggleHotkey", configuration.Autoclicker.ToggleHotkey);
        output.AppendLine();
        output.AppendLine("[Autoclicker]");
        Append(output, "Enabled", configuration.Autoclicker.Enabled);
        Append(output, "MaximumCps", configuration.Autoclicker.MaximumCps);
        Append(output, "HoldThresholdMs", configuration.Autoclicker.HoldThresholdMs);
        Append(output, "ForceEnabledWhenInventoryCloses", configuration.Autoclicker.ForceEnabledWhenInventoryCloses);
        output.AppendLine();
        output.AppendLine("[InventoryPanel]");
        Append(output, "SuppressAutoclicks", configuration.Autoclicker.InventoryPanel.SuppressAutoclicks);
        Append(output, "ShowBorder", configuration.Autoclicker.InventoryPanel.ShowBorder);
        Append(output, "NormalizedLeft", configuration.Autoclicker.InventoryPanel.NormalizedLeft);
        Append(output, "NormalizedTop", configuration.Autoclicker.InventoryPanel.NormalizedTop);
        Append(output, "NormalizedRight", configuration.Autoclicker.InventoryPanel.NormalizedRight);
        Append(output, "NormalizedBottom", configuration.Autoclicker.InventoryPanel.NormalizedBottom);
        output.AppendLine();
        output.AppendLine("[AbilitySlots]");
        Append(output, "SlotCount", configuration.Autoclicker.AbilitySlots.Count);
        for (int index = 0; index < configuration.Autoclicker.AbilitySlots.Count; index++)
        {
            AbilitySlotConfiguration slot = configuration.Autoclicker.AbilitySlots[index];
            Append(output, $"Slot{index + 1}_Key", slot.Slot);
            Append(output, $"Slot{index + 1}_AutoclickerEnabled", slot.AutoclickerEnabled);
        }
        output.AppendLine();
        output.AppendLine("[Keybinds]");
        Append(output, "Enabled", configuration.Keybinds.Enabled);
        Append(output, "BindingCount", configuration.Keybinds.Bindings.Count);
        output.AppendLine();
        output.AppendLine("[Bindings]");
        for (int index = 0; index < configuration.Keybinds.Bindings.Count; index++)
        {
            KeyBinding binding = configuration.Keybinds.Bindings[index];
            Append(output, $"Binding{index + 1}_Source", binding.Source);
            Append(output, $"Binding{index + 1}_Target", binding.Target);
        }

        output.AppendLine();
        output.AppendLine("[ManaOverlay]");
        Append(output, "Enabled", configuration.ManaOverlay.Enabled);
        Append(output, "NormalizedX", configuration.ManaOverlay.NormalizedX);
        Append(output, "NormalizedY", configuration.ManaOverlay.NormalizedY);
        Append(output, "Scale", configuration.ManaOverlay.Scale);
        Append(output, "Opacity", configuration.ManaOverlay.Opacity);

        output.AppendLine();
        output.AppendLine("[Overlay]");
        Append(output, "Enabled", configuration.Overlay.Enabled);
        Append(output, "ShowAutoclickerStatus", configuration.Autoclicker.ShowOverlayStatus);
        Append(output, "ClickThrough", configuration.Overlay.ClickThrough);
        Append(output, "Width", (int)Math.Round(statusElement.Width));
        Append(output, "Height", (int)Math.Round(statusElement.Height));
        Append(output, "RightOffset", (int)Math.Round(Math.Abs(statusElement.X)));
        Append(output, "TopOffset", (int)Math.Round(statusElement.Y));
        return output.ToString();
    }

    public async Task ExportAsync(AppConfiguration configuration, string destinationPath, CancellationToken cancellationToken = default)
    {
        string temporaryPath = destinationPath + ".tmp";
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(destinationPath))!);
        try
        {
            await File.WriteAllTextAsync(temporaryPath, Export(configuration), Encoding.UTF8, cancellationToken)
                .ConfigureAwait(false);
            File.Move(temporaryPath, destinationPath, true);
            _logger.LogInformation("Exported modular runtime configuration to {Destination} with {BindingCount} bindings.", destinationPath, configuration.Keybinds.Bindings.Count);
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
            _logger.LogError(exception, "Runtime configuration export failed for {Destination}.", destinationPath);
            throw;
        }
    }

    private static void Append(StringBuilder output, string key, string? value) =>
        output.Append(key).Append('=').AppendLine(Sanitize(value));

    private static void Append(StringBuilder output, string key, int value) =>
        output.Append(key).Append('=').AppendLine(value.ToString(CultureInfo.InvariantCulture));

    private static void Append(StringBuilder output, string key, bool value) =>
        output.Append(key).Append('=').AppendLine(value ? "1" : "0");

    private static void Append(StringBuilder output, string key, double value) =>
        output.Append(key).Append('=').AppendLine(value.ToString("0.######", CultureInfo.InvariantCulture));

    private static string Sanitize(string? value) =>
        (value ?? string.Empty).Replace("\r", string.Empty, StringComparison.Ordinal)
            .Replace("\n", string.Empty, StringComparison.Ordinal)
            .Trim();
}
