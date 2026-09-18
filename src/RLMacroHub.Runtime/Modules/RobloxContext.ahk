class RobloxContext {
    static WindowSelector := "ahk_exe RobloxPlayerBeta.exe"

    IsActive() => WinActive(RobloxContext.WindowSelector) != 0

    IsMinimized() {
        try return WinGetMinMax(RobloxContext.WindowSelector) = -1
        catch
            return false
    }

    TryGetBounds(&x, &y, &width, &height) {
        try {
            WinGetPos(&x, &y, &width, &height, RobloxContext.WindowSelector)
            return width != "" && height != ""
        } catch {
            x := 0
            y := 0
            width := 0
            height := 0
            return false
        }
    }

    TryGetClientBounds(&x, &y, &width, &height) {
        x := 0
        y := 0
        width := 0
        height := 0
        hwnd := WinExist(RobloxContext.WindowSelector)
        if !hwnd
            return false

        clientRect := Buffer(16, 0)
        clientOrigin := Buffer(8, 0)
        if !DllCall("GetClientRect", "Ptr", hwnd, "Ptr", clientRect, "Int")
            return false
        if !DllCall("ClientToScreen", "Ptr", hwnd, "Ptr", clientOrigin, "Int")
            return false

        x := NumGet(clientOrigin, 0, "Int")
        y := NumGet(clientOrigin, 4, "Int")
        width := NumGet(clientRect, 8, "Int") - NumGet(clientRect, 0, "Int")
        height := NumGet(clientRect, 12, "Int") - NumGet(clientRect, 4, "Int")
        return width > 0 && height > 0
    }
}
