settings:
    useLf():
    loadOperatingSystemLib():
    compressed()

Defaults = loadConfig('./settings.ac.yaml', loadConfigSettings('utf8'))

function PowerToysConfig()
    copyKeys(
        Defaults,
        current,
        { keysToExclude = { "powertoys_version", "enabled" } })

    ensureObjPath(current, "enabled")
    copyKeys(Defaults.enabled, current.enabled)
end

return PowerToysConfig