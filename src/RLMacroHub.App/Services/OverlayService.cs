using Microsoft.UI.Dispatching;
using RLMacroHub.App.Windows;
using RLMacroHub.Core.Models;
using RLMacroHub.Core.Services;
using RLMacroHub.Infrastructure.Windows;
using WinRT.Interop;

namespace RLMacroHub.App.Services;

public sealed class OverlayService : IOverlayService
{
    private readonly IRobloxWindowService _roblox;
    private readonly ISettingsService _settings;
    private readonly WindowInteropService _windowInterop;
    private readonly DispatcherQueue _dispatcher;
    private OverlayWindow? _window;
    private bool _editMode;
    private bool _requestedVisible;

    public OverlayService(IRobloxWindowService roblox, ISettingsService settings, WindowInteropService windowInterop)
    {
        _roblox = roblox;
        _settings = settings;
        _windowInterop = windowInterop;
        _dispatcher = DispatcherQueue.GetForCurrentThread();
        _roblox.StateChanged += OnRobloxStateChanged;
    }

    public bool IsVisible => _requestedVisible;

    public Task ShowAsync(CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        _requestedVisible = true;
        EnsureWindow();
        UpdateWindow(_roblox.Current);
        return Task.CompletedTask;
    }

    public Task HideAsync(CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        _requestedVisible = false;
        _window?.AppWindow.Hide();
        return Task.CompletedTask;
    }

    public Task SetEditModeAsync(bool enabled, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();
        _editMode = enabled;
        if (_window is not null)
        {
            _windowInterop.ConfigureOverlay(WindowNative.GetWindowHandle(_window), clickThrough: !enabled);
        }

        return Task.CompletedTask;
    }

    private void EnsureWindow()
    {
        if (_window is not null)
        {
            return;
        }

        _window = new OverlayWindow();
        _windowInterop.ConfigureOverlay(WindowNative.GetWindowHandle(_window), clickThrough: !_editMode);
    }

    private void OnRobloxStateChanged(object? sender, RobloxWindowState state) =>
        _ = _dispatcher.TryEnqueue(() => UpdateWindow(state));

    private void UpdateWindow(RobloxWindowState state)
    {
        if (!_requestedVisible)
        {
            return;
        }

        EnsureWindow();
        if (_window is null)
        {
            return;
        }

        bool shouldShow = _editMode || (state.IsRunning && state.IsForeground && !state.IsMinimized);
        if (!shouldShow)
        {
            _window.AppWindow.Hide();
            return;
        }

        OverlayElementConfiguration element = _settings.Current.Overlay.Elements
            .FirstOrDefault(candidate => candidate.Id == "autoclicker-status") ?? new OverlayElementConfiguration();
        int x = state.IsRunning
            ? state.Bounds.X + state.Bounds.Width + (int)element.X
            : 100;
        int y = state.IsRunning ? state.Bounds.Y + (int)element.Y : 100;
        _windowInterop.MoveTopmostNoActivate(
            WindowNative.GetWindowHandle(_window),
            x,
            y,
            (int)element.Width,
            (int)element.Height);
        _window.Activate();
        _windowInterop.ConfigureOverlay(WindowNative.GetWindowHandle(_window), clickThrough: !_editMode);
    }
}
