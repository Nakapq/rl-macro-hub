class InventoryPanelOverlay {
    static BorderThickness := 2
    static TransparentColor := "010101"
    static BorderColor := "00E5FF"

    __New(configuration, context, guard, logger) {
        this.Configuration := configuration
        this.Context := context
        this.Guard := guard
        this.Logger := logger
        this.Window := ""
        this.TopBorder := ""
        this.RightBorder := ""
        this.BottomBorder := ""
        this.LeftBorder := ""
    }

    Create() {
        if !this.Configuration.ShowBorder
            return

        try {
            this.Window := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000 -DPIScale", "RL Macro Hub Inventory Region")
            this.Window.MarginX := 0
            this.Window.MarginY := 0
            this.Window.BackColor := InventoryPanelOverlay.TransparentColor
            colorOptions := "Background" InventoryPanelOverlay.BorderColor " c" InventoryPanelOverlay.BorderColor " Range0-100"
            this.TopBorder := this.Window.AddProgress("x0 y0 w1 h2 " colorOptions, 100)
            this.RightBorder := this.Window.AddProgress("x0 y0 w2 h1 " colorOptions, 100)
            this.BottomBorder := this.Window.AddProgress("x0 y0 w1 h2 " colorOptions, 100)
            this.LeftBorder := this.Window.AddProgress("x0 y0 w2 h1 " colorOptions, 100)
            this.Window.Show("Hide w1 h1 NoActivate")
            WinSetTransColor InventoryPanelOverlay.TransparentColor, "ahk_id " this.Window.Hwnd
            this.Tick()
        } catch as error {
            this.Logger.Error("Inventory exclusion border creation failed: " error.Message)
            this.Window := ""
        }
    }

    Tick(*) {
        if !IsObject(this.Window)
            return

        if !this.Context.IsActive() || this.Context.IsMinimized() {
            this.Window.Hide()
            return
        }

        if !this.Guard.TryGetScreenBounds(&left, &top, &right, &bottom) {
            this.Window.Hide()
            return
        }

        width := Max(4, right - left)
        height := Max(4, bottom - top)
        thickness := InventoryPanelOverlay.BorderThickness
        this.TopBorder.Move(0, 0, width, thickness)
        this.RightBorder.Move(width - thickness, 0, thickness, height)
        this.BottomBorder.Move(0, height - thickness, width, thickness)
        this.LeftBorder.Move(0, 0, thickness, height)
        this.Window.Show("x" left " y" top " w" width " h" height " NoActivate")
    }

    Destroy() {
        if IsObject(this.Window) {
            this.Window.Destroy()
            this.Window := ""
        }
    }
}
