using Microsoft.UI.Xaml.Controls;
using RLMacroHub.App.ViewModels;

namespace RLMacroHub.App.Views;

public sealed partial class ManaOverlayPage : Page
{
    public ManaOverlayPage(ManaOverlayViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
    }

    public ManaOverlayViewModel ViewModel { get; }
}
