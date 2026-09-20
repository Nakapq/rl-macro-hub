using System.Collections.ObjectModel;
using CommunityToolkit.Mvvm.ComponentModel;
using RLMacroHub.Core.Services;

namespace RLMacroHub.App.ViewModels;

public sealed class MacrosViewModel : ObservableObject
{
    private readonly SynchronizationContext? _synchronizationContext;

    public MacrosViewModel(ISettingsService settings)
    {
        _synchronizationContext = SynchronizationContext.Current;
        Refresh(settings.Current);
        settings.SettingsChanged += (_, configuration) => Post(() => Refresh(configuration));
    }

    public ObservableCollection<MacroListItem> Items { get; } = [];

    private void Refresh(Core.Models.AppConfiguration configuration)
    {
        Items.Clear();
        Items.Add(new("Autoclicker", "High-resolution modular AHK v2 click scheduler", configuration.Autoclicker.Enabled ? "Enabled" : "Disabled", "autoclicker", true));
        Items.Add(new("Keybinds", "Shared-state, modifier-aware Roblox remapping", configuration.Keybinds.Enabled ? "Enabled" : "Disabled", "keybinds", true));
        Items.Add(new("Mana Overlay", "Transparent PNG guide aligned to the focused Roblox client", configuration.ManaOverlay.Enabled ? "Enabled" : "Disabled", "mana", true));
        Items.Add(new("Gate Macro", "Exact chat notation expansion for gate locations", configuration.GateMacro.Enabled ? "Enabled" : "Disabled", "gate", true));
        Items.Add(new("Cooldown Indicators", "Reusable visual cooldown tracking", "Planned", "cooldowns", false));
    }

    private void Post(Action action)
    {
        if (_synchronizationContext is null)
        {
            action();
        }
        else
        {
            _synchronizationContext.Post(_ => action(), null);
        }
    }
}

public sealed record MacroListItem(string Name, string Description, string Status, string Page, bool IsAvailable)
{
    public double AvailableStatusOpacity => IsAvailable ? 1 : 0;
    public double PlannedStatusOpacity => IsAvailable ? 0 : 1;
}
