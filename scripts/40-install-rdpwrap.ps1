[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$RdpWrapperExe,
    [switch]$SkipServiceRestart
)

. "$PSScriptRoot\Sidecar.Common.ps1"
Assert-SidecarAdmin

if (-not (Test-Path -LiteralPath $RdpWrapperExe)) {
    throw "RDP Wrapper executable not found. Download it from https://github.com/sergiye/rdpWrapper and pass -RdpWrapperExe."
}

$wrapperFile = Get-Item -LiteralPath $RdpWrapperExe
$termsrv = Get-Item "$env:SystemRoot\System32\termsrv.dll"

$proc = Start-Process -FilePath $wrapperFile.FullName -ArgumentList "-install -offline" -Wait -PassThru -WindowStyle Hidden
if ($proc.ExitCode -ne 0) {
    throw "rdpWrapper -install failed with exit code $($proc.ExitCode)."
}

$tsKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server"
$rdpTcpKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp"
$policyKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
New-Item -Path $policyKey -Force | Out-Null

New-ItemProperty -Path $tsKey -Name fDenyTSConnections -Value 0 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $tsKey -Name fSingleSessionPerUser -Value 0 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $policyKey -Name fSingleSessionPerUser -Value 0 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $policyKey -Name fPolicyLimitConnections -Value 1 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $policyKey -Name MaxConnections -Value 999999 -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $rdpTcpKey -Name MaxInstanceCount -Value 0xffffffff -PropertyType DWord -Force | Out-Null

try {
    Get-NetFirewallRule -ErrorAction Stop |
        Where-Object { $_.Name -like "RemoteDesktop*" -or $_.DisplayGroup -match "Remote Desktop|远程桌面" } |
        Enable-NetFirewallRule -ErrorAction SilentlyContinue
} catch {
    Write-Warning "Could not update Remote Desktop firewall rules: $($_.Exception.Message)"
}

if (-not $SkipServiceRestart) {
    Restart-Service -Name TermService -Force
    Start-Sleep -Seconds 3
}

[ordered]@{
    rdpWrapperExe = $wrapperFile.FullName
    rdpWrapperVersion = $wrapperFile.VersionInfo.ProductVersion
    termsrvVersion = $termsrv.VersionInfo.ProductVersion
    serviceDll = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\TermService\Parameters").ServiceDll
    termServiceStatus = (Get-Service TermService).Status.ToString()
    fDenyTSConnections = (Get-ItemProperty $tsKey).fDenyTSConnections
    fSingleSessionPerUser = (Get-ItemProperty $tsKey).fSingleSessionPerUser
    policyMaxConnections = (Get-ItemProperty $policyKey).MaxConnections
    listener3389 = [bool](Get-NetTCPConnection -LocalPort 3389 -State Listen -ErrorAction SilentlyContinue)
} | ConvertTo-SidecarJson
