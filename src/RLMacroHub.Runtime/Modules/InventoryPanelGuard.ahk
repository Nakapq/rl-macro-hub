class InventoryPanelGuard {
    static BoundsRefreshIntervalMs := 100

    __New(state, configuration, context) {
        this.State := state
        this.Configuration := configuration
        this.Context := context
        this.CursorPoint := Buffer(8, 0)
        this.LastBoundsRefreshTick := -InventoryPanelGuard.BoundsRefreshIntervalMs
        this.BoundsValid := false
        this.Left := 0
        this.Top := 0
        this.Right := 0
        this.Bottom := 0
    }

    IsPointerBlocked() {
        if !this.Configuration.SuppressAutoclicks || !this.State.InventoryOpen
            return false

        if !this.TryGetScreenBounds(&left, &top, &right, &bottom)
            return false
        if !DllCall("GetCursorPos", "Ptr", this.CursorPoint, "Int")
            return false

        cursorX := NumGet(this.CursorPoint, 0, "Int")
        cursorY := NumGet(this.CursorPoint, 4, "Int")
        return cursorX >= left && cursorX <= right
            && cursorY >= top && cursorY <= bottom
    }

    TryGetScreenBounds(&left, &top, &right, &bottom) {
        left := 0
        top := 0
        right := 0
        bottom := 0
        if !this.RefreshBounds(A_TickCount)
            return false

        left := this.Left
        top := this.Top
        right := this.Right
        bottom := this.Bottom
        return true
    }

    RefreshBounds(nowTick) {
        if nowTick - this.LastBoundsRefreshTick < InventoryPanelGuard.BoundsRefreshIntervalMs
            return this.BoundsValid

        this.LastBoundsRefreshTick := nowTick
        if !this.Context.TryGetClientBounds(&clientX, &clientY, &clientWidth, &clientHeight) {
            this.BoundsValid := false
            return false
        }

        this.Left := clientX + Round(clientWidth * this.Configuration.NormalizedLeft)
        this.Top := clientY + Round(clientHeight * this.Configuration.NormalizedTop)
        this.Right := clientX + Round(clientWidth * this.Configuration.NormalizedRight)
        this.Bottom := clientY + Round(clientHeight * this.Configuration.NormalizedBottom)
        this.BoundsValid := true
        return true
    }

    static ContainsNormalizedPoint(configuration, x, y) {
        return x >= configuration.NormalizedLeft && x <= configuration.NormalizedRight
            && y >= configuration.NormalizedTop && y <= configuration.NormalizedBottom
    }
}
