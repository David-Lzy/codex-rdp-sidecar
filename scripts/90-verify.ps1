param(
    [string]$RdpPath = (Join-Path ([Environment]::GetFolderPath("Desktop")) "Codex.rdp"),
    [string]$FullAddress = "127.0.0.20",
    [string]$TargetUser = "codex"
)

. "$PSScriptRoot\Sidecar.Common.ps1"

$serviceDll = $null
try {
    $serviceDll = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\TermService\Parameters").ServiceDll
} catch {
}

$tsKey = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server" -ErrorAction SilentlyContinue
$policyBase = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" -ErrorAction SilentlyContinue
$policyClient = Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\Client" -ErrorAction SilentlyContinue
$rdpText = if (Test-Path -LiteralPath $RdpPath) { Get-Content -LiteralPath $RdpPath -Raw -Encoding Unicode } else { "" }

[ordered]@{
    targetUserExists = [bool](Get-LocalUser -Name $TargetUser -ErrorAction SilentlyContinue)
    targetProfile = if (Get-LocalUser -Name $TargetUser -ErrorAction SilentlyContinue) { Get-SidecarProfilePath -UserName $TargetUser } else { $null }
    termService = (Get-Service TermService -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType)
    serviceDll = $serviceDll
    rdpListener3389 = [bool](Get-NetTCPConnection -LocalPort 3389 -State Listen -ErrorAction SilentlyContinue)
    localRdpTcp = (Test-NetConnection -ComputerName 127.0.0.1 -Port 3389 -InformationLevel Quiet)
    fDenyTSConnections = $tsKey.fDenyTSConnections
    fSingleSessionPerUser = $tsKey.fSingleSessionPerUser
    policyMaxConnections = $policyBase.MaxConnections
    redirectionWarningDialogVersion = $policyClient.RedirectionWarningDialogVersion
    rdpPath = $RdpPath
    rdpFileExists = (Test-Path -LiteralPath $RdpPath)
    rdpFullAddress = ([regex]::Match($rdpText, "(?m)^full address:s:(.*)$")).Groups[1].Value.Trim()
    rdpUserName = ([regex]::Match($rdpText, "(?m)^username:s:(.*)$")).Groups[1].Value.Trim()
    rdpDesktopWidth = ([regex]::Match($rdpText, "(?m)^desktopwidth:i:(.*)$")).Groups[1].Value.Trim()
    rdpDesktopHeight = ([regex]::Match($rdpText, "(?m)^desktopheight:i:(.*)$")).Groups[1].Value.Trim()
    rdpSmartSizing = ([regex]::Match($rdpText, "(?m)^smart sizing:i:(.*)$")).Groups[1].Value.Trim()
    rdpDynamicResolution = ([regex]::Match($rdpText, "(?m)^dynamic resolution:i:(.*)$")).Groups[1].Value.Trim()
    rdpDesktopScaleFactor = ([regex]::Match($rdpText, "(?m)^desktopscalefactor:i:(.*)$")).Groups[1].Value.Trim()
    rdpDeviceScaleFactor = ([regex]::Match($rdpText, "(?m)^devicescalefactor:i:(.*)$")).Groups[1].Value.Trim()
    rdpSigned = $rdpText -match "(?m)^signature:s:"
    sessions = ((& query.exe session) 2>$null)
} | ConvertTo-SidecarJson
