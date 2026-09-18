using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;

namespace RLMacroHub.App.Windows;

public sealed partial class OverlayWindow : Window
{
    public OverlayWindow()
    {
        InitializeComponent();
        if (AppWindow.Presenter is OverlappedPresenter presenter)
        {
            presenter.SetBorderAndTitleBar(false, false);
            presenter.IsAlwaysOnTop = true;
            presenter.IsResizable = false;
            presenter.IsMaximizable = false;
            presenter.IsMinimizable = false;
        }

        AppWindow.IsShownInSwitchers = false;
    }
}
