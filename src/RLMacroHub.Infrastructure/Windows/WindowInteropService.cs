namespace RLMacroHub.Infrastructure.Windows;

public sealed class WindowInteropService
{
    public void ConfigureOverlay(nint hwnd, bool clickThrough)
    {
        nint style = NativeMethods.GetWindowLongPtr(hwnd, NativeMethods.GwlExStyle);
        style |= NativeMethods.WsExToolWindow | NativeMethods.WsExNoActivate;
        if (clickThrough)
        {
            style |= NativeMethods.WsExTransparent;
        }
        else
        {
            style &= ~NativeMethods.WsExTransparent;
        }

        _ = NativeMethods.SetWindowLongPtr(hwnd, NativeMethods.GwlExStyle, style);
        _ = NativeMethods.SetWindowPos(
            hwnd,
            NativeMethods.HwndTopMost,
            0,
            0,
            0,
            0,
            NativeMethods.SwpNoMove | NativeMethods.SwpNoSize | NativeMethods.SwpNoActivate);
    }

    public void MoveTopmostNoActivate(nint hwnd, int x, int y, int width, int height) =>
        _ = NativeMethods.SetWindowPos(hwnd, NativeMethods.HwndTopMost, x, y, width, height, NativeMethods.SwpNoActivate);
}
