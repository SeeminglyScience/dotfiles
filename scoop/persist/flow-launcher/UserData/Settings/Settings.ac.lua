settings:
    loadChezmoiConfig():
    loadBasicLib():
    withIndentSize(2):
    addFinalNewLine()

Defaults = loadConfig('./Settings.ac.yaml', loadConfigSettings('utf8'))

function FlowLauncherConfig()
    copyKeys(
        Defaults,
        current,
        {
            keysToExclude = {
                "CustomExplorerList",
                "CustomBrowserList",
                "Proxy",
                "PluginSettings",
                "WindowLeft",
                "WindowTop",
                "PreviousScreenWidth",
                "PreviousScreenHeight",
                "PreviousDpiX",
                "PreviousDpiY",
                "ActivateTimes",
            },
        })

    if chezmoi.data.work then
        current.CustomExplorerIndex = 0
        current.CustomBrowserIndex = 3
    else
        current.CustomExplorerIndex = 3
        current.CustomBrowserIndex = 5
    end

    for _, key in ipairs({ "CustomExplorerList", "CustomBrowserList" }) do
        local values = current[key] or {}
        updateEntries(Defaults[key], values, "Name")
        current[key] = values
    end

    ensureObjPath(current, "PluginSettings.Plugins")
    current.PluginSettings.PythonExecutablePath = joinPath(
        chezmoi.homeDir,
        "scoop", "apps", "python", "current", "python.exe")

    current.PluginSettings.NodeExecutablePath = joinPath(
        chezmoi.homeDir,
        "scoop", "apps", "nodejs", "current", "node.exe")

    local updateArgs = { keysToExclude = { "ID", "Name", "Version" }}

    local currentPlugins = current.PluginSettings.Plugins

    for key, value in pairs(Defaults.PluginSettings.Plugins) do
        local targetPlugin = currentPlugins[key]
        if targetPlugin == nil then
            currentPlugins[key] = value
            goto continue
        end

        copyKeys(value, targetPlugin, updateArgs)
        ::continue::
    end
end

return FlowLauncherConfig