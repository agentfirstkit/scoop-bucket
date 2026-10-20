param(
    [ValidateSet("Static", "Install", "All")]
    [string]$Mode = "All",
    [string]$Manifest = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$AllowedKeys = @("architecture", "bin", "description", "homepage", "license", "version")
$ForbiddenKeys = @("installer", "post_install", "pre_install", "script", "uninstaller")

function Get-Manifests {
    if ($Manifest) {
        $Path = Join-Path $Root $Manifest
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
            throw "Manifest not found: $Manifest"
        }
        return @(Get-Item -LiteralPath $Path)
    }
    $Files = @(Get-ChildItem -LiteralPath (Join-Path $Root "bucket") -Filter "*.json" -File | Sort-Object Name)
    if ($Files.Count -eq 0) {
        throw "Bucket contains no manifests"
    }
    return $Files
}

function Test-Static {
    $Manifests = @(Get-Manifests)
    $Readme = Get-Content -LiteralPath (Join-Path $Root "README.md") -Raw
    if ($Readme.Contains("<bin>")) {
        throw "README contains a PowerShell-significant binary placeholder"
    }
    foreach ($File in $Manifests) {
        $Name = $File.BaseName
        $Document = Get-Content -LiteralPath $File.FullName -Raw | ConvertFrom-Json
        $Keys = @($Document.PSObject.Properties.Name | Sort-Object)
        if (Compare-Object $AllowedKeys $Keys) {
            throw "$($File.Name): top-level fields differ from the declarative allowlist"
        }
        foreach ($Key in $ForbiddenKeys) {
            if ($Document.PSObject.Properties.Name -contains $Key) {
                throw "$($File.Name): forbidden script field $Key"
            }
        }
        $Architectures = @($Document.architecture.PSObject.Properties.Name)
        if ($Architectures.Count -ne 1 -or $Architectures[0] -ne "64bit") {
            throw "$($File.Name): only an explicit 64bit package is supported"
        }
        $Asset = $Document.architecture."64bit"
        if ($Asset.url -cnotmatch "^https://github\.com/agentfirstkit/agent-first-[a-z0-9-]+/releases/download/v$([regex]::Escape($Document.version))/$Name-v$([regex]::Escape($Document.version))-x86_64-pc-windows-msvc\.zip$") {
            throw "$($File.Name): URL is not the versioned x64 Windows asset"
        }
        if ($Asset.hash -cnotmatch "^[0-9a-f]{64}$") {
            throw "$($File.Name): hash is not 64 lowercase hex characters"
        }
        $Binaries = @($Document.bin)
        if ($null -eq $Document.bin -or $Binaries.Count -eq 0) {
            throw "$($File.Name): bin must declare at least one binary"
        }
        if (@($Binaries | Sort-Object -Unique).Count -ne $Binaries.Count) {
            throw "$($File.Name): binary shims must be unique (case-insensitive)"
        }
        foreach ($Binary in $Binaries) {
            if ($Binary -cnotmatch "^[a-z][a-z0-9-]*\.exe$") {
                throw "$($File.Name): invalid binary shim $Binary"
            }
        }
        if (-not $Readme.Contains("scoop install agentfirstkit/$Name")) {
            throw "README lacks the concrete install command for $Name"
        }
    }
}

function Test-InstalledCommand([string]$Name, [string]$TempRoot) {
    switch ($Name) {
        "afdata" {
            $Fixture = Join-Path $TempRoot "valid.json"
            '{"duration_ms":25}' | Set-Content -LiteralPath $Fixture -Encoding utf8
            & afdata lint $Fixture | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "afdata lint failed with exit $LASTEXITCODE" }
        }
        "affiles" {
            $Directory = Join-Path $TempRoot "files-contract"
            & affiles api export --directory $Directory | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "affiles api export failed with exit $LASTEXITCODE" }
            $Contract = Get-Content -LiteralPath (Join-Path $Directory "openapi.json") -Raw | ConvertFrom-Json -AsHashtable
            foreach ($Path in @("/v1/directories", "/v1/files/text")) {
                if (-not $Contract["paths"].ContainsKey($Path) -or -not $Contract["paths"][$Path].ContainsKey("get")) {
                    throw "affiles contract lacks GET $Path"
                }
            }
        }
        "afhttp" {
            $ProfileRoot = Join-Path $TempRoot "profiles"
            $ProfileDirectory = Join-Path $ProfileRoot "chromium/inspector"
            New-Item -ItemType Directory -Path $ProfileDirectory | Out-Null
            "profile smoke" | Set-Content -LiteralPath (Join-Path $ProfileDirectory "fixture.txt") -Encoding utf8
            $Output = @(& afhttp profile list --profile-root $ProfileRoot)
            if ($LASTEXITCODE -ne 0) { throw "afhttp profile list failed with exit $LASTEXITCODE" }
            $Event = ($Output -join "`n") | ConvertFrom-Json
            $Profiles = @($Event.result.profiles)
            if ($Event.kind -ne "result" -or $Event.result.code -ne "profile_list" -or
                $Profiles.Count -ne 1 -or $Profiles[0].backend -ne "chromium" -or $Profiles[0].name -ne "inspector") {
                throw "afhttp profile inventory differs from the offline fixture"
            }
        }
        "afmail" {
            # `init` takes a path relative to the current directory and refuses
            # an absolute one, so this runs from $TempRoot and names the
            # workspace rather than handing over a joined path. Restored in a
            # finally block so one failure here does not leave every later
            # smoke running from the wrong directory.
            $Previous = Get-Location
            try {
                Set-Location -LiteralPath $TempRoot
                & afmail init "mail" | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "afmail init failed with exit $LASTEXITCODE" }
                & afmail doctor --workspace "mail" | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "afmail doctor failed with exit $LASTEXITCODE" }
            } finally {
                Set-Location -LiteralPath $Previous
            }
        }
        "afpay" {
            & afpay limit list --data-dir (Join-Path $TempRoot "pay") | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "afpay limit list failed with exit $LASTEXITCODE" }
        }
        "afpdf" {
            # Run from $TempRoot so the default .afpdf/config.json lookup
            # cannot pick up a configuration from wherever the gate started.
            $Previous = Get-Location
            try {
                Set-Location -LiteralPath $TempRoot
                $Output = @(& afpdf engine status)
                if ($LASTEXITCODE -ne 0) { throw "afpdf engine status failed with exit $LASTEXITCODE" }
            } finally {
                Set-Location -LiteralPath $Previous
            }
            $Event = ($Output -join "`n") | ConvertFrom-Json
            if ($Event.kind -ne "result" -or $Event.result.code -ne "engine_status" -or
                [string]::IsNullOrEmpty($Event.result.pinned_build)) {
                throw "afpdf engine status did not report the pinned engine build"
            }
        }
        "afpsql" {
            $PipeRequests = @('{"code":"ping"}', '{"code":"close"}')
            $Output = @($PipeRequests | & afpsql --mode pipe)
            if ($LASTEXITCODE -ne 0) { throw "afpsql pipe failed with exit $LASTEXITCODE" }
            $Events = @($Output | ForEach-Object { $_ | ConvertFrom-Json })
            if ($Events.Count -ne 2 -or $Events[0].kind -ne "result" -or $Events[1].kind -ne "result" -or
                $Events[0].result.code -ne "pong" -or $Events[1].result.code -ne "close") {
                throw "afpsql pipe did not answer ping and close in order"
            }
        }
        "afslug" {
            $Output = @(& afslug slugify "Hello, World!")
            if ($LASTEXITCODE -ne 0 -or ($Output -join "`n") -notmatch "hello-world") {
                throw "afslug functional smoke failed"
            }
        }
        "afterminal" {
            $Directory = Join-Path $TempRoot "terminal-contract"
            & afterminal api export --directory $Directory | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "afterminal api export failed with exit $LASTEXITCODE" }
            $Contract = Get-Content -LiteralPath (Join-Path $Directory "openapi.json") -Raw | ConvertFrom-Json -AsHashtable
            if (-not $Contract["paths"].ContainsKey("/v1/sessions") -or
                -not $Contract["paths"]["/v1/sessions"].ContainsKey("post")) {
                throw "afterminal contract lacks POST /v1/sessions"
            }
        }
        "afui" {
            $PreviousLocation = Get-Location
            $PreviousConfig = $env:AFUI_CONFIG_DIR
            $PreviousSafeMode = $env:AFUI_SAFE_MODE
            try {
                Set-Location -LiteralPath $TempRoot
                $env:AFUI_CONFIG_DIR = Join-Path $TempRoot "afui-config"
                $env:AFUI_SAFE_MODE = "0"
                & afui frontend init inspector panel --scope workspace --frontend-id smoke | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "afui frontend init failed with exit $LASTEXITCODE" }
                $Output = @(& afui frontend check inspector panel --scope workspace)
                if ($LASTEXITCODE -ne 0) { throw "afui frontend check failed with exit $LASTEXITCODE" }
                $Event = ($Output -join "`n") | ConvertFrom-Json
                if ($Event.kind -ne "result" -or $Event.result.code -ne "frontend_check" -or
                    $Event.result.frontend_id -ne "smoke" -or $Event.result.status -ne "disabled") {
                    throw "afui frontend check differs from the offline fixture"
                }
                $Frontend = Get-Content -LiteralPath (Join-Path $TempRoot ".afui/frontends/inspector/panel/frontend.json") -Raw | ConvertFrom-Json
                if ($Frontend.frontend_id -ne "smoke" -or $Frontend.ui_api_version -ne "1") {
                    throw "afui frontend init wrote an unexpected manifest"
                }
            } finally {
                Set-Location -LiteralPath $PreviousLocation
                $env:AFUI_CONFIG_DIR = $PreviousConfig
                $env:AFUI_SAFE_MODE = $PreviousSafeMode
            }
        }
        default {
            $Output = @(& $Name --docs)
            if ($LASTEXITCODE -ne 0 -or ($Output -join "`n") -notmatch "CLI reference") {
                throw "$Name docs smoke failed"
            }
        }
    }
}

function Test-Install {
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        throw "Scoop is required for Install mode"
    }
    $Manifests = @(Get-Manifests)
    $Buckets = @(scoop bucket list)
    $BucketListExit = $LASTEXITCODE
    if ($BucketListExit -ne 0 -and $BucketListExit -ne 2) {
        throw "Scoop bucket list failed with exit $BucketListExit"
    }
    if ($Buckets | Where-Object { $_.Name -eq "agentfirstkit" }) {
        throw "Refusing to alter an already-registered bucket: agentfirstkit"
    }

    $TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-first-scoop-test-" + [Guid]::NewGuid())
    $TempRootCreated = $false
    $BucketAdded = $false
    $PrimaryFailure = $null
    $CleanupFailures = @()
    try {
        New-Item -ItemType Directory -Path $TempRoot | Out-Null
        $TempRootCreated = $true
        # Scoop validates Git repository paths using forward slashes, including
        # a Windows checkout path. Registration belongs to this run only after
        # add succeeds; an existing or failed registration is never removed.
        $LocalCheckout = $Root.Replace('\', '/')
        scoop bucket add agentfirstkit $LocalCheckout | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Local bucket registration failed with exit $LASTEXITCODE"
        }
        $BucketAdded = $true

        foreach ($File in $Manifests) {
            $Name = $File.BaseName
            $Document = Get-Content -LiteralPath $File.FullName -Raw | ConvertFrom-Json
            $Commands = @($Document.bin | ForEach-Object {
                [System.IO.Path]::GetFileNameWithoutExtension($_)
            })
            scoop prefix $Name 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) {
                throw "Refusing to alter an already-installed package: $Name"
            }

            $InstallAttempted = $false
            $PackageFailure = $null
            $PackageCleanupFailures = @()
            try {
                $InstallAttempted = $true
                scoop install "agentfirstkit/$Name" | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    throw "$Name install failed with exit $LASTEXITCODE"
                }
                $VersionPattern = "(?<![0-9A-Za-z.+-])" + [regex]::Escape($Document.version) + "(?![0-9A-Za-z.+-])"
                foreach ($Command in $Commands) {
                    $VersionOutput = @(& $Command --version)
                    if ($LASTEXITCODE -ne 0) {
                        throw "$Command --version failed with exit $LASTEXITCODE"
                    }
                    if (($VersionOutput -join "`n") -notmatch $VersionPattern) {
                        throw "$Command --version does not match manifest version $($Document.version)"
                    }
                }
                Test-InstalledCommand $Name $TempRoot
            }
            catch {
                $PackageFailure = $_
            }
            finally {
                if ($InstallAttempted) {
                    try {
                        scoop uninstall $Name | Out-Null
                        if ($LASTEXITCODE -ne 0) {
                            throw "$Name cleanup failed with exit $LASTEXITCODE"
                        }
                    }
                    catch {
                        $PackageCleanupFailures += $_
                    }
                    foreach ($Command in $Commands) {
                        try {
                            if (Get-Command $Command -ErrorAction SilentlyContinue) {
                                throw "$Name uninstall left the $Command shim on PATH"
                            }
                        }
                        catch {
                            $PackageCleanupFailures += $_
                        }
                    }
                }
                foreach ($Failure in $PackageCleanupFailures) {
                    Write-Error -ErrorRecord $Failure -ErrorAction Continue
                }
            }
            if ($PackageFailure) {
                throw $PackageFailure
            }
            if ($PackageCleanupFailures.Count -gt 0) {
                throw $PackageCleanupFailures[0]
            }
        }
    }
    catch {
        $PrimaryFailure = $_
    }
    finally {
        if ($BucketAdded) {
            try {
                scoop bucket rm agentfirstkit | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    throw "Local bucket cleanup failed with exit $LASTEXITCODE"
                }
            }
            catch {
                $CleanupFailures += $_
            }
        }
        try {
            if ($TempRootCreated -and (Test-Path -LiteralPath $TempRoot)) {
                Remove-Item -LiteralPath $TempRoot -Recurse -Force
            }
        }
        catch {
            $CleanupFailures += $_
        }
        foreach ($Failure in $CleanupFailures) {
            Write-Error -ErrorRecord $Failure -ErrorAction Continue
        }
    }
    if ($PrimaryFailure) {
        throw $PrimaryFailure
    }
    if ($CleanupFailures.Count -gt 0) {
        throw $CleanupFailures[0]
    }
}

switch ($Mode) {
    "Static" { Test-Static }
    "Install" { Test-Install }
    "All" { Test-Static; Test-Install }
}
