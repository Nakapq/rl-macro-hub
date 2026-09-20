class GateMacroModule {
    __New(state, configuration, context, logger) {
        this.State := state
        this.Configuration := configuration
        this.Context := context
        this.Logger := logger
        this.Capture := ""
        this.CaptureEndedCallback := ObjBindMethod(this, "OnCaptureEnded")
        this.MatchList := this.BuildMatchList(configuration.Mappings)
    }

    BeginChatCapture() {
        this.EndChatCapture()
        if !this.Configuration.Enabled || this.MatchList = "" || !this.Context.IsActive()
            return

        ; The slash observer runs on key-down. Waiting for release prevents the
        ; chat-opening slash itself from entering the capture buffer.
        KeyWait "/"
        if !this.State.TypingPaused || !this.Context.IsActive()
            return

        try {
            this.Capture := InputHook(
                "V I1 L" RuntimeConfiguration.MaximumGateNotationLength,
                "{Enter}{Esc}",
                this.MatchList)
            this.Capture.OnEnd := this.CaptureEndedCallback
            this.Capture.Start()
        } catch as error {
            this.Capture := ""
            this.Logger.Error("Gate notation capture could not start: " error.Message)
        }
    }

    EndChatCapture() {
        capture := this.Capture
        this.Capture := ""
        if IsObject(capture) && capture.InProgress {
            try capture.Stop()
        }
    }

    OnCaptureEnded(capture) {
        if this.Capture = capture
            this.Capture := ""
        if capture.EndReason != "Match" || !this.State.TypingPaused || !this.Context.IsActive()
            return

        location := GateMacroModule.ResolveLocation(this.Configuration, capture.Match)
        if location = ""
            return

        this.State.RemapBusy := true
        try {
            SendEvent "{Ctrl down}a{Ctrl up}"
            Sleep 10
            SendEvent "{Backspace}"
            Sleep 10
            SendText location
            this.Logger.Info("Expanded gate notation '" capture.Match "'.")
        } catch as error {
            this.Logger.Error("Gate notation expansion failed: " error.Message)
        } finally {
            this.State.RemapBusy := false
        }
    }

    Dispose() => this.EndChatCapture()

    BuildMatchList(mappings) {
        matchList := ""
        for notation, location in mappings {
            _ := location
            matchList .= (matchList = "" ? "" : ",") notation
        }
        return matchList
    }

    static ResolveLocation(configuration, notation) =>
        configuration.Mappings.Get(notation, "")
}
