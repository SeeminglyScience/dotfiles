function GetSingleton {
    if ($script:PSReadLineSingleton) {
        return $script:PSReadLineSingleton
    }

    return $script:PSReadLineSingleton =
        [Microsoft.PowerShell.PSConsoleReadLine].
            GetField('_singleton', 60).
            GetValue($null)
}
