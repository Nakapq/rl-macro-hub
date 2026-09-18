using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using RLMacroHub.App.ViewModels;
using RLMacroHub.App.Views;
using Windows.Graphics;

namespace RLMacroHub.App.Windows;

public sealed partial class MainWindow : Window
{
    private readonly Dictionary<string, UIElement> _pages;

    public MainWindow(
        DashboardPage dashboard,
        MacrosPage macros,
        AutoclickerPage autoclicker,
        KeybindsPage keybinds,
        ManaOverlayPage manaOverlay,
        OverlayPage overlay,
        ProfilesPage profiles,
        SettingsPage settings,
        DashboardViewModel dashboardViewModel)
    {
        InitializeComponent();
        ExtendsContentIntoTitleBar = true;
        SetTitleBar(AppTitleBar);
        SystemBackdrop = new MicaBackdrop();
        AppWindow.Resize(new SizeInt32(1100, 720));
        if (AppWindow.Presenter is OverlappedPresenter presenter)
        {
            presenter.PreferredMinimumWidth = 900;
            presenter.PreferredMinimumHeight = 600;
        }

        _pages = new Dictionary<string, UIElement>(StringComparer.Ordinal)
        {
            ["dashboard"] = dashboard,
            ["macros"] = macros,
            ["autoclicker"] = autoclicker,
            ["keybinds"] = keybinds,
            ["overlay"] = overlay,
            ["profiles"] = profiles,
            ["settings"] = settings,
            ["mana"] = manaOverlay,
            ["gate"] = new PlannedMacroPage("Gate Macro", "Gate automation is planned and is not presented as active yet."),
            ["cooldowns"] = new PlannedMacroPage("Cooldown Indicators", "A reusable cooldown engine and indicators are planned for Phase 3.")
        };

        dashboardViewModel.NavigationRequested += Navigate;
        Navigation.SelectedItem = Navigation.MenuItems[0];
        Navigate("dashboard");
    }

    private void OnNavigationSelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.SelectedItemContainer?.Tag is string tag)
        {
            Navigate(tag);
        }
    }

    private void Navigate(string tag)
    {
        if (_pages.TryGetValue(tag, out UIElement? page))
        {
            ContentFrame.Content = page;
            Navigation.Header = null;

            NavigationViewItem? item = FindNavigationItem(Navigation.MenuItems, tag);
            if (item is not null)
            {
                Navigation.SelectedItem = item;
            }
        }
    }

    private static NavigationViewItem? FindNavigationItem(IEnumerable<object> items, string tag)
    {
        foreach (object itemObject in items)
        {
            if (itemObject is not NavigationViewItem item)
            {
                continue;
            }

            if (string.Equals(item.Tag as string, tag, StringComparison.Ordinal))
            {
                return item;
            }

            NavigationViewItem? nested = FindNavigationItem(item.MenuItems, tag);
            if (nested is not null)
            {
                return nested;
            }
        }

        return null;
    }
}
