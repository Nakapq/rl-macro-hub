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
        await writer.SaveAsync(configuration);

        using JsonSettingsService reader = new(paths, NullLogger<JsonSettingsService>.Instance);
        AppConfiguration reloaded = await reader.LoadAsync();

        Assert.Equal(97, reloaded.Autoclicker.MaximumCps);
        AbilitySlotConfiguration reloadedSlot = reloaded.Autoclicker.AbilitySlots.Single(slot => slot.Slot == "2");
        Assert.Equal("Dash", reloadedSlot.Name);
        Assert.False(reloadedSlot.AutoclickerEnabled);
        Assert.Contains(reloaded.Keybinds.Bindings, binding => binding.Source == "Q" && binding.Target == "6");
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
}
