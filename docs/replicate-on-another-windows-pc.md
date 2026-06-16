# Replicate On Another Windows PC

[中文说明](replicate-on-another-windows-pc.zh-CN.md)

Use this handoff when you want another local Windows machine to run the same Codex RDP sidecar setup.

## Prompt For Codex On The Target PC

Copy this into Codex on the target machine after the prerequisites are ready:

```text
Please set up this Windows PC as a Codex RDP sidecar machine using the codex-rdp-sidecar toolkit.

Repository or package path:
<paste cloned repo path or extracted zip path here>

Target sidecar account:
- username: codex
- password: <choose a local password>
- local admin: yes, only because this is my personal machine and I accept the risk

Game path:
E:\FunPlus\Foundation Galactic Frontier

Requirements:
- Run the scripts from an elevated PowerShell session.
- Create or repair the sidecar user.
- Copy my selected Codex session, Codex pets, and game profile.
- Keep the sidecar Codex sandbox policy on workspace-write/on-request. Do not preserve danger-full-access.
- Install/configure RDP Wrapper from my downloaded rdpWrapper.exe.
- Generate a signed desktop Codex.rdp launcher, save credentials if I explicitly provide the password, use 150% scaling, and avoid scroll bars when maximized.
- Verify RDP, TermService/RDP Wrapper state, and Codex sandbox readiness.
- Explain any risk before disabling RDP warnings or copying auth/state files.
```

## Human Prerequisites

Do these on the target PC before asking Codex to run the flow:

- Use Windows 10/11 Pro, Enterprise, Education, or Pro for Workstations.
- Keep this on a private LAN or VPN. Do not expose RDP directly to the public internet.
- Sign in with an account that can run elevated PowerShell.
- Enable Windows sudo or be ready to use Administrator PowerShell.
- If you want the same no-prompt lab workflow, disable UAC or configure elevation so scripts will not stall.
- Install Codex Desktop on the main user and sign in.
- Download RDP Wrapper separately from <https://github.com/sergiye/rdpWrapper>.
- Review the RDP Wrapper issue tracker for current Windows compatibility, especially <https://github.com/sergiye/rdpWrapper/issues/27>.
- Decide whether you really want to copy Codex auth/state files. They may contain reusable credentials or tokens.

## Transfer Options

Preferred if SSH auth works:

```powershell
Set-Location H:\Codex
git clone git@github.com:David-Lzy/codex-rdp-sidecar.git
Set-Location H:\Codex\codex-rdp-sidecar
```

If GitHub SSH is not configured on the target PC, copy the prepared zip package, extract it, and run commands from the extracted folder.

## Standard Command Sequence

Adjust paths, password, session ID, and RDP Wrapper path before running.

```powershell
Set-Location H:\Codex\codex-rdp-sidecar

$RdpWrapperExe = "H:\Download\rdpWrapper.exe"
$SidecarUser = "codex"
$SidecarPassword = "<choose-a-password>"
$RdpAddress = "127.0.0.20"
$RdpPath = "$env:USERPROFILE\Desktop\Codex.rdp"
$SessionId = "<codex-session-id>"

.\scripts\00-preflight.ps1 -RdpWrapperExe $RdpWrapperExe

.\scripts\10-create-sidecar-user.ps1 `
  -UserName $SidecarUser `
  -Password $SidecarPassword `
  -MakeAdmin `
  -InitializeProfile

.\scripts\20-copy-codex-session.ps1 `
  -TargetUser $SidecarUser `
  -SessionId $SessionId `
  -IncludePets `
  -IncludeAuth `
  -IncludeState

.\scripts\30-copy-game-profile.ps1 `
  -ManifestPath .\profiles\foundation-galactic-frontier.example.json `
  -TargetUser $SidecarUser

.\scripts\40-install-rdpwrap.ps1 -RdpWrapperExe $RdpWrapperExe

.\scripts\50-create-rdp-launcher.ps1 `
  -RdpPath $RdpPath `
  -FullAddress $RdpAddress `
  -UserName "$env:COMPUTERNAME\$SidecarUser" `
  -Password $SidecarPassword `
  -DesktopWidth 3840 `
  -DesktopHeight 2060 `
  -DesktopScaleFactor 150 `
  -SaveCredential `
  -Sign

.\scripts\90-verify.ps1 `
  -RdpPath $RdpPath `
  -FullAddress $RdpAddress `
  -TargetUser $SidecarUser
```

If you want to suppress the newer unknown `.rdp` publisher warning, prefer trusting the certificate thumbprint emitted by `50-create-rdp-launcher.ps1`:

```powershell
.\scripts\60-disable-rdp-warning.ps1 -TrustedCertThumbprint "<thumbprint>"
```

Use `-AllowUnsignedFiles` only on a machine where you accept the broader risk.

## Important Sandbox Note

Do not copy `danger-full-access` into the sidecar account unless you intentionally want to disable managed sandbox enforcement.

`20-copy-codex-session.ps1` now normalizes the sidecar account to:

```toml
sandbox_mode = "workspace-write"
approval_policy = "on-request"
```

This avoids the Codex Desktop error:

```text
only managed permission profiles can be enforced by the Windows sandbox
```

After changing this config, fully exit and reopen Codex inside the RDP session.

## Checks

Useful process and log checks:

```powershell
tasklist /v /fi "imagename eq Codex.exe"
tasklist /v /fi "imagename eq codex.exe"

Get-WinEvent -FilterHashtable @{
  LogName = "Application"
  StartTime = (Get-Date).AddHours(-2)
} | Where-Object {
  $_.Message -match "Codex-SearchForUpdatesWithPausedAddAsync|80073d02|StoreAgent"
}
```

Codex Desktop logs for MSIX installs are usually under:

```text
C:\Users\<user>\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\Codex\Logs
```

## Risk Reminder

This setup creates another interactive login path, may save RDP credentials, may copy Codex auth/state, and depends on third-party RDP Wrapper compatibility. Use it only on machines where you accept those risks.
