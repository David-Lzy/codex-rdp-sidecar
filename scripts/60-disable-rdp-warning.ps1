[CmdletBinding()]
param(
    [string]$TrustedCertThumbprint = "",
    [switch]$AllowUnsignedFiles
)

. "$PSScriptRoot\Sidecar.Common.ps1"
Assert-SidecarAdmin

$policyBase = "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services"
$policyClient = Join-Path $policyBase "Client"
New-Item -Path $policyBase -Force | Out-Null
New-Item -Path $policyClient -Force | Out-Null

New-ItemProperty -Path $policyBase -Name AllowSignedFiles -Value 1 -PropertyType DWord -Force | Out-Null
if ($AllowUnsignedFiles) {
    New-ItemProperty -Path $policyBase -Name AllowUnsignedFiles -Value 1 -PropertyType DWord -Force | Out-Null
}
if ($TrustedCertThumbprint) {
    New-ItemProperty -Path $policyBase -Name TrustedCertThumbprints -Value $TrustedCertThumbprint.ToUpperInvariant() -PropertyType String -Force | Out-Null
}

# Compatibility switch for the newer "unknown .rdp publisher" redirection warning.
# Microsoft may remove this behavior in a future Windows release.
New-ItemProperty -Path $policyClient -Name RedirectionWarningDialogVersion -Value 1 -PropertyType DWord -Force | Out-Null

[ordered]@{
    policyBase = $policyBase
    policyClient = $policyClient
    allowSignedFiles = (Get-ItemProperty $policyBase).AllowSignedFiles
    allowUnsignedFiles = (Get-ItemProperty $policyBase -ErrorAction SilentlyContinue).AllowUnsignedFiles
    trustedCertThumbprints = (Get-ItemProperty $policyBase -ErrorAction SilentlyContinue).TrustedCertThumbprints
    redirectionWarningDialogVersion = (Get-ItemProperty $policyClient).RedirectionWarningDialogVersion
} | ConvertTo-SidecarJson
