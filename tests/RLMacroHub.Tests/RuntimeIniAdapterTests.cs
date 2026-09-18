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

        RuntimeIniAdapter adapter = new(NullLogger<RuntimeIniAdapter>.Instance);
        string ini = adapter.Export(configuration);

        Assert.Contains("[Runtime]", ini, StringComparison.Ordinal);
        Assert.Contains("SchemaVersion=5", ini, StringComparison.Ordinal);
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
        Assert.Contains("[ManaOverlay]", ini, StringComparison.Ordinal);
        Assert.Contains("NormalizedY=0", ini, StringComparison.Ordinal);
        Assert.Contains("Opacity=1", ini, StringComparison.Ordinal);
        Assert.Contains("Width=56", ini, StringComparison.Ordinal);
        Assert.Contains("RightOffset=348", ini, StringComparison.Ordinal);
    }
}
