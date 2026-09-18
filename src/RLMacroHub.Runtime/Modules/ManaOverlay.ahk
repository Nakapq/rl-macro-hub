class ManaOverlay {
    static SourceWidth := 1920
    static SourceHeight := 1080

    __New(configuration, context, logger, imagePath) {
        this.Configuration := configuration
        this.Context := context
        this.Logger := logger
        this.ImagePath := imagePath
        this.Window := ""
        this.GdiToken := 0
        this.SourceBitmap := 0
        this.MemoryDc := 0
        this.SurfaceBitmap := 0
        this.PreviousBitmap := 0
        this.SurfaceWidth := 0
        this.SurfaceHeight := 0
    }

    Create() {
        if !this.Configuration.Enabled
            return

        if !FileExist(this.ImagePath) {
            this.Logger.Error("Mana overlay image was not found: " this.ImagePath)
            return
        }

        try {
            this.StartGdiPlus()
            status := DllCall(
                "gdiplus\GdipCreateBitmapFromFile",
                "WStr", this.ImagePath,
                "Ptr*", &sourceBitmap := 0,
                "UInt")
            if status != 0 || !sourceBitmap
                throw Error("GDI+ could not load the mana overlay PNG (status " status ").")

            this.SourceBitmap := sourceBitmap
            this.Window := Gui(
                "+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000 +E0x00080000 -DPIScale",
                "RL Macro Hub Mana Overlay")
            this.Window.OnEvent("Close", (*) => this.Window.Hide())
            this.Tick()
        } catch as error {
            this.Logger.Error("Mana overlay creation failed: " error.Message)
            this.ReleaseGraphics()
            if IsObject(this.Window)
                this.Window.Destroy()
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

        if !this.Context.TryGetClientBounds(&clientX, &clientY, &clientWidth, &clientHeight) {
            this.Window.Hide()
            return
        }

        bounds := ManaOverlay.CalculateBounds(
            this.Configuration,
            clientX,
            clientY,
            clientWidth,
            clientHeight)

        try {
            this.EnsureSurface(bounds.Width, bounds.Height)
            this.UpdateLayeredWindow(bounds)
        } catch as error {
            this.Window.Hide()
            this.Logger.Error("Mana overlay update failed: " error.Message)
        }
    }

    static CalculateBounds(configuration, clientX, clientY, clientWidth, clientHeight) {
        return {
            X: clientX + Round(clientWidth * configuration.NormalizedX),
            Y: clientY + Round(clientHeight * configuration.NormalizedY),
            Width: Max(1, Round(clientWidth * configuration.Scale)),
            Height: Max(1, Round(clientHeight * configuration.Scale))
        }
    }

    StartGdiPlus() {
        startupInput := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
        NumPut("UInt", 1, startupInput, 0)
        status := DllCall(
            "gdiplus\GdiplusStartup",
            "UPtr*", &token := 0,
            "Ptr", startupInput.Ptr,
            "Ptr", 0,
            "UInt")
        if status != 0 || !token
            throw Error("GDI+ startup failed (status " status ").")
        this.GdiToken := token
    }

    EnsureSurface(width, height) {
        if this.MemoryDc && width = this.SurfaceWidth && height = this.SurfaceHeight
            return

        this.ReleaseSurface()
        screenDc := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
        if !screenDc
            throw Error("Could not acquire the desktop device context.")

        try {
            this.MemoryDc := DllCall("gdi32\CreateCompatibleDC", "Ptr", screenDc, "Ptr")
            if !this.MemoryDc
                throw Error("Could not create the mana overlay device context.")

            bitmapInfo := Buffer(40, 0)
            NumPut("UInt", 40, bitmapInfo, 0)
            NumPut("Int", width, bitmapInfo, 4)
            NumPut("Int", -height, bitmapInfo, 8)
            NumPut("UShort", 1, bitmapInfo, 12)
            NumPut("UShort", 32, bitmapInfo, 14)
            this.SurfaceBitmap := DllCall(
                "gdi32\CreateDIBSection",
                "Ptr", screenDc,
                "Ptr", bitmapInfo.Ptr,
                "UInt", 0,
                "Ptr*", &bits := 0,
                "Ptr", 0,
                "UInt", 0,
                "Ptr")
            if !this.SurfaceBitmap
                throw Error("Could not create the mana overlay bitmap surface.")

            this.PreviousBitmap := DllCall(
                "gdi32\SelectObject",
                "Ptr", this.MemoryDc,
                "Ptr", this.SurfaceBitmap,
                "Ptr")

            status := DllCall(
                "gdiplus\GdipCreateFromHDC",
                "Ptr", this.MemoryDc,
                "Ptr*", &graphics := 0,
                "UInt")
            if status != 0 || !graphics
                throw Error("Could not create the mana overlay graphics surface (status " status ").")

            try {
                DllCall("gdiplus\GdipSetCompositingMode", "Ptr", graphics, "Int", 1)
                DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", graphics, "Int", 7)
                DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", graphics, "Int", 4)
                DllCall("gdiplus\GdipGraphicsClear", "Ptr", graphics, "UInt", 0x00000000)
                status := DllCall(
                    "gdiplus\GdipDrawImageRectI",
                    "Ptr", graphics,
                    "Ptr", this.SourceBitmap,
                    "Int", 0,
                    "Int", 0,
                    "Int", width,
                    "Int", height,
                    "UInt")
                if status != 0
                    throw Error("Could not draw the mana overlay PNG (status " status ").")
            } finally {
                DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
            }

            this.SurfaceWidth := width
            this.SurfaceHeight := height
        } catch {
            this.ReleaseSurface()
            throw
        } finally {
            DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDc)
        }
    }

    UpdateLayeredWindow(bounds) {
        destination := Buffer(8, 0)
        NumPut("Int", bounds.X, destination, 0)
        NumPut("Int", bounds.Y, destination, 4)
        dimensions := Buffer(8, 0)
        NumPut("Int", bounds.Width, dimensions, 0)
        NumPut("Int", bounds.Height, dimensions, 4)
        source := Buffer(8, 0)
        blend := Buffer(4, 0)
        NumPut("UChar", Round(255 * this.Configuration.Opacity), blend, 2)
        NumPut("UChar", 1, blend, 3)

        screenDc := DllCall("user32\GetDC", "Ptr", 0, "Ptr")
        if !screenDc
            throw Error("Could not acquire the desktop device context.")

        try {
            updated := DllCall(
                "user32\UpdateLayeredWindow",
                "Ptr", this.Window.Hwnd,
                "Ptr", screenDc,
                "Ptr", destination.Ptr,
                "Ptr", dimensions.Ptr,
                "Ptr", this.MemoryDc,
                "Ptr", source.Ptr,
                "UInt", 0,
                "Ptr", blend.Ptr,
                "UInt", 2,
                "Int")
            if !updated
                throw Error("UpdateLayeredWindow failed (Win32 error " A_LastError ").")
        } finally {
            DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", screenDc)
        }

        DllCall("user32\ShowWindow", "Ptr", this.Window.Hwnd, "Int", 8)
    }

    ReleaseSurface() {
        if this.MemoryDc && this.PreviousBitmap
            DllCall("gdi32\SelectObject", "Ptr", this.MemoryDc, "Ptr", this.PreviousBitmap)
        if this.SurfaceBitmap
            DllCall("gdi32\DeleteObject", "Ptr", this.SurfaceBitmap)
        if this.MemoryDc
            DllCall("gdi32\DeleteDC", "Ptr", this.MemoryDc)
        this.MemoryDc := 0
        this.SurfaceBitmap := 0
        this.PreviousBitmap := 0
        this.SurfaceWidth := 0
        this.SurfaceHeight := 0
    }

    ReleaseGraphics() {
        this.ReleaseSurface()
        if this.SourceBitmap
            DllCall("gdiplus\GdipDisposeImage", "Ptr", this.SourceBitmap)
        this.SourceBitmap := 0
        ; AutoHotkey also uses GDI+ internally. Releasing our image and GDI
        ; surfaces is safe, but shutting down GDI+ before the interpreter has
        ; destroyed its own GUI resources can fault. The process owns this one
        ; startup token for its remaining lifetime and Windows reclaims it.
        this.GdiToken := 0
    }

    Destroy() {
        if IsObject(this.Window) {
            this.Window.Hide()
            this.ReleaseGraphics()
            this.Window.Destroy()
            this.Window := ""
            return
        }
        this.ReleaseGraphics()
    }
}
