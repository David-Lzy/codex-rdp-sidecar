$ErrorActionPreference = "Stop"

function Test-SidecarAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-SidecarAdmin {
    if (-not (Test-SidecarAdmin)) {
        throw "This script must run from an elevated PowerShell session."
    }
}

function Get-SidecarLocalUserSid {
    param([Parameter(Mandatory)][string]$UserName)
    $user = Get-LocalUser -Name $UserName -ErrorAction Stop
    return $user.SID.Value
}

function Get-SidecarProfilePath {
    param(
        [Parameter(Mandatory)][string]$UserName,
        [switch]$RequireExisting
    )
    $sid = Get-SidecarLocalUserSid -UserName $UserName
    $profile = Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue |
        Where-Object { $_.SID -eq $sid } |
        Select-Object -First 1
    if ($profile -and $profile.LocalPath) {
        return $profile.LocalPath
    }

    $fallback = Join-Path "C:\Users" $UserName
    if (Test-Path -LiteralPath $fallback) {
        return $fallback
    }
    if ($RequireExisting) {
        throw "Could not find profile path for local user '$UserName'. Log on once or run 10-create-sidecar-user.ps1 -InitializeProfile."
    }
    return $fallback
}

function New-SidecarDirectory {
    param([Parameter(Mandatory)][string]$Path)
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
}

function Invoke-SidecarRobocopy {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination,
        [string[]]$ExtraArgs = @()
    )
    if (-not (Test-Path -LiteralPath $Source)) {
        Write-Warning "Source does not exist, skipping: $Source"
        return $false
    }

    New-SidecarDirectory -Path $Destination
    $args = @($Source, $Destination, "/E", "/COPY:DAT", "/DCOPY:DAT", "/R:2", "/W:1", "/NFL", "/NDL", "/NP") + $ExtraArgs
    & robocopy @args | Out-Null
    $code = $LASTEXITCODE
    if ($code -gt 7) {
        throw "Robocopy failed with exit code $code for '$Source' -> '$Destination'."
    }
    return $true
}

function Resolve-SidecarTemplatePath {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$SourceProfile,
        [string]$TargetProfile
    )
    $resolved = $Path
    if ($SourceProfile) {
        $resolved = $resolved.Replace("{SourceProfile}", $SourceProfile)
    }
    if ($TargetProfile) {
        $resolved = $resolved.Replace("{TargetProfile}", $TargetProfile)
    }
    return [Environment]::ExpandEnvironmentVariables($resolved)
}

function ConvertTo-SidecarJson {
    param([Parameter(Mandatory)]$InputObject)
    $InputObject | ConvertTo-Json -Depth 8
}

