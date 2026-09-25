using Microsoft.UI.Xaml.Controls;
using RLMacroHub.App.ViewModels;

namespace RLMacroHub.App.Views;

public sealed partial class GateMacroPage : Page
{
    public GateMacroPage(GateMacroViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
    }

    public GateMacroViewModel ViewModel { get; }
}
