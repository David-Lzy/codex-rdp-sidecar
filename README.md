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

## What This Automates

- Creates a local sidecar user, optionally with local administrator rights.
- Adds the user to `Remote Desktop Users`.
- Initializes the sidecar user profile.
- Copies selected Codex session/config files into the sidecar profile.
- Optionally copies Codex auth/state files when explicitly requested.
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

## Codex Session Copying

`20-copy-codex-session.ps1` copies only basic config by default. You must explicitly opt in to sensitive files:

- `-IncludeAuth` copies `auth.json` and browser/native-host related files.
- `-IncludeState` copies local Codex state SQLite files.
- `-MoveSession` removes the source session file after copying and uses PowerShell confirmation semantics.

Do not commit copied `.codex` data.

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
