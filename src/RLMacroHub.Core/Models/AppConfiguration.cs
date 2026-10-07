using System.Collections.ObjectModel;
using System.Text.Json.Serialization;

namespace RLMacroHub.Core.Models;

public sealed class AppConfiguration
{
    public const int CurrentSchemaVersion = 8;

    public int SchemaVersion { get; set; } = CurrentSchemaVersion;
    public GeneralConfiguration General { get; set; } = new();
    public AutoclickerConfiguration Autoclicker { get; set; } = new();
    public KeybindConfiguration Keybinds { get; set; } = new();
    public BackwardsRunConfiguration BackwardsRun { get; set; } = new();
    public GateMacroConfiguration GateMacro { get; set; } = new();
    public ManaOverlayConfiguration ManaOverlay { get; set; } = new();
    public OverlayConfiguration Overlay { get; set; } = new();

    public static AppConfiguration CreateDefault() => new();

    public void ValidateAndNormalize()
    {
        int previousSchemaVersion = SchemaVersion;
        General ??= new();
        Autoclicker ??= new();
        Keybinds ??= new();
        BackwardsRun ??= new();
        GateMacro ??= new();
        ManaOverlay ??= new();
        Overlay ??= new();

        Autoclicker.ToggleHotkey = Normalize(Autoclicker.ToggleHotkey, "XButton1");
        if (string.Equals(Autoclicker.ToggleHotkey, "w", StringComparison.OrdinalIgnoreCase)
            || string.Equals(Autoclicker.ToggleHotkey, "s", StringComparison.OrdinalIgnoreCase)
            || string.Equals(Autoclicker.ToggleHotkey, "a", StringComparison.OrdinalIgnoreCase)
            || string.Equals(Autoclicker.ToggleHotkey, "d", StringComparison.OrdinalIgnoreCase)
            || string.Equals(Autoclicker.ToggleHotkey, "g", StringComparison.OrdinalIgnoreCase)
            || string.Equals(Autoclicker.ToggleHotkey, "q", StringComparison.OrdinalIgnoreCase)
            || string.Equals(Autoclicker.ToggleHotkey, "v", StringComparison.OrdinalIgnoreCase)
            || string.Equals(Autoclicker.ToggleHotkey, "LButton", StringComparison.OrdinalIgnoreCase)
            || string.Equals(Autoclicker.ToggleHotkey, "RButton", StringComparison.OrdinalIgnoreCase))
        {
            Autoclicker.ToggleHotkey = "XButton1";
        }
        Autoclicker.MaximumCps = Math.Clamp(Autoclicker.MaximumCps, 1, 120);
        Autoclicker.HoldThresholdMs = Math.Clamp(Autoclicker.HoldThresholdMs, 0, 1000);
        Autoclicker.NormalizeAbilitySlots();
        Autoclicker.InventoryPanel ??= new();
        Autoclicker.InventoryPanel.ValidateAndNormalize();
        General.ActiveProfileId = Normalize(General.ActiveProfileId, "default");
        Keybinds.Bindings ??= [];
        if (!Enum.IsDefined(BackwardsRun.Mode))
        {
            BackwardsRun.Mode = BackwardsRunMode.Legacy;
        }
        GateMacro.ValidateAndNormalize();
        ManaOverlay.ValidateAndNormalize();
        ManaOverlay.MigrateFrom(previousSchemaVersion);
        ManaOverlay.ValidateAndNormalize();

        foreach (KeyBinding binding in Keybinds.Bindings)
        {
            binding.Source = binding.Source?.Trim() ?? string.Empty;
            binding.Target = binding.Target?.Trim() ?? string.Empty;
        }

        Overlay.NormalizeElements();
        SchemaVersion = CurrentSchemaVersion;
    }

    private static string Normalize(string? value, string fallback) =>
        string.IsNullOrWhiteSpace(value) ? fallback : value.Trim();
}

public sealed class BackwardsRunConfiguration
{
    public bool Enabled { get; set; } = true;
    public BackwardsRunMode Mode { get; set; } = BackwardsRunMode.Legacy;
}

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum BackwardsRunMode
{
    Legacy,
    DoubleTap,
    MultiDirectional
}

public sealed class GateMacroConfiguration
{
    public const int MaximumMappings = 100;

    public bool Enabled { get; set; } = true;
    public ObservableCollection<GateLocationMapping> Mappings { get; set; } = CreateDefaultMappings();

    public static ObservableCollection<GateLocationMapping> CreateDefaultMappings() =>
    [
        new("d", "desert"),
        new("d1", "desert 1"),
        new("d2", "desert 2"),
        new("d3", "desert 3"),
        new("d4", "desert 4"),
        new("d5", "desert 5"),
        new("t", "tundra"),
        new("t1", "tundra 1"),
        new("t2", "tundra 2"),
        new("t3", "tundra 3"),
        new("t4", "tundra 4"),
        new("t5", "tundra 5"),
        new("t6", "tundra 6"),
        new("t7", "tundra 7"),
        new("f", "forest"),
        new("f1", "forest 1"),
        new("f2", "forest 2"),
        new("f3", "forest 3"),
        new("f4", "forest 4"),
        new("f5", "forest 5"),
        new("df", "deepforest"),
        new("df1", "deepforest 1"),
        new("df2", "deepforest 2"),
        new("df3", "deepforest 3"),
        new("df4", "deepforest 4"),
        new("df5", "deepforest 5"),
        new("s", "shore"),
        new("s1", "shore 1"),
        new("s2", "shore 2"),
        new("s3", "shore 3"),
        new("s4", "shore 4"),
        new("j", "jungle"),
        new("j1", "jungle 1"),
        new("j2", "jungle 2"),
        new("p", "plains"),
        new("p1", "plains 1"),
        new("p2", "plains 2"),
        new("p3", "plains 3"),
        new("fo", "forge"),
        new("fo1", "forge 1"),
        new("fo2", "forge 2"),
        new("fo3", "forge 3"),
        new("fo4", "forge 4"),
        new("sn", "snail"),
        new("sky", "skycastle"),
        new("sig", "sigil")
    ];

    public void ValidateAndNormalize()
    {
        Mappings ??= [];
        HashSet<string> notations = new(StringComparer.OrdinalIgnoreCase);
        ObservableCollection<GateLocationMapping> normalized = [];
        foreach (GateLocationMapping? mapping in Mappings)
        {
            if (mapping is null || normalized.Count >= MaximumMappings)
            {
                continue;
            }

            string notation = (mapping.Notation ?? string.Empty).Trim().ToLowerInvariant();
            string location = (mapping.Location ?? string.Empty)
                .Replace('\r', ' ')
                .Replace('\n', ' ')
                .Trim();
            if (!GateLocationMapping.IsValidNotation(notation)
                || location.Length is < 1 or > GateLocationMapping.MaximumLocationLength
                || !notations.Add(notation))
            {
                continue;
            }

            normalized.Add(new GateLocationMapping(notation, location));
        }

        Mappings = normalized;
    }
}

public sealed class GateLocationMapping
{
    public const int MaximumNotationLength = 20;
    public const int MaximumLocationLength = 120;

    public GateLocationMapping() { }

    public GateLocationMapping(string notation, string location)
    {
        Notation = notation;
        Location = location;
    }

    public string Notation { get; set; } = string.Empty;
    public string Location { get; set; } = string.Empty;

    public static bool IsValidNotation(string? notation) =>
        !string.IsNullOrWhiteSpace(notation)
        && notation.Length <= MaximumNotationLength
        && notation.All(character => char.IsAsciiLetterOrDigit(character) || character is '-' or '_');

}

public sealed class ManaOverlayConfiguration
{
    private const double PreviousImageContentX = 13d / 1920d;
    private const double PreviousImageContentY = 549d / 1080d;

    public const double DefaultNormalizedX = 0d;
    public const double DefaultNormalizedY = 0d;
    public const double DefaultScale = 1d;
    public const double DefaultOpacity = 1d;

    public bool Enabled { get; set; } = true;
    public double NormalizedX { get; set; } = DefaultNormalizedX;
    public double NormalizedY { get; set; } = DefaultNormalizedY;
    public double Scale { get; set; } = DefaultScale;
    public double Opacity { get; set; } = DefaultOpacity;

    public void ValidateAndNormalize()
    {
        NormalizedX = Normalize(NormalizedX, DefaultNormalizedX, -1d, 2d);
        NormalizedY = Normalize(NormalizedY, DefaultNormalizedY, -1d, 2d);
        Scale = Normalize(Scale, DefaultScale, 0.25d, 3d);
        Opacity = Normalize(Opacity, DefaultOpacity, 0.1d, 1d);
    }

    public void MigrateFrom(int schemaVersion)
    {
        if (schemaVersion != 4)
        {
            return;
        }

        // Schema 4 positioned a cropped 46 x 360 sprite. Schema 5 positions the
        // original full canvas, so translate the old sprite position into a
        // canvas offset while preserving custom placement and scale.
        NormalizedX -= PreviousImageContentX * Scale;
        NormalizedY -= PreviousImageContentY * Scale;
    }

    private static double Normalize(double value, double fallback, double minimum, double maximum) =>
        double.IsFinite(value) ? Math.Clamp(value, minimum, maximum) : fallback;
}

public sealed class GeneralConfiguration
{
    public bool StartWithWindows { get; set; }
    public bool MinimizeToTray { get; set; }
    public string? AutoHotkeyExecutablePath { get; set; }
    public string ActiveProfileId { get; set; } = "default";
}

public sealed class AutoclickerConfiguration
{
    private static readonly string[] SupportedSlotKeys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="];

    public bool Enabled { get; set; } = true;
    public string ToggleHotkey { get; set; } = "XButton1";
    public int MaximumCps { get; set; } = 120;
    public int HoldThresholdMs { get; set; } = 30;
    public ObservableCollection<AbilitySlotConfiguration> AbilitySlots { get; set; } = CreateDefaultAbilitySlots();
    public InventoryPanelConfiguration InventoryPanel { get; set; } = new();
    public bool ForceEnabledWhenInventoryCloses { get; set; } = true;
    public bool ShowOverlayStatus { get; set; } = true;

    public static ObservableCollection<AbilitySlotConfiguration> CreateDefaultAbilitySlots() =>
        new(SupportedSlotKeys.Select(key => new AbilitySlotConfiguration(key, string.Empty, true)));

    public void NormalizeAbilitySlots()
    {
        AbilitySlots ??= [];
        Dictionary<string, AbilitySlotConfiguration> configured = AbilitySlots
            .Where(slot => !string.IsNullOrWhiteSpace(slot.Slot))
            .GroupBy(slot => slot.Slot.Trim(), StringComparer.OrdinalIgnoreCase)
            .ToDictionary(group => group.Key, group => group.First(), StringComparer.OrdinalIgnoreCase);

        ObservableCollection<AbilitySlotConfiguration> normalized = [];
        foreach (string key in SupportedSlotKeys)
        {
            if (!configured.TryGetValue(key, out AbilitySlotConfiguration? slot))
            {
                normalized.Add(new AbilitySlotConfiguration(key, string.Empty, true));
                continue;
            }

            string name = slot.Name?.Trim() ?? string.Empty;
            if (name.Length > AbilitySlotConfiguration.MaximumNameLength)
            {
                name = name[..AbilitySlotConfiguration.MaximumNameLength];
            }

            normalized.Add(new AbilitySlotConfiguration(key, name, slot.AutoclickerEnabled));
        }

        AbilitySlots = normalized;
    }
}

public sealed class AbilitySlotConfiguration
{
    public const int MaximumNameLength = 60;

    public AbilitySlotConfiguration() { }

    public AbilitySlotConfiguration(string slot, string name, bool autoclickerEnabled)
    {
        Slot = slot;
        Name = name;
        AutoclickerEnabled = autoclickerEnabled;
    }

    public string Slot { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public bool AutoclickerEnabled { get; set; } = true;
}

public sealed class InventoryPanelConfiguration
{
    public const double DefaultNormalizedLeft = 479d / 1920d;
    public const double DefaultNormalizedTop = 458d / 1080d;
    public const double DefaultNormalizedRight = 1442d / 1920d;
    public const double DefaultNormalizedBottom = 1000d / 1080d;

    public bool SuppressAutoclicks { get; set; } = true;
    public bool ShowBorder { get; set; }
    public double NormalizedLeft { get; set; } = DefaultNormalizedLeft;
    public double NormalizedTop { get; set; } = DefaultNormalizedTop;
    public double NormalizedRight { get; set; } = DefaultNormalizedRight;
    public double NormalizedBottom { get; set; } = DefaultNormalizedBottom;

    public void ValidateAndNormalize()
    {
        if (!double.IsFinite(NormalizedLeft)
            || !double.IsFinite(NormalizedTop)
            || !double.IsFinite(NormalizedRight)
            || !double.IsFinite(NormalizedBottom))
        {
            RestoreDefaults();
            return;
        }

        NormalizedLeft = Math.Clamp(NormalizedLeft, 0d, 1d);
        NormalizedTop = Math.Clamp(NormalizedTop, 0d, 1d);
        NormalizedRight = Math.Clamp(NormalizedRight, 0d, 1d);
        NormalizedBottom = Math.Clamp(NormalizedBottom, 0d, 1d);

        if (NormalizedRight <= NormalizedLeft || NormalizedBottom <= NormalizedTop)
            RestoreDefaults();
    }

    private void RestoreDefaults()
    {
        NormalizedLeft = DefaultNormalizedLeft;
        NormalizedTop = DefaultNormalizedTop;
        NormalizedRight = DefaultNormalizedRight;
        NormalizedBottom = DefaultNormalizedBottom;
    }
}

public sealed class KeybindConfiguration
{
    public bool Enabled { get; set; } = true;
    public ObservableCollection<KeyBinding> Bindings { get; set; } =
    [
        new("x", "0"),
        new("c", "-"),
        new("z", "9"),
        new("t", "8"),
        new("Tab", "7")
    ];
}

public sealed class KeyBinding
{
    public KeyBinding() { }

    public KeyBinding(string source, string target)
    {
        Source = source;
        Target = target;
    }

    public string Source { get; set; } = string.Empty;
    public string Target { get; set; } = string.Empty;
}

public sealed class OverlayConfiguration
{
    public bool Enabled { get; set; } = true;
    public bool ClickThrough { get; set; } = true;
    public ObservableCollection<OverlayElementConfiguration> Elements { get; set; } =
    [
        OverlayElementConfiguration.CreateDefaultAutoclickerStatus()
    ];

    public void NormalizeElements()
    {
        Elements ??= [];
        OverlayElementConfiguration? status = Elements.FirstOrDefault(element => element.Id == "autoclicker-status");
        if (status is null)
        {
            Elements.Add(OverlayElementConfiguration.CreateDefaultAutoclickerStatus());
            return;
        }

        bool usesPreviousDefault = Math.Abs(status.X - (-373d)) < 0.001
            && Math.Abs(status.Y - 96d) < 0.001
            && Math.Abs(status.Width - 94d) < 0.001
            && Math.Abs(status.Height - 39d) < 0.001;
        if (usesPreviousDefault)
        {
            status.X = OverlayElementConfiguration.DefaultAutoclickerStatusX;
            status.Width = OverlayElementConfiguration.DefaultAutoclickerStatusWidth;
        }
    }
}

public sealed class OverlayElementConfiguration
{
    public const double DefaultAutoclickerStatusX = -348;
    public const double DefaultAutoclickerStatusY = 96;
    public const double DefaultAutoclickerStatusWidth = 56;
    public const double DefaultAutoclickerStatusHeight = 39;

    public string Id { get; set; } = string.Empty;
    public double X { get; set; }
    public double Y { get; set; }
    public double Width { get; set; } = DefaultAutoclickerStatusWidth;
    public double Height { get; set; } = DefaultAutoclickerStatusHeight;
    public bool IsVisible { get; set; } = true;

    public static OverlayElementConfiguration CreateDefaultAutoclickerStatus() => new()
    {
        Id = "autoclicker-status",
        X = DefaultAutoclickerStatusX,
        Y = DefaultAutoclickerStatusY,
        Width = DefaultAutoclickerStatusWidth,
        Height = DefaultAutoclickerStatusHeight,
        IsVisible = true
    };
}
