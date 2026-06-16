[CmdletBinding()]
param(
    [string]$RdpPath = (Join-Path ([Environment]::GetFolderPath("Desktop")) "Codex.rdp"),
    [string]$TemplatePath = (Join-Path (Split-Path -Parent $PSScriptRoot) "templates\Codex.rdp.template"),
    [string]$FullAddress = "127.0.0.20",
    [Parameter(Mandatory)][string]$UserName,
    [string]$Password = "",
    [int]$DesktopWidth = 2560,
    [int]$DesktopHeight = 1600,
    [switch]$SaveCredential,
    [switch]$Sign,
    [string]$CertificateSubject = "CN=Codex RDP Publisher"
)

. "$PSScriptRoot\Sidecar.Common.ps1"

if (-not (Test-Path -LiteralPath $TemplatePath)) {
    throw "Template not found: $TemplatePath"
}

$rdp = Get-Content -LiteralPath $TemplatePath -Raw -Encoding UTF8
$rdp = $rdp.Replace("{{FULL_ADDRESS}}", $FullAddress)
$rdp = $rdp.Replace("{{USERNAME}}", $UserName)
$rdp = $rdp.Replace("{{DESKTOP_WIDTH}}", [string]$DesktopWidth)
$rdp = $rdp.Replace("{{DESKTOP_HEIGHT}}", [string]$DesktopHeight)
New-SidecarDirectory -Path (Split-Path -Parent $RdpPath)
Set-Content -LiteralPath $RdpPath -Value $rdp -Encoding Unicode -NoNewline

if ($SaveCredential) {
    if (-not $Password) {
        throw "-SaveCredential requires -Password."
    }
    cmdkey /delete:TERMSRV/$FullAddress 2>$null | Out-Null
    cmdkey /generic:TERMSRV/$FullAddress /user:$UserName /pass:$Password | Out-Null
}

$thumbprint = $null
if ($Sign) {
    $cert = Get-ChildItem Cert:\CurrentUser\My |
        Where-Object { $_.Subject -eq $CertificateSubject -and $_.HasPrivateKey -and $_.NotAfter -gt (Get-Date).AddMonths(1) } |
        Sort-Object NotAfter -Descending |
        Select-Object -First 1
    if (-not $cert) {
        $cert = New-SelfSignedCertificate `
            -Type CodeSigningCert `
            -Subject $CertificateSubject `
            -KeyUsage DigitalSignature `
            -FriendlyName "Codex RDP Signing Certificate" `
            -CertStoreLocation "Cert:\CurrentUser\My" `
            -NotAfter (Get-Date).AddYears(5)
    }
    $certFile = Join-Path $env:TEMP "codex-rdp-publisher.cer"
    Export-Certificate -Cert $cert -FilePath $certFile -Force | Out-Null
    Import-Certificate -FilePath $certFile -CertStoreLocation Cert:\CurrentUser\Root | Out-Null
    Import-Certificate -FilePath $certFile -CertStoreLocation Cert:\CurrentUser\TrustedPublisher | Out-Null

    $output = & rdpsign.exe /sha256 $cert.Thumbprint $RdpPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        $output = & rdpsign.exe /sha1 $cert.Thumbprint $RdpPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "rdpsign failed: $output"
        }
    }
    $thumbprint = $cert.Thumbprint
}

[ordered]@{
    rdpPath = $RdpPath
    fullAddress = $FullAddress
    userName = $UserName
    credentialSaved = [bool]$SaveCredential
    signed = [bool]$Sign
    certificateThumbprint = $thumbprint
} | ConvertTo-SidecarJson

