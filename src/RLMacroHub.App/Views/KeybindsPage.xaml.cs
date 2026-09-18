using Microsoft.UI.Xaml.Controls;
using RLMacroHub.App.ViewModels;

namespace RLMacroHub.App.Views;

public sealed partial class KeybindsPage : Page
{
    public KeybindsPage(KeybindsViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
    }

    public KeybindsViewModel ViewModel { get; }
}
