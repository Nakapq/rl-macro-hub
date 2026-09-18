using Microsoft.Extensions.Logging;
using RLMacroHub.Infrastructure.Configuration;

namespace RLMacroHub.Infrastructure.Logging;

public sealed class FileLoggerProvider : ILoggerProvider
{
    private readonly object _sync = new();
    private readonly StreamWriter _writer;

    public FileLoggerProvider(AppPaths paths)
    {
        paths.EnsureCreated();
        string logFile = Path.Combine(paths.LogsDirectory, $"rl-macro-hub-{DateTimeOffset.Now:yyyyMMdd}.log");
        _writer = new StreamWriter(new FileStream(logFile, FileMode.Append, FileAccess.Write, FileShare.ReadWrite))
        {
            AutoFlush = true
        };
    }

    public ILogger CreateLogger(string categoryName) => new FileLogger(categoryName, this);

    internal void Write(string category, LogLevel level, EventId eventId, string message, Exception? exception)
    {
        lock (_sync)
        {
            _writer.Write(DateTimeOffset.Now.ToString("O", System.Globalization.CultureInfo.InvariantCulture));
            _writer.Write(" [");
            _writer.Write(level);
            _writer.Write("] ");
            _writer.Write(category);
            if (eventId.Id != 0)
            {
                _writer.Write(" (");
                _writer.Write(eventId.Id);
                _writer.Write(')');
            }

            _writer.Write(": ");
            _writer.WriteLine(message);
            if (exception is not null)
            {
                _writer.WriteLine(exception);
            }
        }
    }

    public void Dispose()
    {
        lock (_sync)
        {
            _writer.Dispose();
        }
    }

    private sealed class FileLogger(string category, FileLoggerProvider provider) : ILogger
    {
        public IDisposable? BeginScope<TState>(TState state) where TState : notnull => null;
        public bool IsEnabled(LogLevel logLevel) => logLevel >= LogLevel.Information;

        public void Log<TState>(
            LogLevel logLevel,
            EventId eventId,
            TState state,
            Exception? exception,
            Func<TState, Exception?, string> formatter)
        {
            if (IsEnabled(logLevel))
            {
                provider.Write(category, logLevel, eventId, formatter(state, exception), exception);
            }
        }
    }
}
