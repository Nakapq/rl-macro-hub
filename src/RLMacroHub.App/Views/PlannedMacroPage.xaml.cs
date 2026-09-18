using Microsoft.UI.Xaml.Controls;

namespace RLMacroHub.App.Views;

public sealed partial class PlannedMacroPage : Page
{
    public PlannedMacroPage(string pageTitle, string description)
    {
        PageTitle = pageTitle;
        Description = description;
        InitializeComponent();
    }

    public string PageTitle { get; }
    public string Description { get; }
}
