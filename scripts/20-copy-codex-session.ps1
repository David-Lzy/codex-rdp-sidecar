[CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
param(
    [Parameter(Mandatory)][string]$TargetUser,
    [string]$SourceProfile = $env:USERPROFILE,
    [string]$SessionId = "",
    [switch]$IncludeAuth,
    [switch]$IncludeState,
    [switch]$IncludePets,
    [switch]$MoveSession
)

. "$PSScriptRoot\Sidecar.Common.ps1"

$targetProfile = Get-SidecarProfilePath -UserName $TargetUser -RequireExisting
$sourceCodex = Join-Path $SourceProfile ".codex"
$targetCodex = Join-Path $targetProfile ".codex"
if (-not (Test-Path -LiteralPath $sourceCodex)) {
    throw "Source .codex directory not found: $sourceCodex"
}
New-SidecarDirectory -Path $targetCodex

$copied = New-Object System.Collections.Generic.List[string]
$baseFiles = @("config.toml", "AGENTS.md", "session_index.jsonl", "models_cache.json")
if ($IncludeAuth) {
    $baseFiles += @("auth.json", "chrome-native-hosts.json", "chrome-native-hosts-v2.json")
}
if ($IncludeState) {
    $baseFiles += @(".codex-global-state.json", "state_5.sqlite", "state_5.sqlite-shm", "state_5.sqlite-wal")
}

foreach ($name in $baseFiles) {
    $src = Join-Path $sourceCodex $name
    if (Test-Path -LiteralPath $src) {
        Copy-Item -LiteralPath $src -Destination (Join-Path $targetCodex $name) -Force
        $copied.Add(".codex\$name")
    }
}

if ($IncludePets) {
    $sourcePets = Join-Path $sourceCodex "pets"
    $targetPets = Join-Path $targetCodex "pets"
    if (Invoke-SidecarRobocopy -Source $sourcePets -Destination $targetPets) {
        $copied.Add(".codex\pets")
    }
}

if ($SessionId) {
    $sessionFiles = Get-ChildItem -LiteralPath (Join-Path $sourceCodex "sessions") -Recurse -Filter "*.jsonl" -ErrorAction Stop |
        Where-Object { $_.Name -like "*$SessionId*" }
    if (-not $sessionFiles) {
        throw "No Codex session jsonl matched SessionId '$SessionId'."
    }
    foreach ($file in $sessionFiles) {
        $relative = $file.FullName.Substring($sourceCodex.Length).TrimStart("\")
        $dest = Join-Path $targetCodex $relative
        New-SidecarDirectory -Path (Split-Path -Parent $dest)
        Copy-Item -LiteralPath $file.FullName -Destination $dest -Force
        $copied.Add($relative)
        if ($MoveSession) {
            if ($PSCmdlet.ShouldProcess($file.FullName, "remove source session after copy")) {
                Remove-Item -LiteralPath $file.FullName -Force
            }
        }
    }
}

[ordered]@{
    sourceCodex = $sourceCodex
    targetCodex = $targetCodex
    sessionId = $SessionId
    includeAuth = [bool]$IncludeAuth
    includeState = [bool]$IncludeState
    includePets = [bool]$IncludePets
    moveSession = [bool]$MoveSession
    copied = $copied
} | ConvertTo-SidecarJson
