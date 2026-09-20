using System.Text.Json;
using Microsoft.Extensions.Logging;
using RLMacroHub.Core.Models;
using RLMacroHub.Core.Services;

namespace RLMacroHub.Infrastructure.Configuration;

public sealed class JsonSettingsService : ISettingsService, IDisposable
{
    private static readonly JsonSerializerOptions SerializerOptions = new(JsonSerializerDefaults.Web)
    {
        WriteIndented = true
    };

    private readonly AppPaths _paths;
    private readonly ILogger<JsonSettingsService> _logger;
    private readonly SemaphoreSlim _gate = new(1, 1);

    public JsonSettingsService(AppPaths paths, ILogger<JsonSettingsService> logger)
    {
        _paths = paths;
        _logger = logger;
    }

    public AppConfiguration Current { get; private set; } = AppConfiguration.CreateDefault();
    public event EventHandler<AppConfiguration>? SettingsChanged;

    public async Task<AppConfiguration> LoadAsync(CancellationToken cancellationToken = default)
    {
        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            _paths.EnsureCreated();
            if (!File.Exists(_paths.ConfigurationFile))
            {
                Current = AppConfiguration.CreateDefault();
                await WriteAtomicAsync(Current, cancellationToken).ConfigureAwait(false);
                return Current;
            }

            try
            {
                await using FileStream stream = File.OpenRead(_paths.ConfigurationFile);
                Current = await JsonSerializer.DeserializeAsync<AppConfiguration>(stream, SerializerOptions, cancellationToken)
                    .ConfigureAwait(false) ?? throw new JsonException("Configuration cannot be null.");
                Current.ValidateAndNormalize();
                return Current;
            }
            catch (Exception exception) when (exception is JsonException or IOException or UnauthorizedAccessException)
            {
                _logger.LogError(exception, "Configuration could not be loaded; preserving it and restoring defaults.");
                PreserveCorruptedConfiguration();
                Current = AppConfiguration.CreateDefault();
                await WriteAtomicAsync(Current, cancellationToken).ConfigureAwait(false);
                return Current;
            }
        }
        finally
        {
            _gate.Release();
        }
    }

    public async Task SaveAsync(AppConfiguration configuration, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(configuration);
        configuration.ValidateAndNormalize();

        await _gate.WaitAsync(cancellationToken).ConfigureAwait(false);
        try
        {
            _paths.EnsureCreated();
            await WriteAtomicAsync(configuration, cancellationToken).ConfigureAwait(false);
            Current = configuration;
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
            _logger.LogError(exception, "Configuration write failed.");
            throw;
        }
        finally
        {
            _gate.Release();
        }

        SettingsChanged?.Invoke(this, Current);
    }

    private async Task WriteAtomicAsync(AppConfiguration configuration, CancellationToken cancellationToken)
    {
        string temporaryPath = _paths.ConfigurationFile + ".tmp";
        await using (FileStream stream = new(
            temporaryPath,
            FileMode.Create,
            FileAccess.Write,
            FileShare.None,
            16 * 1024,
            FileOptions.Asynchronous | FileOptions.WriteThrough))
        {
            await JsonSerializer.SerializeAsync(stream, configuration, SerializerOptions, cancellationToken)
                .ConfigureAwait(false);
            await stream.FlushAsync(cancellationToken).ConfigureAwait(false);
        }

        File.Move(temporaryPath, _paths.ConfigurationFile, true);
    }

    private void PreserveCorruptedConfiguration()
    {
        try
        {
            string destination = Path.Combine(
                _paths.RootDirectory,
                $"config.corrupt.{DateTimeOffset.UtcNow:yyyyMMddHHmmssfff}.json");
            File.Move(_paths.ConfigurationFile, destination, true);
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
            _logger.LogWarning(exception, "The malformed configuration could not be preserved.");
        }
    }

    public void Dispose() => _gate.Dispose();
}
