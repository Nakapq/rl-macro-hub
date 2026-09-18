using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.UI.Xaml;
using RLMacroHub.App.Services;
using RLMacroHub.App.ViewModels;
using RLMacroHub.App.Views;
using RLMacroHub.App.Windows;
using RLMacroHub.Core.Services;
using RLMacroHub.Infrastructure.Configuration;
using RLMacroHub.Infrastructure.Logging;
using RLMacroHub.Infrastructure.Macros;
using RLMacroHub.Infrastructure.Profiles;
using RLMacroHub.Infrastructure.Roblox;
using RLMacroHub.Infrastructure.Windows;

namespace RLMacroHub.App;

public partial class App : Application
{
    private ServiceProvider? _serviceProvider;
    private MainWindow? _mainWindow;
    private bool _shuttingDown;

    public App()
    {
        InitializeComponent();
        RequestedTheme = ApplicationTheme.Dark;
    }

    protected override async void OnLaunched(LaunchActivatedEventArgs args)
    {
        base.OnLaunched(args);
        AppPaths paths = new();
        FileLoggerProvider fileLogger = new(paths);
        ServiceCollection services = new();
        services.AddSingleton(paths);
        services.AddSingleton(fileLogger);
        services.AddLogging(builder => builder.SetMinimumLevel(LogLevel.Information).AddProvider(fileLogger));
        services.AddSingleton<ISettingsService, JsonSettingsService>();
        services.AddSingleton<IProfileService, ProfileService>();
        services.AddSingleton<RuntimeIniAdapter>();
        services.AddSingleton<AhkRuntimeDiscovery>();
        services.AddSingleton<RuntimeAssetStager>();
        services.AddSingleton<IMacroRuntimeService, AhkRuntimeService>();
        services.AddSingleton<IRobloxWindowService, RobloxWindowService>();
        services.AddSingleton<WindowInteropService>();
        services.AddSingleton<IOverlayService, OverlayService>();

        services.AddSingleton<DashboardViewModel>();
        services.AddSingleton<MacrosViewModel>();
        services.AddSingleton<AutoclickerViewModel>();
        services.AddSingleton<KeybindsViewModel>();
        services.AddSingleton<ManaOverlayViewModel>();
        services.AddSingleton<ProfilesViewModel>();
        services.AddSingleton<SettingsViewModel>();

        services.AddSingleton<DashboardPage>();
        services.AddSingleton<MacrosPage>();
        services.AddSingleton<AutoclickerPage>();
        services.AddSingleton<KeybindsPage>();
        services.AddSingleton<ManaOverlayPage>();
        services.AddSingleton<OverlayPage>();
        services.AddSingleton<ProfilesPage>();
        services.AddSingleton<SettingsPage>();
        services.AddSingleton<MainWindow>();

        _serviceProvider = services.BuildServiceProvider();
        ILogger<App> logger = _serviceProvider.GetRequiredService<ILogger<App>>();
        try
        {
            logger.LogInformation("RL Macro Hub starting.");
            await _serviceProvider.GetRequiredService<ISettingsService>().LoadAsync();
            await _serviceProvider.GetRequiredService<IRobloxWindowService>().StartAsync();
            _mainWindow = _serviceProvider.GetRequiredService<MainWindow>();
            _mainWindow.Closed += OnMainWindowClosed;
            _mainWindow.Activate();
        }
        catch (Exception exception)
        {
            logger.LogCritical(exception, "Application startup failed.");
            throw;
        }
    }

    private async void OnMainWindowClosed(object sender, WindowEventArgs args)
    {
        if (_shuttingDown || _serviceProvider is null)
        {
            return;
        }

        _shuttingDown = true;
        ILogger<App> logger = _serviceProvider.GetRequiredService<ILogger<App>>();
        logger.LogInformation("RL Macro Hub shutting down.");
        await _serviceProvider.GetRequiredService<IOverlayService>().HideAsync();
        await _serviceProvider.GetRequiredService<IMacroRuntimeService>().StopAsync();
        await _serviceProvider.GetRequiredService<IRobloxWindowService>().StopAsync();
        await _serviceProvider.DisposeAsync();
    }
}
