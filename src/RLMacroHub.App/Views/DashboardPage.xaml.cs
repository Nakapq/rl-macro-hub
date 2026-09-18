using Microsoft.UI.Xaml.Controls;
using RLMacroHub.App.ViewModels;

namespace RLMacroHub.App.Views;

public sealed partial class DashboardPage : Page
{
    public DashboardPage(DashboardViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
    }

    public DashboardViewModel ViewModel { get; }
}
