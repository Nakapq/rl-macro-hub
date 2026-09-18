using Microsoft.UI.Xaml.Controls;
using RLMacroHub.App.ViewModels;

namespace RLMacroHub.App.Views;

public sealed partial class MacrosPage : Page
{
    public MacrosPage(MacrosViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
    }

    public MacrosViewModel ViewModel { get; }
}
