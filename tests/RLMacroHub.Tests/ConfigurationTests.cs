using Microsoft.Extensions.Logging.Abstractions;
using RLMacroHub.Core.Models;
using RLMacroHub.Infrastructure.Configuration;

namespace RLMacroHub.Tests;

public sealed class ConfigurationTests
{
    [Fact]
    public async Task MissingConfigurationCreatesDefaults()
    {
        using TemporaryDirectory temporary = new();
        AppPaths paths = new(temporary.Path);
        using JsonSettingsService service = new(paths, NullLogger<JsonSettingsService>.Instance);

        AppConfiguration configuration = await service.LoadAsync();

        Assert.True(File.Exists(paths.ConfigurationFile));
        Assert.Equal(120, configuration.Autoclicker.MaximumCps);
        Assert.Equal("XButton1", configuration.Autoclicker.ToggleHotkey);
        Assert.True(configuration.Autoclicker.InventoryPanel.SuppressAutoclicks);
        Assert.False(configuration.Autoclicker.InventoryPanel.ShowBorder);
        Assert.Equal(InventoryPanelConfiguration.DefaultNormalizedLeft, configuration.Autoclicker.InventoryPanel.NormalizedLeft);
        Assert.Equal(12, configuration.Autoclicker.AbilitySlots.Count);
        Assert.All(configuration.Autoclicker.AbilitySlots, slot => Assert.True(slot.AutoclickerEnabled));
        Assert.True(configuration.ManaOverlay.Enabled);
        Assert.Equal(ManaOverlayConfiguration.DefaultNormalizedY, configuration.ManaOverlay.NormalizedY);
        Assert.Equal(5, configuration.Keybinds.Bindings.Count);
        Assert.True(configuration.GateMacro.Enabled);
        Assert.Equal(38, configuration.GateMacro.Mappings.Count);
        Assert.Contains(configuration.GateMacro.Mappings, mapping => mapping.Notation == "d5" && mapping.Location == "desert 5");
        Assert.Contains(configuration.GateMacro.Mappings, mapping => mapping.Notation == "fo4" && mapping.Location == "forge 4");
        Assert.Contains(configuration.GateMacro.Mappings, mapping => mapping.Notation == "sig" && mapping.Location == "sigil");
        OverlayElementConfiguration status = Assert.Single(configuration.Overlay.Elements);
        Assert.Equal(56, status.Width);
        Assert.Equal(-348, status.X);
    }

    [Fact]
    public void ValidationNormalizesManaOverlaySettings()
    {
        AppConfiguration configuration = AppConfiguration.CreateDefault();
        configuration.ManaOverlay.NormalizedX = double.NaN;
        configuration.ManaOverlay.Scale = 99;
        configuration.ManaOverlay.Opacity = 0;

        configuration.ValidateAndNormalize();

        Assert.Equal(ManaOverlayConfiguration.DefaultNormalizedX, configuration.ManaOverlay.NormalizedX);
        Assert.Equal(3, configuration.ManaOverlay.Scale);
        Assert.Equal(0.1, configuration.ManaOverlay.Opacity);
    }

    [Fact]
    public void ValidationMigratesCroppedManaOverlayCoordinatesToFullCanvas()
    {
        AppConfiguration configuration = AppConfiguration.CreateDefault();
        configuration.SchemaVersion = 4;
        configuration.ManaOverlay.NormalizedX = 13d / 1920d;
        configuration.ManaOverlay.NormalizedY = 549d / 1080d;

        configuration.ValidateAndNormalize();

        Assert.Equal(0, configuration.ManaOverlay.NormalizedX, precision: 10);
        Assert.Equal(0, configuration.ManaOverlay.NormalizedY, precision: 10);
        Assert.Equal(AppConfiguration.CurrentSchemaVersion, configuration.SchemaVersion);
    }

    [Fact]
    public async Task SettingsAndDynamicBindingsRoundTrip()
    {
        using TemporaryDirectory temporary = new();
        AppPaths paths = new(temporary.Path);
        using JsonSettingsService writer = new(paths, NullLogger<JsonSettingsService>.Instance);
        AppConfiguration configuration = await writer.LoadAsync();
        configuration.Autoclicker.MaximumCps = 97;
        AbilitySlotConfiguration secondSlot = configuration.Autoclicker.AbilitySlots.Single(slot => slot.Slot == "2");
        secondSlot.Name = "  Dash  ";
        secondSlot.AutoclickerEnabled = false;
        configuration.Keybinds.Bindings.Add(new KeyBinding("Q", "6"));
        configuration.GateMacro.Enabled = true;
        configuration.GateMacro.Mappings = [new GateLocationMapping("custom", "forest 3")];
        await writer.SaveAsync(configuration);

        using JsonSettingsService reader = new(paths, NullLogger<JsonSettingsService>.Instance);
        AppConfiguration reloaded = await reader.LoadAsync();

        Assert.Equal(97, reloaded.Autoclicker.MaximumCps);
        AbilitySlotConfiguration reloadedSlot = reloaded.Autoclicker.AbilitySlots.Single(slot => slot.Slot == "2");
        Assert.Equal("Dash", reloadedSlot.Name);
        Assert.False(reloadedSlot.AutoclickerEnabled);
        Assert.Contains(reloaded.Keybinds.Bindings, binding => binding.Source == "Q" && binding.Target == "6");
        Assert.True(reloaded.GateMacro.Enabled);
        GateLocationMapping gateMapping = Assert.Single(reloaded.GateMacro.Mappings);
        Assert.Equal("custom", gateMapping.Notation);
        Assert.Equal("forest 3", gateMapping.Location);
    }

    [Fact]
    public async Task UsersCanRemoveAllDefaultGateMappings()
    {
        using TemporaryDirectory temporary = new();
        AppPaths paths = new(temporary.Path);
        using JsonSettingsService writer = new(paths, NullLogger<JsonSettingsService>.Instance);
        AppConfiguration configuration = await writer.LoadAsync();
        configuration.GateMacro.Mappings.Clear();
        await writer.SaveAsync(configuration);

        using JsonSettingsService reader = new(paths, NullLogger<JsonSettingsService>.Instance);
        AppConfiguration reloaded = await reader.LoadAsync();

        Assert.Empty(reloaded.GateMacro.Mappings);
    }

    [Theory]
    [InlineData(-10, 1)]
    [InlineData(400, 120)]
    [InlineData(80, 80)]
    public void ValidationClampsMaximumCps(int input, int expected)
    {
        AppConfiguration configuration = AppConfiguration.CreateDefault();
        configuration.Autoclicker.MaximumCps = input;

        configuration.ValidateAndNormalize();

        Assert.Equal(expected, configuration.Autoclicker.MaximumCps);
    }

    [Fact]
    public void ValidationRestoresAnInvalidInventoryPanel()
    {
        AppConfiguration configuration = AppConfiguration.CreateDefault();
        configuration.Autoclicker.InventoryPanel.NormalizedLeft = 0.9;
        configuration.Autoclicker.InventoryPanel.NormalizedRight = 0.1;

        configuration.ValidateAndNormalize();

        Assert.Equal(InventoryPanelConfiguration.DefaultNormalizedLeft, configuration.Autoclicker.InventoryPanel.NormalizedLeft);
        Assert.Equal(InventoryPanelConfiguration.DefaultNormalizedRight, configuration.Autoclicker.InventoryPanel.NormalizedRight);
    }

    [Fact]
    public void ValidationMigratesPreviousStatusOverlayDefaults()
    {
        AppConfiguration configuration = AppConfiguration.CreateDefault();
        configuration.Overlay.Elements =
        [
            new OverlayElementConfiguration
            {
                Id = "autoclicker-status",
                X = -373,
                Y = 96,
                Width = 94,
                Height = 39
            }
        ];

        configuration.ValidateAndNormalize();

        OverlayElementConfiguration status = Assert.Single(configuration.Overlay.Elements);
        Assert.Equal(56, status.Width);
        Assert.Equal(-348, status.X);
    }

    [Fact]
    public async Task MalformedConfigurationIsPreservedAndDefaultsAreRestored()
    {
        using TemporaryDirectory temporary = new();
        AppPaths paths = new(temporary.Path);
        paths.EnsureCreated();
        await File.WriteAllTextAsync(paths.ConfigurationFile, "{ definitely-not-json");
        using JsonSettingsService service = new(paths, NullLogger<JsonSettingsService>.Instance);

        AppConfiguration recovered = await service.LoadAsync();

        Assert.Equal(120, recovered.Autoclicker.MaximumCps);
        Assert.Single(Directory.GetFiles(temporary.Path, "config.corrupt.*.json"));
        Assert.True(File.Exists(paths.ConfigurationFile));
    }

    [Fact]
    public void ValidationReplacesMissingSectionsAndCollections()
    {
        AppConfiguration configuration = AppConfiguration.CreateDefault();
        configuration.General = null!;
        configuration.Autoclicker = null!;
        configuration.Keybinds = null!;
        configuration.GateMacro = null!;
        configuration.ManaOverlay = null!;
        configuration.Overlay = null!;

        configuration.ValidateAndNormalize();

        Assert.Equal("default", configuration.General.ActiveProfileId);
        Assert.Equal(12, configuration.Autoclicker.AbilitySlots.Count);
        Assert.NotNull(configuration.Autoclicker.InventoryPanel);
        Assert.NotNull(configuration.Keybinds.Bindings);
        Assert.NotNull(configuration.GateMacro.Mappings);
        Assert.Equal(ManaOverlayConfiguration.DefaultScale, configuration.ManaOverlay.Scale);
        Assert.Equal("autoclicker-status", Assert.Single(configuration.Overlay.Elements).Id);
    }

    [Fact]
    public void ValidationNormalizesInputAndAbilitySlots()
    {
        AppConfiguration configuration = AppConfiguration.CreateDefault();
        configuration.General.ActiveProfileId = "  alternate  ";
        configuration.Autoclicker.ToggleHotkey = "  F8  ";
        configuration.Autoclicker.HoldThresholdMs = 2_000;
        configuration.Autoclicker.InventoryPanel.NormalizedLeft = -1;
        configuration.Autoclicker.InventoryPanel.NormalizedTop = -1;
        configuration.Autoclicker.InventoryPanel.NormalizedRight = 2;
        configuration.Autoclicker.InventoryPanel.NormalizedBottom = 2;
        configuration.Autoclicker.AbilitySlots =
        [
            new AbilitySlotConfiguration(" 2 ", new string('a', AbilitySlotConfiguration.MaximumNameLength + 10), false),
            new AbilitySlotConfiguration("2", "ignored duplicate", true),
            new AbilitySlotConfiguration("unsupported", "ignored", false)
        ];
        configuration.Keybinds.Bindings = [new KeyBinding("  Q  ", "  6  ")];

        configuration.ValidateAndNormalize();

        Assert.Equal("alternate", configuration.General.ActiveProfileId);
        Assert.Equal("F8", configuration.Autoclicker.ToggleHotkey);
        Assert.Equal(1_000, configuration.Autoclicker.HoldThresholdMs);
        Assert.Equal(0, configuration.Autoclicker.InventoryPanel.NormalizedLeft);
        Assert.Equal(0, configuration.Autoclicker.InventoryPanel.NormalizedTop);
        Assert.Equal(1, configuration.Autoclicker.InventoryPanel.NormalizedRight);
        Assert.Equal(1, configuration.Autoclicker.InventoryPanel.NormalizedBottom);
        Assert.Equal(12, configuration.Autoclicker.AbilitySlots.Count);
        AbilitySlotConfiguration secondSlot = configuration.Autoclicker.AbilitySlots.Single(slot => slot.Slot == "2");
        Assert.Equal(AbilitySlotConfiguration.MaximumNameLength, secondSlot.Name.Length);
        Assert.False(secondSlot.AutoclickerEnabled);
        Assert.Equal("Q", Assert.Single(configuration.Keybinds.Bindings).Source);
        Assert.Equal("6", Assert.Single(configuration.Keybinds.Bindings).Target);
    }

    [Fact]
    public async Task SaveNormalizesConfigurationAndRaisesSettingsChanged()
    {
        using TemporaryDirectory temporary = new();
        AppPaths paths = new(temporary.Path);
        using JsonSettingsService service = new(paths, NullLogger<JsonSettingsService>.Instance);
        AppConfiguration configuration = AppConfiguration.CreateDefault();
        configuration.Autoclicker.MaximumCps = 500;
        AppConfiguration? notification = null;
        service.SettingsChanged += (_, updated) => notification = updated;

        await service.SaveAsync(configuration);

        Assert.Same(configuration, service.Current);
        Assert.Same(configuration, notification);
        Assert.Equal(120, configuration.Autoclicker.MaximumCps);
        Assert.True(File.Exists(paths.ConfigurationFile));
        Assert.False(File.Exists(paths.ConfigurationFile + ".tmp"));
    }

    [Fact]
    public async Task NullConfigurationIsPreservedAndDefaultsAreRestored()
    {
        using TemporaryDirectory temporary = new();
        AppPaths paths = new(temporary.Path);
        paths.EnsureCreated();
        await File.WriteAllTextAsync(paths.ConfigurationFile, "null");
        using JsonSettingsService service = new(paths, NullLogger<JsonSettingsService>.Instance);

        AppConfiguration recovered = await service.LoadAsync();

        Assert.Equal(120, recovered.Autoclicker.MaximumCps);
        Assert.Single(Directory.GetFiles(temporary.Path, "config.corrupt.*.json"));
        Assert.NotEqual("null", (await File.ReadAllTextAsync(paths.ConfigurationFile)).Trim());
    }

    [Fact]
    public void ValidationNormalizesGateMappings()
    {
        AppConfiguration configuration = AppConfiguration.CreateDefault();
        configuration.GateMacro.Mappings =
        [
            new GateLocationMapping("  D5  ", "  desert 5  "),
            new GateLocationMapping("d5", "duplicate"),
            new GateLocationMapping("d50", "distinct longer notation"),
            new GateLocationMapping("not valid", "ignored"),
            new GateLocationMapping("c2", "castle\r\n2")
        ];

        configuration.ValidateAndNormalize();

        Assert.Collection(
            configuration.GateMacro.Mappings,
            mapping =>
            {
                Assert.Equal("d5", mapping.Notation);
                Assert.Equal("desert 5", mapping.Location);
            },
            mapping =>
            {
                Assert.Equal("d50", mapping.Notation);
                Assert.Equal("distinct longer notation", mapping.Location);
            },
            mapping =>
            {
                Assert.Equal("c2", mapping.Notation);
                Assert.Equal("castle  2", mapping.Location);
            });
    }
}
