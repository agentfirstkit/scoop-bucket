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
    return @(Get-ChildItem -LiteralPath (Join-Path $Root "bucket") -Filter "*.json" | Sort-Object Name)
}

function Test-Static {
    $Readme = Get-Content -LiteralPath (Join-Path $Root "README.md") -Raw
    if ($Readme.Contains("<bin>")) {
        throw "README contains a PowerShell-significant binary placeholder"
    }
    foreach ($File in Get-Manifests) {
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
        if ($Asset.url -notmatch "^https://github\.com/agentfirstkit/agent-first-[a-z0-9-]+/releases/download/v$([regex]::Escape($Document.version))/$Name-v$([regex]::Escape($Document.version))-x86_64-pc-windows-msvc\.zip$") {
            throw "$($File.Name): URL is not the versioned x64 Windows asset"
        }
        if ($Asset.hash -notmatch "^[0-9a-f]{64}$") {
            throw "$($File.Name): hash is not 64 lowercase hex characters"
        }
        foreach ($Binary in @($Document.bin)) {
            if ($Binary -notmatch "^[a-z][a-z0-9-]*\.exe$") {
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
        "afmail" {
            $Workspace = Join-Path $TempRoot "mail"
            & afmail init $Workspace | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "afmail init failed with exit $LASTEXITCODE" }
            & afmail doctor --workspace $Workspace | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "afmail doctor failed with exit $LASTEXITCODE" }
        }
        "afpay" {
            & afpay limit list --data-dir (Join-Path $TempRoot "pay") | Out-Null
            if ($LASTEXITCODE -ne 0) { throw "afpay limit list failed with exit $LASTEXITCODE" }
        }
        "afslug" {
            $Output = @(& afslug slugify "Hello, World!")
            if ($LASTEXITCODE -ne 0 -or ($Output -join "`n") -notmatch "hello-world") {
                throw "afslug functional smoke failed"
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
    $TempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("agent-first-scoop-test-" + [Guid]::NewGuid())
    New-Item -ItemType Directory -Path $TempRoot | Out-Null
    try {
        foreach ($File in Get-Manifests) {
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
            try {
                $InstallAttempted = $true
                scoop install $File.FullName | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    throw "$Name install failed with exit $LASTEXITCODE"
                }
                foreach ($Command in $Commands) {
                    & $Command --version | Out-Null
                    if ($LASTEXITCODE -ne 0) {
                        throw "$Command --version failed with exit $LASTEXITCODE"
                    }
                }
                Test-InstalledCommand $Name $TempRoot
            }
            finally {
                if ($InstallAttempted) {
                    scoop uninstall $Name | Out-Null
                    if ($LASTEXITCODE -ne 0) {
                        throw "$Name cleanup failed with exit $LASTEXITCODE"
                    }
                    foreach ($Command in $Commands) {
                        if (Get-Command $Command -ErrorAction SilentlyContinue) {
                            throw "$Name uninstall left the $Command shim on PATH"
                        }
                    }
                }
            }
        }
    }
    finally {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force
    }
}

switch ($Mode) {
    "Static" { Test-Static }
    "Install" { Test-Install }
    "All" { Test-Static; Test-Install }
}
