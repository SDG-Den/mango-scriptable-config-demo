$ErrorActionPreference = "Stop"
. "$env:MANGO_LIB/mango.ps1"

$ok = $false
for ($i = 0; $i -lt 50; $i++) {
    try {
        Get-Mango "version" | Out-Null
        $ok = $true
        break
    } catch { Start-Sleep -Milliseconds 100 }
}
if (-not $ok) { Write-Error "mango not reachable"; exit 1 }

Write-Output ("version: " + (Get-MangoVersion))
Set-MangoOption "borderpx" "0"
Set-MangoOption "gappih" "4"
Set-MangoOption "rootcolor" "1d1d2b"
Set-MangoOption "animations" "off"
Set-MangoOption "bind" "alt,Return,spawn_shell,foot"
Invoke-MangoDispatch "setlayout" @("tile")
Write-Output ("binds: " + @((Get-MangoBinds)).Count)
Write-Output ("monitors: " + @((Get-MangoMonitors)).Count)
Get-MangoWatchFrame "all-clients" | Out-Null
Write-Output "config done"