# codex-rdp-sidecar

[中文说明](README.zh-CN.md)

Provision an isolated local Windows RDP sidecar account for Codex/game automation, with session migration, game config copying, RDP Wrapper setup, and a signed one-click RDP launcher.

This is for a personal Windows lab or home machine where you want automation to run in a separate interactive desktop session instead of stealing focus from your main console session.

## Status

Experimental. Use at your own risk.

The scripts are designed to be readable and parameterized. They intentionally do not include passwords, copied Codex state, game state, certificates, or RDP Wrapper binaries.

## Prerequisites

- Windows 10/11 Pro, Enterprise, Education, or Pro for Workstations.
- Local administrator rights.
- Windows sudo enabled, or an elevated PowerShell session.
- For the intended no-prompt home workflow, UAC disabled or otherwise configured so elevated scripts can run predictably.
- RDP Wrapper downloaded separately from <https://github.com/sergiye/rdpWrapper>.
- `rdpsign.exe`, included with Windows, for signing generated `.rdp` files.
- A private LAN or VPN. Do not expose this setup directly to the public internet.

The June 2026 RDP Wrapper breakage discussed here is tracked upstream at:

<https://github.com/sergiye/rdpWrapper/issues/27>

For a copy-and-run handoff to another Windows PC, use [docs/replicate-on-another-windows-pc.md](docs/replicate-on-another-windows-pc.md).

## What This Automates

- Creates a local sidecar user, optionally with local administrator rights.
- Adds the user to `Remote Desktop Users`.
- Initializes the sidecar user profile.
- Copies selected Codex session/config files into the sidecar profile.
- Optionally copies Codex auth/state files when explicitly requested.
- Optionally copies local Codex pet assets.
- Copies game profile folders and `HKCU` registry keys through a reviewed manifest.
- Installs/configures RDP Wrapper through an external `rdpWrapper.exe`.
- Configures `TermService` policy for parallel sessions.
- Generates a desktop `.rdp` launcher.
- Saves RDP credentials with `cmdkey` when explicitly requested.
- Signs the `.rdp` file with a local code-signing certificate.
- Optionally disables the newer unknown `.rdp` publisher warning.

## What This Does Not Do

- It does not patch `termsrv.dll`.
- It does not redistribute RDP Wrapper.
- It does not make RDP safe to expose to the internet.
- It does not guarantee compatibility after Windows updates.
- It does not remove your responsibility for licenses, account safety, or local law/policy.

## Quick Start

Run these from an elevated PowerShell session unless noted.

```powershell
Set-Location H:\Codex\codex-rdp-sidecar

.\scripts\00-preflight.ps1 -RdpWrapperExe H:\Download\rdpWrapper.exe

.\scripts\10-create-sidecar-user.ps1 `
  -UserName codex `
  -Password "change-this-password" `
  -MakeAdmin `
  -InitializeProfile

.\scripts\20-copy-codex-session.ps1 `
  -TargetUser codex `
  -SessionId "<codex-session-id>" `
  -IncludePets `
  -IncludeAuth `
  -IncludeState

.\scripts\30-copy-game-profile.ps1 `
  -ManifestPath .\profiles\foundation-galactic-frontier.example.json `
  -TargetUser codex

.\scripts\40-install-rdpwrap.ps1 `
  -RdpWrapperExe H:\Download\rdpWrapper.exe

.\scripts\50-create-rdp-launcher.ps1 `
  -RdpPath "$env:USERPROFILE\Desktop\Codex.rdp" `
  -FullAddress 127.0.0.20 `
  -UserName "$env:COMPUTERNAME\codex" `
  -Password "change-this-password" `
  -DesktopWidth 3840 `
  -DesktopHeight 2060 `
  -DesktopScaleFactor 150 `
  -SaveCredential `
  -Sign

.\scripts\60-disable-rdp-warning.ps1 `
  -AllowUnsignedFiles

.\scripts\90-verify.ps1 `
  -RdpPath "$env:USERPROFILE\Desktop\Codex.rdp" `
  -FullAddress 127.0.0.20 `
  -TargetUser codex
```

If you want the safer signed-file path, run `60-disable-rdp-warning.ps1` with the certificate thumbprint emitted by `50-create-rdp-launcher.ps1` instead of allowing unsigned files:

```powershell
.\scripts\60-disable-rdp-warning.ps1 -TrustedCertThumbprint "<thumbprint>"
```

## Frequent RDP Edits

Editing an `.rdp` file invalidates its signature. Re-run:

```powershell
.\scripts\50-create-rdp-launcher.ps1 `
  -RdpPath "$env:USERPROFILE\Desktop\Codex.rdp" `
  -FullAddress 127.0.0.20 `
  -UserName "$env:COMPUTERNAME\codex" `
  -Password "change-this-password" `
  -SaveCredential `
  -Sign
```

## RDP Resolution And Scaling

`50-create-rdp-launcher.ps1` defaults to the practical sidecar setup tested on a 4K-class local display:

- `desktopwidth:i:3840`
- `desktopheight:i:2060`
- `smart sizing:i:1`
- `dynamic resolution:i:0`
- `desktopscalefactor:i:150`
- `devicescalefactor:i:100`

This favors a maximized window with no scroll bars. `smart sizing` scales the remote frame when the local RDP client area does not exactly match the remote desktop size, so it is not guaranteed to be pixel-perfect. Pixel-perfect output requires the remote desktop size to exactly equal the RDP client area.

`dynamic resolution:i:1` is theoretically better because the remote desktop follows the client window size, but it may not work reliably through RDP Wrapper or modified `TermService` chains. Use `-EnableDynamicResolution` only if you have verified it works on your host.

## Codex Session Copying

`20-copy-codex-session.ps1` copies only basic config by default. You must explicitly opt in to sensitive files:

- `-IncludeAuth` copies `auth.json` and browser/native-host related files.
- `-IncludeState` copies local Codex state SQLite files.
- `-IncludePets` copies `.codex\pets` custom pet assets.
- By default, copied `config.toml` is normalized to `sandbox_mode = "workspace-write"` and `approval_policy = "on-request"` for the sidecar account. This keeps the Windows Agent sandbox on a managed permission profile.
- `-PreserveCodexAccessPolicy` keeps the source `sandbox_mode` and `approval_policy` values. Use it only if you intentionally want to copy settings such as `danger-full-access`.
- `-MoveSession` removes the source session file after copying and uses PowerShell confirmation semantics.

Do not commit copied `.codex` data.

## Troubleshooting Codex Agent Sandbox Updates

If the sidecar account shows `Unable to update Agent sandbox`, there are two common causes.

First, make sure the sidecar Codex config is not forcing full access. Windows Agent sandbox setup can only enforce managed permission profiles. If the Codex desktop log contains:

```text
only managed permission profiles can be enforced by the Windows sandbox
```

then the target user's `.codex\config.toml` probably contains `sandbox_mode = "danger-full-access"` or `approval_policy = "never"`. Re-run `20-copy-codex-session.ps1` without `-PreserveCodexAccessPolicy`, or edit the sidecar account config to:

```toml
sandbox_mode = "workspace-write"
approval_policy = "on-request"
```

Then fully exit and reopen Codex in the sidecar RDP session.

Second, check whether the Codex MSIX/AppX package is open in another Windows session.

On a machine where both the main console account and the RDP sidecar account are running Codex, Windows may log:

- `StoreAgentInstallFailure1`
- `Update;Codex-SearchForUpdatesWithPausedAddAsync`
- error code `80073d02`

That code usually means the package is in use and cannot be updated. Close Codex in every local and RDP session, wait for all `Codex.exe` and `codex.exe` processes to exit, then reopen one Codex instance and retry the update.

Useful checks:

```powershell
tasklist /v /fi "imagename eq Codex.exe"
tasklist /v /fi "imagename eq codex.exe"

Get-WinEvent -FilterHashtable @{
  LogName = "Application"
  StartTime = (Get-Date).AddHours(-2)
} | Where-Object {
  $_.Message -match "Codex-SearchForUpdatesWithPausedAddAsync|80073d02"
}
```

Codex desktop logs for MSIX installs are usually under:

```text
C:\Users\<user>\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\Codex\Logs
```

## Game Profile Copying

Game copying is manifest-driven. Review the manifest before running:

```json
{
  "directories": [
    {
      "source": "{SourceProfile}\\AppData\\Roaming\\com.funplus",
      "destination": "{TargetProfile}\\AppData\\Roaming\\com.funplus"
    }
  ],
  "registryKeys": [
    "HKCU\\Software\\Funplus",
    "HKCU\\Software\\funplus.sdk"
  ]
}
```

Only `HKCU` registry keys are supported by the copy script.

## Risk And Liability

Read [docs/security-notes.md](docs/security-notes.md).

By using these scripts, you accept responsibility for the security, legal, and operational consequences. The scripts are provided as-is under the MIT License.

## License

MIT. See [LICENSE](LICENSE).
