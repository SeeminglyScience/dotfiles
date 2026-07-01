settings:useLf():loadOperatingSystemLib():loadBasicLib()

Defaults = loadConfig('./settings.ac.yaml', loadConfigSettings('utf8'))

function WTConfig()
    copyKeys(
        Defaults,
        current,
        { keysToExclude = { "profiles", "keybindings" } })

    ensureObjPath(current, "profiles.defaults")

    local currentProfileDefaults = current.profiles.defaults
    copyKeys(Defaults.profiles.defaults, currentProfileDefaults)

    -- Make a map of keybindings so we can easily check what should be added
    -- or removed.
    local defaultsBinds = toDict(
        Defaults.keybindings,
        function(_, value) return value.id..value.keys end,
        function(key, _) return key end)

    local currentBinds = toDict(
        current.keybindings,
        function(_, value) return value.id..value.keys end,
        function(key, _) return key end)

    -- Touch up keybinds manually, adding/removing based on what is in defaults.
    -- Doing it this way so that order is ignored.
    local offset = 0
    for key, value in pairs(currentBinds) do
        if not containsKey(defaultsBinds, key) then
            removeAt(current.keybindings, value - offset)
            offset = offset + 1
        end
    end

    for key, value in pairs(defaultsBinds) do
        if not containsKey(currentBinds, key) then
            addItem(current.keybindings, Defaults.keybindings[value])
        end
    end

    local defaultMap = toDict(Defaults.profiles.list, "guid")
    local currentMap = toDict(current.profiles.list, "guid")

    local resultProfiles = newArray()

    for guid, profile in pairs(defaultMap) do
        if profile.name == "PowerShell Dev" then
            local pwshStore = os.getenv("PWSH_STORE") or "C:\\pwsh"
            profile.commandline = joinPath(pwshStore, "dev", "pwsh.exe")
        end

        if not containsKey(currentMap, guid) then
            addItem(resultProfiles, profile)
            goto continue
        end

        copyKeys(profile, currentMap[guid])
        addItem(resultProfiles, currentMap[guid])
        removeKey(currentMap, guid)
        ::continue::
    end

    for _, value in pairs(currentMap) do
        -- Everything remaining in currentMap is not in our defaults. If it's
        -- removed then it'll usually reappear, so hide it instead.
        value.hidden = true
        addItem(resultProfiles, value)
    end

    current.profiles.list = resultProfiles
end

return WTConfig