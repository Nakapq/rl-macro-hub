using Microsoft.Extensions.Logging.Abstractions;
using RLMacroHub.Core.Models;
using RLMacroHub.Infrastructure.Configuration;
using RLMacroHub.Infrastructure.Profiles;
using System.Text.Json;

namespace RLMacroHub.Tests;

public sealed class ProfileServiceTests
{
    [Fact]
    public async Task ProfilesCanBeCreatedRenamedSelectedAndDeleted()
    {
        using TemporaryDirectory temporary = new();
        AppPaths paths = new(temporary.Path);
        using JsonSettingsService settings = new(paths, NullLogger<JsonSettingsService>.Instance);
        await settings.LoadAsync();
        ProfileService service = new(paths, settings, NullLogger<ProfileService>.Instance);

        IReadOnlyList<ProfileConfiguration> initial = await service.GetProfilesAsync();
        ProfileConfiguration created = await service.CreateAsync("Dungeon");
        await service.RenameAsync(created.Id, "Dungeon PvP");
        await service.SelectAsync(created.Id);

        IReadOnlyList<ProfileConfiguration> updated = await service.GetProfilesAsync();
        Assert.Single(initial);
        Assert.Equal("Dungeon PvP", updated.Single(profile => profile.Id == created.Id).Name);
        Assert.Equal(created.Id, settings.Current.General.ActiveProfileId);

        await service.DeleteAsync(created.Id);
        Assert.Single(await service.GetProfilesAsync());
        Assert.Equal("default", settings.Current.General.ActiveProfileId);
    }

    [Fact]
    public async Task DefaultProfileCannotBeDeleted()
    {
        using TemporaryDirectory temporary = new();
        AppPaths paths = new(temporary.Path);
        using JsonSettingsService settings = new(paths, NullLogger<JsonSettingsService>.Instance);
        await settings.LoadAsync();
        ProfileService service = new(paths, settings, NullLogger<ProfileService>.Instance);
        _ = await service.GetProfilesAsync();

        await Assert.ThrowsAsync<InvalidOperationException>(() => service.DeleteAsync("default"));
    }

    [Fact]
    public async Task AbilitySlotNamesAndPoliciesAreSavedToTheActiveProfile()
    {
        using TemporaryDirectory temporary = new();
        AppPaths paths = new(temporary.Path);
        using JsonSettingsService settings = new(paths, NullLogger<JsonSettingsService>.Instance);
        await settings.LoadAsync();
        ProfileService service = new(paths, settings, NullLogger<ProfileService>.Instance);
        _ = await service.GetProfilesAsync();
        AbilitySlotConfiguration slot = settings.Current.Autoclicker.AbilitySlots.Single(candidate => candidate.Slot == "=");
        slot.Name = "Gate";
        slot.AutoclickerEnabled = false;
        await settings.SaveAsync(settings.Current);

        await service.SaveActiveSettingsAsync();

        ProfileConfiguration active = (await service.GetProfilesAsync()).Single(profile => profile.Id == "default");
        AbilitySlotConfiguration savedSlot = active.Settings.Autoclicker.AbilitySlots.Single(candidate => candidate.Slot == "=");
        Assert.Equal("Gate", savedSlot.Name);
        Assert.False(savedSlot.AutoclickerEnabled);
    }

    [Fact]
    public async Task SwitchingProfilesPersistsMacroSettingsAndPreservesGlobalSettings()
    {
        using TemporaryDirectory temporary = new();
        AppPaths paths = new(temporary.Path);
        using JsonSettingsService settings = new(paths, NullLogger<JsonSettingsService>.Instance);
        await settings.LoadAsync();
        using ProfileService service = new(paths, settings, NullLogger<ProfileService>.Instance);
        _ = await service.GetProfilesAsync();

        settings.Current.General.AutoHotkeyExecutablePath = @"C:\Tools\AutoHotkey64.exe";
        settings.Current.Autoclicker.MaximumCps = 90;
        settings.Current.Keybinds.Bindings = [new KeyBinding("q", "1")];
        settings.Current.GateMacro.Enabled = true;
        settings.Current.GateMacro.Mappings = [new GateLocationMapping("d5", "desert 5")];
        settings.Current.Overlay.ClickThrough = true;
        await settings.SaveAsync(settings.Current);
        await service.SaveActiveSettingsAsync();

        ProfileConfiguration alternate = await service.CreateAsync("Alternate");
        await service.SelectAsync(alternate.Id);
        settings.Current.General.AutoHotkeyExecutablePath = @"D:\AHK\AutoHotkey64.exe";
        settings.Current.Autoclicker.MaximumCps = 45;
        settings.Current.Keybinds.Bindings = [new KeyBinding("e", "2")];
        settings.Current.GateMacro.Enabled = false;
        settings.Current.GateMacro.Mappings = [new GateLocationMapping("c2", "castle 2")];
        settings.Current.Overlay.ClickThrough = false;
        await settings.SaveAsync(settings.Current);
        await service.SaveActiveSettingsAsync();

        await service.SelectAsync("default");
        Assert.Equal(90, settings.Current.Autoclicker.MaximumCps);
        Assert.Equal("q", Assert.Single(settings.Current.Keybinds.Bindings).Source);
        Assert.True(settings.Current.Overlay.ClickThrough);
        Assert.True(settings.Current.GateMacro.Enabled);
        Assert.Equal("d5", Assert.Single(settings.Current.GateMacro.Mappings).Notation);
        Assert.Equal(@"D:\AHK\AutoHotkey64.exe", settings.Current.General.AutoHotkeyExecutablePath);

        await service.SelectAsync(alternate.Id);
        Assert.Equal(45, settings.Current.Autoclicker.MaximumCps);
        Assert.Equal("e", Assert.Single(settings.Current.Keybinds.Bindings).Source);
        Assert.False(settings.Current.Overlay.ClickThrough);
        Assert.False(settings.Current.GateMacro.Enabled);
        Assert.Equal("c2", Assert.Single(settings.Current.GateMacro.Mappings).Notation);
        Assert.Equal(@"D:\AHK\AutoHotkey64.exe", settings.Current.General.AutoHotkeyExecutablePath);
    }

    [Fact]
    public async Task DeletingActiveProfileLoadsDefaultProfileSettings()
    {
        using TemporaryDirectory temporary = new();
        AppPaths paths = new(temporary.Path);
        using JsonSettingsService settings = new(paths, NullLogger<JsonSettingsService>.Instance);
        await settings.LoadAsync();
        using ProfileService service = new(paths, settings, NullLogger<ProfileService>.Instance);
        _ = await service.GetProfilesAsync();

        settings.Current.Autoclicker.MaximumCps = 88;
        await settings.SaveAsync(settings.Current);
        await service.SaveActiveSettingsAsync();
        ProfileConfiguration alternate = await service.CreateAsync("Temporary");
        await service.SelectAsync(alternate.Id);
        settings.Current.Autoclicker.MaximumCps = 33;
        await settings.SaveAsync(settings.Current);

        await service.DeleteAsync(alternate.Id);

        Assert.Equal("default", settings.Current.General.ActiveProfileId);
        Assert.Equal(88, settings.Current.Autoclicker.MaximumCps);
    }

    [Fact]
    public async Task MissingActiveProfileRecoversToDefault()
    {
        using TemporaryDirectory temporary = new();
        AppPaths paths = new(temporary.Path);
        using JsonSettingsService settings = new(paths, NullLogger<JsonSettingsService>.Instance);
        await settings.LoadAsync();
        using ProfileService service = new(paths, settings, NullLogger<ProfileService>.Instance);
        _ = await service.GetProfilesAsync();
        settings.Current.General.ActiveProfileId = "missing";
        await settings.SaveAsync(settings.Current);

        IReadOnlyList<ProfileConfiguration> profiles = await service.GetProfilesAsync();

        Assert.Single(profiles);
        Assert.Equal("default", settings.Current.General.ActiveProfileId);
    }

    [Fact]
    public async Task MalformedDefaultProfileIsPreservedAndRecreated()
    {
        using TemporaryDirectory temporary = new();
        AppPaths paths = new(temporary.Path);
        using JsonSettingsService settings = new(paths, NullLogger<JsonSettingsService>.Instance);
        await settings.LoadAsync();
        Directory.CreateDirectory(paths.ProfilesDirectory);
        string defaultPath = Path.Combine(paths.ProfilesDirectory, "default.json");
        await File.WriteAllTextAsync(defaultPath, "{not-json");
        using ProfileService service = new(paths, settings, NullLogger<ProfileService>.Instance);

        IReadOnlyList<ProfileConfiguration> profiles = await service.GetProfilesAsync();

        Assert.True(Assert.Single(profiles).IsDefault);
        Assert.True(File.Exists(defaultPath));
        Assert.Single(Directory.EnumerateFiles(paths.ProfilesDirectory, "default.json.corrupt.*"));
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public async Task ProfileNamesCannotBeBlank(string name)
    {
        using TemporaryDirectory temporary = new();
        AppPaths paths = new(temporary.Path);
        using JsonSettingsService settings = new(paths, NullLogger<JsonSettingsService>.Instance);
        await settings.LoadAsync();
        using ProfileService service = new(paths, settings, NullLogger<ProfileService>.Instance);

        await Assert.ThrowsAsync<ArgumentException>(() => service.CreateAsync(name));
    }

    [Fact]
    public async Task ProfileWithMismatchedStoredIdIsIgnored()
    {
        using TemporaryDirectory temporary = new();
        AppPaths paths = new(temporary.Path);
        using JsonSettingsService settings = new(paths, NullLogger<JsonSettingsService>.Instance);
        await settings.LoadAsync();
        paths.EnsureCreated();
        ProfileConfiguration mismatched = new() { Id = "different-id", Name = "Untrusted" };
        string mismatchedPath = Path.Combine(paths.ProfilesDirectory, "expected-id.json");
        await File.WriteAllTextAsync(mismatchedPath, JsonSerializer.Serialize(mismatched));
        using ProfileService service = new(paths, settings, NullLogger<ProfileService>.Instance);

        IReadOnlyList<ProfileConfiguration> profiles = await service.GetProfilesAsync();

        ProfileConfiguration profile = Assert.Single(profiles);
        Assert.Equal("default", profile.Id);
    }
}
