[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ManifestPath,
    [Parameter(Mandatory)][string]$TargetUser,
    [string]$SourceProfile = $env:USERPROFILE
)

. "$PSScriptRoot\Sidecar.Common.ps1"
Assert-SidecarAdmin

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "Manifest not found: $ManifestPath"
}

$manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$targetProfile = Get-SidecarProfilePath -UserName $TargetUser -RequireExisting
$copiedDirectories = New-Object System.Collections.Generic.List[object]
$copiedFiles = New-Object System.Collections.Generic.List[object]

$directoryEntries = @()
if ($manifest.directories) { $directoryEntries = @($manifest.directories) }
$fileEntries = @()
if ($manifest.files) { $fileEntries = @($manifest.files) }
$registryEntries = @()
if ($manifest.registryKeys) { $registryEntries = @($manifest.registryKeys) }

foreach ($entry in $directoryEntries) {
    $src = Resolve-SidecarTemplatePath -Path $entry.source -SourceProfile $SourceProfile -TargetProfile $targetProfile
    $dst = Resolve-SidecarTemplatePath -Path $entry.destination -SourceProfile $SourceProfile -TargetProfile $targetProfile
    $ok = Invoke-SidecarRobocopy -Source $src -Destination $dst
    $copiedDirectories.Add([ordered]@{ source = $src; destination = $dst; copied = $ok })
}

foreach ($entry in $fileEntries) {
    $src = Resolve-SidecarTemplatePath -Path $entry.source -SourceProfile $SourceProfile -TargetProfile $targetProfile
    $dst = Resolve-SidecarTemplatePath -Path $entry.destination -SourceProfile $SourceProfile -TargetProfile $targetProfile
    if (Test-Path -LiteralPath $src) {
        New-SidecarDirectory -Path (Split-Path -Parent $dst)
        Copy-Item -LiteralPath $src -Destination $dst -Force
        $copiedFiles.Add([ordered]@{ source = $src; destination = $dst; copied = $true })
    } else {
        $copiedFiles.Add([ordered]@{ source = $src; destination = $dst; copied = $false })
    }
}

$targetSid = Get-SidecarLocalUserSid -UserName $TargetUser
$targetHiveLoaded = Test-Path -LiteralPath "Registry::HKEY_USERS\$targetSid"
$targetHiveMount = $targetSid
if (-not $targetHiveLoaded) {
    $targetHiveMount = "CodexSidecarTarget"
    $targetHive = Join-Path $targetProfile "NTUSER.DAT"
    if (-not (Test-Path -LiteralPath $targetHive)) {
        throw "Target user hive not found: $targetHive"
    }
    & reg.exe load "HKU\$targetHiveMount" $targetHive | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to load target registry hive for $TargetUser."
    }
}

$registryImported = New-Object System.Collections.Generic.List[string]
try {
    foreach ($key in $registryEntries) {
        if (-not $key) { continue }
        if ($key -notlike "HKCU\*") {
            throw "Only HKCU registry keys are supported by this script: $key"
        }
        $temp = Join-Path $env:TEMP ("codex-sidecar-" + ([guid]::NewGuid()) + ".reg")
        $targetReg = Join-Path $env:TEMP ("codex-sidecar-target-" + ([guid]::NewGuid()) + ".reg")
        & reg.exe export $key $temp /y | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Registry key export failed, skipping: $key"
            continue
        }
        $relative = $key.Substring("HKCU\".Length)
        $text = Get-Content -LiteralPath $temp -Raw -Encoding Unicode
        $text = $text -replace "HKEY_CURRENT_USER\\$([regex]::Escape($relative))", "HKEY_USERS\$targetHiveMount\$relative"
        Set-Content -LiteralPath $targetReg -Value $text -Encoding Unicode
        & reg.exe import $targetReg | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $registryImported.Add($key)
        } else {
            Write-Warning "Registry import failed: $key"
        }
        Remove-Item -LiteralPath $temp, $targetReg -Force -ErrorAction SilentlyContinue
    }
} finally {
    if (-not $targetHiveLoaded) {
        & reg.exe unload "HKU\$targetHiveMount" | Out-Null
    }
}

[ordered]@{
    manifest = (Resolve-Path -LiteralPath $ManifestPath).Path
    sourceProfile = $SourceProfile
    targetProfile = $targetProfile
    copiedDirectories = $copiedDirectories
    copiedFiles = $copiedFiles
    registryImported = $registryImported
} | ConvertTo-SidecarJson
