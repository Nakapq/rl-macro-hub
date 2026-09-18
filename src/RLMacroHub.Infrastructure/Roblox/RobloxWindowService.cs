using System.Diagnostics;
using Microsoft.Extensions.Logging;
using RLMacroHub.Core.Models;
using RLMacroHub.Core.Services;
using RLMacroHub.Infrastructure.Windows;

namespace RLMacroHub.Infrastructure.Roblox;

public sealed class RobloxWindowService : IRobloxWindowService
{
    private readonly ILogger<RobloxWindowService> _logger;
    private CancellationTokenSource? _lifetime;
    private Task? _trackingTask;

    public RobloxWindowService(ILogger<RobloxWindowService> logger) => _logger = logger;

    public RobloxWindowState Current { get; private set; } = RobloxWindowState.NotRunning;
    public event EventHandler<RobloxWindowState>? StateChanged;

    public Task StartAsync(CancellationToken cancellationToken = default)
    {
        if (_trackingTask is not null)
        {
            return Task.CompletedTask;
        }

        _lifetime = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        _trackingTask = TrackAsync(_lifetime.Token);
        return Task.CompletedTask;
    }

    public async Task StopAsync(CancellationToken cancellationToken = default)
    {
        if (_lifetime is null || _trackingTask is null)
        {
            return;
        }

        await _lifetime.CancelAsync().ConfigureAwait(false);
        try
        {
            await _trackingTask.WaitAsync(cancellationToken).ConfigureAwait(false);
        }
        catch (OperationCanceledException)
        {
        }

        _trackingTask = null;
        _lifetime.Dispose();
        _lifetime = null;
    }

    private async Task TrackAsync(CancellationToken cancellationToken)
    {
        using PeriodicTimer timer = new(TimeSpan.FromSeconds(1));
        do
        {
            RobloxWindowState next = Detect();
            if (next != Current)
            {
                bool discovered = !Current.IsRunning && next.IsRunning;
                bool lost = Current.IsRunning && !next.IsRunning;
                Current = next;
                if (discovered)
                {
                    _logger.LogInformation("Roblox window discovered (HWND 0x{Hwnd:X}).", next.Hwnd);
                }
                else if (lost)
                {
                    _logger.LogInformation("Roblox window lost.");
                }

                StateChanged?.Invoke(this, next);
            }
        }
        while (await timer.WaitForNextTickAsync(cancellationToken).ConfigureAwait(false));
    }

    private static RobloxWindowState Detect()
    {
        Process[] processes = Process.GetProcessesByName("RobloxPlayerBeta");
        try
        {
            foreach (Process process in processes)
            {
                try
                {
                    process.Refresh();
                    nint hwnd = process.MainWindowHandle;
                    if (hwnd == nint.Zero || !NativeMethods.GetWindowRect(hwnd, out NativeMethods.Rect rect))
                    {
                        continue;
                    }

                    return new RobloxWindowState(
                        true,
                        NativeMethods.GetForegroundWindow() == hwnd,
                        NativeMethods.IsIconic(hwnd),
                        hwnd,
                        new WindowBounds(rect.Left, rect.Top, rect.Right - rect.Left, rect.Bottom - rect.Top));
                }
                catch (InvalidOperationException)
                {
                }
            }
        }
        finally
        {
            foreach (Process process in processes)
            {
                process.Dispose();
            }
        }

        return RobloxWindowState.NotRunning;
    }

    public async ValueTask DisposeAsync()
    {
        await StopAsync().ConfigureAwait(false);
        GC.SuppressFinalize(this);
    }
}
