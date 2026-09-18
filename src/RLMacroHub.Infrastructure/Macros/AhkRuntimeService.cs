using System.Diagnostics;
using Microsoft.Extensions.Logging;
using RLMacroHub.Core.Models;
using RLMacroHub.Core.Services;
using RLMacroHub.Infrastructure.Windows;

namespace RLMacroHub.Infrastructure.Macros;

public sealed class AhkRuntimeService : IMacroRuntimeService
{
    private readonly AhkRuntimeDiscovery _discovery;
    private readonly ILogger<AhkRuntimeService> _logger;
    private readonly SemaphoreSlim _gate = new(1, 1);
    private Process? _process;
    private bool _requestedStop;

    public AhkRuntimeService(AhkRuntimeDiscovery discovery, ILogger<AhkRuntimeService> logger)
    {
        _discovery = discovery;
        _logger = logger;
    }

    public MacroRuntimeState State { get; private set; } = MacroRuntimeState.Stopped;
    public string? LastError { get; private set; }
    public event EventHandler<MacroRuntimeState>? StateChanged;

    public async Task StartAsync(string scriptPath, string? explicitExecutablePath = null, CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (_process is { HasExited: false })
            {
                return;
            }

            if (!File.Exists(scriptPath))
            {
                SetState(MacroRuntimeState.Unavailable, "The AHK runtime entry point was not found.");
                return;
            }

            string? executable = _discovery.ResolveExecutable(explicitExecutablePath);
            if (executable is null)
            {
                SetState(MacroRuntimeState.Unavailable, "AutoHotkey v2 was not found. Set a compatible executable path in Settings.");
                return;
            }

            SetState(MacroRuntimeState.Starting);
            _requestedStop = false;
            Process process = new()
            {
                StartInfo = new ProcessStartInfo(executable)
                {
                    UseShellExecute = false,
                    WorkingDirectory = Path.GetDirectoryName(scriptPath)!,
                    ArgumentList = { scriptPath }
                },
                EnableRaisingEvents = true
            };
            process.Exited += OnProcessExited;

            if (!process.Start())
            {
                process.Dispose();
                SetState(MacroRuntimeState.Faulted, "AutoHotkey did not start.");
                return;
            }

            _process = process;
            _logger.LogInformation("AHK v2 process {ProcessId} started using {Executable}.", process.Id, executable);
            SetState(MacroRuntimeState.Running);
        }
        catch (Exception exception) when (exception is InvalidOperationException or System.ComponentModel.Win32Exception or IOException)
        {
            _logger.LogError(exception, "AHK process failed to start.");
            SetState(MacroRuntimeState.Faulted, "AutoHotkey could not be started. See the log for details.");
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task StopAsync(CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            if (_process is null || _process.HasExited)
            {
                CleanupProcess();
                SetState(MacroRuntimeState.Stopped);
                return;
            }

            _requestedStop = true;
            SetState(MacroRuntimeState.Stopping);
            Process process = _process;
            bool closePosted = PostCloseToProcessWindows(process.Id);
            if (!closePosted)
            {
                closePosted = process.CloseMainWindow();
            }

            if (!closePosted || !await WaitForExitAsync(process, TimeSpan.FromSeconds(3), cancellationToken).ConfigureAwait(false))
            {
                _logger.LogWarning("Graceful AHK shutdown failed; terminating process {ProcessId} as a fallback.", process.Id);
                process.Kill(entireProcessTree: true);
                await process.WaitForExitAsync(cancellationToken).ConfigureAwait(false);
            }

            CleanupProcess();
            SetState(MacroRuntimeState.Stopped);
        }
        finally
        {
            _gate.Release();
        }
    }

    private void OnProcessExited(object? sender, EventArgs eventArgs)
    {
        if (sender is not Process process)
        {
            return;
        }

        _logger.LogInformation("AHK process {ProcessId} exited with code {ExitCode}.", process.Id, process.ExitCode);
        if (!_requestedStop)
        {
            SetState(MacroRuntimeState.Faulted, $"The macro exited unexpectedly (code {process.ExitCode}).");
        }
    }

    private static bool PostCloseToProcessWindows(int processId)
    {
        bool posted = false;
        _ = NativeMethods.EnumWindows((hwnd, parameter) =>
        {
            _ = parameter;
            _ = NativeMethods.GetWindowThreadProcessId(hwnd, out uint ownerProcessId);
            if (ownerProcessId == (uint)processId)
            {
                posted |= NativeMethods.PostMessage(hwnd, NativeMethods.WmClose, nint.Zero, nint.Zero);
            }

            return true;
        }, nint.Zero);
        return posted;
    }

    private static async Task<bool> WaitForExitAsync(Process process, TimeSpan timeout, CancellationToken cancellationToken)
    {
        try
        {
            await process.WaitForExitAsync(cancellationToken).WaitAsync(timeout, cancellationToken).ConfigureAwait(false);
            return true;
        }
        catch (TimeoutException)
        {
            return false;
        }
    }

    private void SetState(MacroRuntimeState state, string? error = null)
    {
        State = state;
        LastError = error;
        StateChanged?.Invoke(this, state);
    }

    private void CleanupProcess()
    {
        if (_process is not null)
        {
            _process.Exited -= OnProcessExited;
            _process.Dispose();
            _process = null;
        }
    }

    public async ValueTask DisposeAsync()
    {
        await StopAsync().ConfigureAwait(false);
        _gate.Dispose();
        GC.SuppressFinalize(this);
    }
}
