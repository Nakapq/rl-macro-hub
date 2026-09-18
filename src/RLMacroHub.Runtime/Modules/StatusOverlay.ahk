class StatusOverlay {
    __New(state, configuration, context, logger) {
        this.State := state
        this.Configuration := configuration
        this.Context := context
        this.Logger := logger
        this.Window := ""
        this.StatusControl := ""
        this.CpsControl := ""
    }

    Create() {
        if !this.Configuration.Enabled || !this.Configuration.ShowAutoclickerStatus
            return

        options := "+AlwaysOnTop -Caption +ToolWindow"
        if this.Configuration.ClickThrough
            options .= " +E0x20"

        try {
            innerWidth := Max(38, this.Configuration.Width - 2)
            labelWidth := Max(26, Floor(innerWidth * 0.55))
            statusX := 4 + labelWidth
            statusWidth := Max(18, innerWidth - labelWidth - 5)
            cpsWidth := Max(34, this.Configuration.Width - 6)
            this.Window := Gui(options, "RL Macro Hub Runtime")
            this.Window.MarginX := 0
            this.Window.MarginY := 0
            this.Window.BackColor := "4B2F1C"
            this.Window.AddProgress("x1 y1 w" innerWidth " h18 BackgroundD9B783 cD9B783 Range0-100", 100)
            this.Window.AddProgress("x1 y20 w" innerWidth " h18 BackgroundCBA873 cCBA873 Range0-100", 100)
            this.Window.SetFont("s8 Bold c3E2818", "Garamond")
            this.Window.AddText("x4 y1 w" labelWidth " h18 +0x200 +BackgroundTrans", "Auto")
            this.Window.SetFont("s8 Bold c8A2D24", "Garamond")
            this.StatusControl := this.Window.AddText("x" statusX " y1 w" statusWidth " h18 Right +0x200 +BackgroundTrans", "OFF")
            this.Window.SetFont("s7 Bold c4A321F", "Garamond")
            this.CpsControl := this.Window.AddText("x3 y20 w" cpsWidth " h18 Center +0x200 +BackgroundTrans", "CPS: 0")
            this.Window.OnEvent("Close", (*) => this.Window.Hide())
            this.Window.Show("Hide w" this.Configuration.Width " h" this.Configuration.Height " NoActivate")
            this.Tick()
        } catch as error {
            this.Logger.Error("Status overlay creation failed: " error.Message)
            this.Window := ""
        }
    }

    Tick(*) {
        if !IsObject(this.Window)
            return

        this.UpdateStatus()
        this.Position()
    }

    UpdateStatus() {
        if !this.State.Enabled {
            this.StatusControl.SetFont("s8 Bold c8A2D24", "Garamond")
            this.StatusControl.Text := "OFF"
        } else if !this.State.AbilityAutoclickEnabled {
            this.StatusControl.SetFont("s6 Bold c8A5A20", "Garamond")
            this.StatusControl.Text := "HOLD"
        } else {
            this.StatusControl.SetFont("s8 Bold c3F6B3A", "Garamond")
            this.StatusControl.Text := "ON"
        }
        this.CpsControl.Text := "CPS: " this.State.CurrentCps
    }

    Position() {
        if !this.Context.IsActive() || this.Context.IsMinimized() {
            this.Window.Hide()
            return
        }

        if !this.Context.TryGetBounds(&x, &y, &width, &height)
            return

        statusX := x + width - this.Configuration.RightOffset
        statusY := y + this.Configuration.TopOffset
        this.Window.Show(
            "x" statusX " y" statusY
            " w" this.Configuration.Width " h" this.Configuration.Height
            " NoActivate")
    }

    Destroy() {
        if IsObject(this.Window) {
            this.Window.Destroy()
            this.Window := ""
        }
    }
}
