class GateMacroModule {
    static InputResetIntervalMs := 5000

    __New(state, configuration, context, logger) {
        this.State := state
        this.Configuration := configuration
        this.Context := context
        this.Logger := logger
        this.Observer := ""
        this.CaptureActive := false
        this.InputBuffer := ""
        this.LastInputTick := 0
        this.Disposed := false
        this.ObserverEndedCallback := ObjBindMethod(this, "OnObserverEnded")
        this.ObserverCharCallback := ObjBindMethod(this, "OnObserverChar")
        this.ObserverKeyDownCallback := ObjBindMethod(this, "OnObserverKeyDown")
    }

    Start() {
        this.Disposed := false
        this.Tick()
    }

    Tick() {
        shouldObserve := this.CaptureActive
            && !this.Disposed
            && this.Configuration.Enabled
            && this.Configuration.Mappings.Count > 0
            && this.State.TypingPaused
            && this.Context.IsActive()
        if shouldObserve {
            if !IsObject(this.Observer) || !this.Observer.InProgress
                this.StartObserver()
            return
        }

        if this.CaptureActive
            this.CancelCapture()
        else
            this.StopObserver()
    }

    BeginChatCapture() {
        this.CancelCapture()
        if this.Disposed
            || !this.Configuration.Enabled
            || this.Configuration.Mappings.Count = 0
            || !this.State.TypingPaused
            || !this.Context.IsActive()
            return false

        this.CaptureActive := true
        this.StartObserver()
        return this.CaptureActive
    }

    StartObserver() {
        try {
            ; Bound keys are passed through with SendEvent while chat is active.
            ; Observe level-zero input so those characters remain part of a notation;
            ; RemapBusy keeps actual remap output and our replacement text excluded.
            observer := InputHook("V")
            observer.OnEnd := this.ObserverEndedCallback
            observer.OnChar := this.ObserverCharCallback
            observer.OnKeyDown := this.ObserverKeyDownCallback
            observer.KeyOpt("{Backspace}", "N")
            this.Observer := observer
            observer.Start()
        } catch as error {
            this.Observer := ""
            this.CaptureActive := false
            this.ResetInput()
            this.Logger.Error("Gate notation observer could not start: " error.Message)
        }
    }

    StopObserver() {
        observer := this.Observer
        this.Observer := ""
        this.ResetInput()
        if IsObject(observer) && observer.InProgress
            try observer.Stop()
    }

    OnObserverEnded(observer) {
        if this.Observer = observer {
            this.Observer := ""
            this.CaptureActive := false
            this.ResetInput()
        }
    }

    OnObserverChar(observer, characters) {
        _ := observer
        if !this.CaptureActive
            || !this.State.TypingPaused
            || !this.Context.IsActive()
            || this.State.RemapBusy
            return

        if this.LastInputTick = 0 || A_TickCount - this.LastInputTick > GateMacroModule.InputResetIntervalMs
            this.InputBuffer := ""
        this.LastInputTick := A_TickCount

        loop parse characters {
            character := A_LoopField
            if RegExMatch(character, "^[A-Za-z0-9_-]$") {
                this.InputBuffer .= StrLower(character)
                if StrLen(this.InputBuffer) > RuntimeConfiguration.MaximumGateNotationLength
                    this.InputBuffer := SubStr(this.InputBuffer, -RuntimeConfiguration.MaximumGateNotationLength)
            } else {
                this.InputBuffer := ""
            }
        }
    }

    OnObserverKeyDown(observer, virtualKey, scanCode) {
        _ := observer
        _ := scanCode
        if virtualKey != 8
            || !this.CaptureActive
            || !this.State.TypingPaused
            || !this.Context.IsActive()
            || this.State.RemapBusy
            return

        length := StrLen(this.InputBuffer)
        this.InputBuffer := length > 0 ? SubStr(this.InputBuffer, 1, length - 1) : ""
        this.LastInputTick := A_TickCount
    }

    SubmitCapture() {
        captureWasActive := this.CaptureActive
        notation := this.InputBuffer
        inputExpired := this.LastInputTick = 0
            || A_TickCount - this.LastInputTick > GateMacroModule.InputResetIntervalMs
        this.CancelCapture()
        if !captureWasActive
            || !this.State.TypingPaused
            || !this.Configuration.Enabled
            || !this.Context.IsActive()
            || inputExpired
            || notation = ""
            return false

        location := GateMacroModule.ResolveLocation(this.Configuration, notation)
        if location = ""
            return false

        this.ReplaceVisibleText(location)
        this.Logger.Info("Expanded gate notation '" notation "' on submit.")
        return true
    }

    ResetInput() {
        this.InputBuffer := ""
        this.LastInputTick := 0
    }

    CancelCapture() {
        this.CaptureActive := false
        this.StopObserver()
    }

    ReplaceVisibleText(location) {
        clipboardBackup := ""
        hasClipboardBackup := false
        canPaste := false
        this.State.RemapBusy := true
        try {
            try {
                clipboardBackup := ClipboardAll()
                hasClipboardBackup := true
                A_Clipboard := location
                canPaste := true
            } catch as error {
                this.Logger.Warn("Clipboard was unavailable; using text input. " error.Message)
            }

            SendEvent "{Ctrl down}a{Ctrl up}"
            Sleep 10
            SendEvent "{Backspace}"
            Sleep 10
            if canPaste {
                SendEvent "{Ctrl down}v{Ctrl up}"
                ; Give Roblox time to consume the paste before restoring the clipboard.
                Sleep 40
            } else {
                SendText location
            }
        } catch as error {
            this.Logger.Error("Gate notation expansion failed: " error.Message)
        } finally {
            if hasClipboardBackup
                try A_Clipboard := clipboardBackup
            this.State.RemapBusy := false
        }
    }

    Dispose() {
        this.Disposed := true
        this.CancelCapture()
    }

    static ResolveLocation(configuration, notation) =>
        configuration.Mappings.Get(notation, "")
}
