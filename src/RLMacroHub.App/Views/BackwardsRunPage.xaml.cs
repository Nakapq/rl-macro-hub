using Microsoft.UI.Xaml.Controls;
using RLMacroHub.App.ViewModels;

namespace RLMacroHub.App.Views;

public sealed partial class BackwardsRunPage : Page
{
    public BackwardsRunPage(BackwardsRunViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
    }

    public BackwardsRunViewModel ViewModel { get; }
}
