function Get-MangoSocketPath {
    $path = $env:MANGO_INSTANCE_SIGNATURE
    if (-not $path) { throw "MANGO_INSTANCE_SIGNATURE is not set" }
    return $path
}

function New-MangoConnection {
    $socket = [System.Net.Sockets.Socket]::new(
        [System.Net.Sockets.AddressFamily]::Unix,
        [System.Net.Sockets.SocketType]::Stream,
        [System.Net.Sockets.ProtocolType]::Unspecified)
    $endpoint = [System.Net.Sockets.UnixDomainSocketEndPoint]::new((Get-MangoSocketPath))
    $socket.Connect($endpoint)
    return [pscustomobject]@{
        Socket = $socket
        Stream = [System.Net.Sockets.NetworkStream]::new($socket, $false)
    }
}

function Invoke-MangoCall([string]$Command) {
    $conn = New-MangoConnection
    try {
        $writer = [System.IO.StreamWriter]::new($conn.Stream)
        $writer.AutoFlush = $true
        $writer.WriteLine($Command)
        $reader = [System.IO.StreamReader]::new($conn.Stream)
        $line = $reader.ReadLine()
        if ($null -eq $line) { throw "connection closed without reply: $Command" }
        $reply = $line | ConvertFrom-Json
        if ($reply.error) { throw $reply.error }
        return $reply
    } finally {
        $conn.Stream.Dispose()
        $conn.Socket.Close()
    }
}

function Invoke-MangoRetry([string]$Command, [int]$Attempts = 50, [double]$Delay = 0.1) {
    for ($i = 0; $i -lt $Attempts; $i++) {
        try { return (Invoke-MangoCall $Command) }
        catch { Start-Sleep -Milliseconds ([int]($Delay * 1000)) }
    }
    throw "mango not reachable after $Attempts attempts: $Command"
}

function Get-Mango([string]$Spec) {
    return (Invoke-MangoCall ("get " + $Spec))
}

function Set-MangoOption([string]$Key, [string]$Value) {
    return (Invoke-MangoCall ("setoption " + $Key + " " + $Value))
}

function Invoke-MangoDispatch([string]$Function, [string[]]$Args) {
    $joined = @($Function) + @($Args)
    return (Invoke-MangoCall ("dispatch " + ($joined -join ",")))
}

function Unset-MangoBind([string]$Mode, [string]$Mods, [string]$Keysym, [string]$Family = "bind") {
    return (Invoke-MangoCall ("unset bind " + $Mode + " " + $Mods + " " + $Keysym + " " + $Family))
}

function Unset-MangoRule([string]$Kind, [string]$Spec) {
    return (Invoke-MangoCall ("unset " + $Kind + " " + $Spec))
}

function Watch-Mango([string]$Subject, [scriptblock]$Action = $null) {
    $conn = New-MangoConnection
    try {
        $writer = [System.IO.StreamWriter]::new($conn.Stream)
        $writer.AutoFlush = $true
        $writer.WriteLine("watch " + $Subject)
        $reader = [System.IO.StreamReader]::new($conn.Stream)
        while ($null -ne ($line = $reader.ReadLine())) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $frame = $line | ConvertFrom-Json
            if ($frame.error) { throw $frame.error }
            if ($null -eq $Action) { $frame | Write-Output }
            else { & $Action $frame | Out-Null }
        }
    } finally {
        $conn.Stream.Dispose()
        $conn.Socket.Close()
    }
}

function Get-MangoWatchFrame([string]$Subject) {
    $frames = @()
    Watch-Mango $Subject { param($f) $frames += $f } | Out-Null
    return $frames[0]
}

function Get-MangoVersion { return (Get-Mango "version").version }
function Get-MangoMonitors { return (Get-Mango "all-monitors").monitors }
function Get-MangoClients { return (Get-Mango "all-clients").clients }
function Get-MangoFocusedClient { return (Get-Mango "focusing-client") }
function Get-MangoBinds { return (Get-Mango "binds").binds }
function Get-MangoRules { return (Get-Mango "rules").rules }
function Get-MangoOption([string]$Key) { return (Get-Mango ("option " + $Key)).value }
function Get-MangoOptions { return (Get-Mango "options") }

function Add-MangoBind([string]$Mode, [string]$Mods, [string]$Keysym, [string]$Cmd) {
    return (Invoke-MangoDispatch "setup_bind" @($Mode, $Mods, $Keysym, $Cmd))
}

function Add-MangoRule([string]$Match, [string[]]$Props) {
    return (Invoke-MangoDispatch "setup_rule" @($Match) + @($Props))
}

function Add-MangoRuleForClass([string]$ClassName, [string[]]$Props) {
    return (Add-MangoRule ("class=" + $ClassName) $Props)
}

function Set-MangoLayout([string]$Name) {
    return (Invoke-MangoDispatch "setlayout" @($Name))
}

$script:MangoLayoutCount = 0
function Switch-MangoLayout {
    $script:MangoLayoutCount++
    if (($script:MangoLayoutCount % 2) -eq 1) { return (Set-MangoLayout "tile") }
    return (Set-MangoLayout "dwindle")
}

function Set-MangoBorders([int]$Px, [string]$Color) {
    return @((Set-MangoOption "borderpx" "$Px"), (Set-MangoOption "bordercolor" $Color))
}

function Set-MangoGaps([int]$H, [int]$V) {
    return @((Set-MangoOption "gappih" "$H"), (Set-MangoOption "gappiv" "$V"))
}

function Set-MangoTheme([string]$Hex, [int]$BorderPx) {
    return @(
        (Set-MangoOption "rootcolor" $Hex),
        (Set-MangoOption "bordercolor" $Hex),
        (Set-MangoOption "borderpx" "$BorderPx")
    )
}

function Wait-MangoFrame([string]$Subject, [scriptblock]$Predicate, [double]$Timeout = 5.0) {
    $deadline = (Get-Date).AddSeconds($Timeout)
    do {
        $frame = (Get-MangoWatchFrame $Subject)
        if (& $Predicate $frame) { return $frame }
    } while ((Get-Date) -lt $deadline)
    throw "watch_until timeout: watch $Subject"
}

function ForEach-MangoClient([scriptblock]$Action) {
    foreach ($client in (Get-MangoClients)) {
        & $Action $client | Out-Null
    }
}

function When-MangoFocused([scriptblock]$Action) {
    $client = (Get-MangoFocusedClient)
    if ($null -ne $client.id) {
        & $Action $client | Out-Null
    }
}

function Get-MangoOptionsMap {
    $raw = (Get-MangoOptions)
    if ($null -ne $raw.options) {
        $map = @{}
        foreach ($prop in $raw.options.PSObject.Properties) {
            $map[$prop.Name] = if ($prop.Value -is [pscustomobject]) { $prop.Value.value } else { $prop.Value }
        }
        return $map
    }
    if ($null -ne $raw.option) {
        return @{ $raw.option = $raw.value }
    }
    return $raw
}

function Get-MangoInfo {
    return [pscustomobject]@{
        version = (Get-MangoVersion)
        monitors = (Get-MangoMonitors)
        options = (Get-MangoOptions)
    }
}

function Set-MangoOptions([hashtable]$Pairs) {
    $replies = @()
    foreach ($key in $Pairs.Keys) {
        $replies += (Set-MangoOption $key "$($Pairs[$key])")
    }
    return $replies
}