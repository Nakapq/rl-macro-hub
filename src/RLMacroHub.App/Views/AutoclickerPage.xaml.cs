using Microsoft.UI.Xaml.Controls;
using RLMacroHub.App.ViewModels;

namespace RLMacroHub.App.Views;

public sealed partial class AutoclickerPage : Page
{
    public AutoclickerPage(AutoclickerViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
    }

    public AutoclickerViewModel ViewModel { get; }
}
