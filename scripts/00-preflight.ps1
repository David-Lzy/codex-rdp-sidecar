param(
    [string]$RdpWrapperExe = "",
    [switch]$Json
)

. "$PSScriptRoot\Sidecar.Common.ps1"

$sudoPath = Join-Path $env:SystemRoot "System32\sudo.exe"
$sudoConfig = $null
if (Test-Path -LiteralPath $sudoPath) {
    try {
        $sudoConfig = (& $sudoPath config) -join "`n"
    } catch {
        $sudoConfig = $_.Exception.Message
    }
}

$enableLua = $null
try {
    $enableLua = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name EnableLUA -ErrorAction Stop).EnableLUA
} catch {
}

$rdpWrapper = if ($RdpWrapperExe) { Get-Item -LiteralPath $RdpWrapperExe -ErrorAction SilentlyContinue } else { $null }
$termsrv = Get-Item "$env:SystemRoot\System32\termsrv.dll" -ErrorAction SilentlyContinue
$serviceDll = $null
try {
    $serviceDll = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\TermService\Parameters" -ErrorAction Stop).ServiceDll
} catch {
}

$result = [ordered]@{
    computerName = $env:COMPUTERNAME
    user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    isAdmin = Test-SidecarAdmin
    windows = (Get-ComputerInfo | Select-Object -Property WindowsProductName, OsBuildNumber, WindowsVersion)
    uacEnableLua = $enableLua
    windowsSudoPath = if (Test-Path -LiteralPath $sudoPath) { $sudoPath } else { $null }
    windowsSudoConfig = $sudoConfig
    rdpsign = (Get-Command rdpsign.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
    termService = (Get-Service TermService -ErrorAction SilentlyContinue | Select-Object Name, Status, StartType)
    termsrvVersion = if ($termsrv) { $termsrv.VersionInfo.ProductVersion } else { $null }
    termServiceDll = $serviceDll
    rdpWrapperExe = if ($rdpWrapper) {
        [ordered]@{
            path = $rdpWrapper.FullName
            version = $rdpWrapper.VersionInfo.ProductVersion
        }
    } else { $null }
}

if ($Json) {
    ConvertTo-SidecarJson $result
} else {
    $result | Format-List
}

