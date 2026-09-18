using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using RLMacroHub.App.ViewModels;

namespace RLMacroHub.App.Views;

public sealed partial class ProfilesPage : Page
{
    public ProfilesPage(ProfilesViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
    }

    public ProfilesViewModel ViewModel { get; }

    private async void OnLoaded(object sender, RoutedEventArgs args) => await ViewModel.InitializeAsync();
}
