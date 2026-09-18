class RuntimeLogger {
    __New(path) {
        this.Path := path
    }

    Info(message) => this.Write("INFO", message)
    Warn(message) => this.Write("WARN", message)
    Error(message) => this.Write("ERROR", message)

    Write(level, message) {
        try FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " [" level "] " message "`n", this.Path, "UTF-8")
    }
}
