[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$UserName,
    [Parameter(Mandatory)][string]$Password,
    [string]$FullName = "Codex RDP Sidecar",
    [string]$Description = "Local sidecar automation account",
    [switch]$MakeAdmin,
    [switch]$InitializeProfile
)

. "$PSScriptRoot\Sidecar.Common.ps1"
Assert-SidecarAdmin

$secure = ConvertTo-SecureString $Password -AsPlainText -Force
$existing = Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue
if (-not $existing) {
    New-LocalUser -Name $UserName -Password $secure -FullName $FullName -Description $Description -PasswordNeverExpires | Out-Null
} else {
    Set-LocalUser -Name $UserName -Password $secure -PasswordNeverExpires $true
}

Enable-LocalUser -Name $UserName

foreach ($group in @("Remote Desktop Users")) {
    $members = Get-LocalGroupMember -Group $group -ErrorAction Stop
    if (-not ($members | Where-Object { $_.Name -match "\\$([regex]::Escape($UserName))$" })) {
        Add-LocalGroupMember -Group $group -Member "$env:COMPUTERNAME\$UserName"
    }
}

if ($MakeAdmin) {
    $members = Get-LocalGroupMember -Group "Administrators" -ErrorAction Stop
    if (-not ($members | Where-Object { $_.Name -match "\\$([regex]::Escape($UserName))$" })) {
        Add-LocalGroupMember -Group "Administrators" -Member "$env:COMPUTERNAME\$UserName"
    }
}

if ($InitializeProfile) {
    $marker = Join-Path $env:PUBLIC "codex-rdp-sidecar-profile-init.txt"
    Remove-Item -LiteralPath $marker -ErrorAction SilentlyContinue
    $cred = [pscredential]::new("$env:COMPUTERNAME\$UserName", $secure)
    $cmd = "/c whoami > `"$marker`" && echo %USERPROFILE% >> `"$marker`""
    Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" -ArgumentList $cmd -Credential $cred -LoadUserProfile -WindowStyle Hidden -Wait
}

$sid = Get-SidecarLocalUserSid -UserName $UserName
[ordered]@{
    user = "$env:COMPUTERNAME\$UserName"
    sid = $sid
    enabled = (Get-LocalUser -Name $UserName).Enabled
    profilePath = Get-SidecarProfilePath -UserName $UserName
    admin = [bool](Get-LocalGroupMember -Group "Administrators" | Where-Object { $_.SID -eq $sid })
    remoteDesktopUser = [bool](Get-LocalGroupMember -Group "Remote Desktop Users" | Where-Object { $_.SID -eq $sid })
} | ConvertTo-SidecarJson

