using Microsoft.Extensions.Logging.Abstractions;
using RLMacroHub.Core.Models;
using RLMacroHub.Infrastructure.Configuration;

namespace RLMacroHub.Tests;

public sealed class RuntimeIniAdapterTests
{
    [Fact]
    public void ExportIncludesAllBindingsAndBehaviorSettings()
    {
        AppConfiguration configuration = AppConfiguration.CreateDefault();
        for (int index = 0; index < 8; index++)
        {
            configuration.Keybinds.Bindings.Add(new KeyBinding($"F{index + 1}", $"Numpad{index}"));
        }
        AbilitySlotConfiguration secondSlot = configuration.Autoclicker.AbilitySlots.Single(slot => slot.Slot == "2");
        secondSlot.Name = "Dash";
        secondSlot.AutoclickerEnabled = false;
        configuration.GateMacro.Enabled = true;
        configuration.GateMacro.Mappings.Add(new GateLocationMapping("d5", "desert 5"));

        RuntimeIniAdapter adapter = new(NullLogger<RuntimeIniAdapter>.Instance);
        string ini = adapter.Export(configuration);

        Assert.Contains("[Runtime]", ini, StringComparison.Ordinal);
        Assert.Contains("SchemaVersion=6", ini, StringComparison.Ordinal);
        Assert.Contains("MaximumCps=120", ini, StringComparison.Ordinal);
        Assert.Contains("HoldThresholdMs=30", ini, StringComparison.Ordinal);
        Assert.DoesNotContain("YieldMs", ini, StringComparison.Ordinal);
        Assert.Contains("[InventoryPanel]", ini, StringComparison.Ordinal);
        Assert.Contains("SuppressAutoclicks=1", ini, StringComparison.Ordinal);
        Assert.Contains("ShowBorder=0", ini, StringComparison.Ordinal);
        Assert.Contains("NormalizedLeft=0.249479", ini, StringComparison.Ordinal);
        Assert.DoesNotContain("SuppressWhileInventoryOpen", ini, StringComparison.Ordinal);
        Assert.Contains("[AbilitySlots]", ini, StringComparison.Ordinal);
        Assert.Contains("SlotCount=12", ini, StringComparison.Ordinal);
        Assert.Contains("Slot2_Key=2", ini, StringComparison.Ordinal);
        Assert.Contains("Slot2_AutoclickerEnabled=0", ini, StringComparison.Ordinal);
        Assert.DoesNotContain("Dash", ini, StringComparison.Ordinal);
        Assert.DoesNotContain("WeaponSlot", ini, StringComparison.Ordinal);
        Assert.Contains("BindingCount=13", ini, StringComparison.Ordinal);
        Assert.Contains("Binding13_Source=F8", ini, StringComparison.Ordinal);
        Assert.Contains("Binding13_Target=Numpad7", ini, StringComparison.Ordinal);
        Assert.Contains("[GateMacro]", ini, StringComparison.Ordinal);
        Assert.Contains("Enabled=1", ini, StringComparison.Ordinal);
        Assert.Contains("MappingCount=1", ini, StringComparison.Ordinal);
        Assert.Contains("Mapping1_Notation=d5", ini, StringComparison.Ordinal);
        Assert.Contains("Mapping1_Location=desert 5", ini, StringComparison.Ordinal);
        Assert.Contains("[ManaOverlay]", ini, StringComparison.Ordinal);
        Assert.Contains("NormalizedY=0", ini, StringComparison.Ordinal);
        Assert.Contains("Opacity=1", ini, StringComparison.Ordinal);
        Assert.Contains("Width=56", ini, StringComparison.Ordinal);
        Assert.Contains("RightOffset=348", ini, StringComparison.Ordinal);
    }

    [Fact]
    public async Task ExportAsyncWritesAtomicallyAndSanitizesBindings()
    {
        using TemporaryDirectory temporary = new();
        string destination = Path.Combine(temporary.Path, "nested", "runtime.ini");
        AppConfiguration configuration = AppConfiguration.CreateDefault();
        configuration.Keybinds.Bindings = [new KeyBinding("  Q\r\nInjected=1  ", "  6  ")];
        RuntimeIniAdapter adapter = new(NullLogger<RuntimeIniAdapter>.Instance);

        await adapter.ExportAsync(configuration, destination);

        string ini = await File.ReadAllTextAsync(destination);
        Assert.Contains("Binding1_Source=QInjected=1", ini, StringComparison.Ordinal);
        Assert.Contains("Binding1_Target=6", ini, StringComparison.Ordinal);
        Assert.DoesNotContain("\nInjected=1", ini, StringComparison.Ordinal);
        Assert.False(File.Exists(destination + ".tmp"));
    }
}
