# Security Notes

This repository is intended for a personal lab or home machine where the operator accepts the tradeoffs.

## High-Risk Choices

- Creating a local automation account may create another login path into the machine.
- Making that account an administrator increases blast radius.
- Saving RDP credentials with `cmdkey` stores reusable credentials in Windows Credential Manager.
- Copying `.codex/auth.json` or Codex state may copy API/session credentials.
- Copying game profile folders or `HKCU` registry keys may transfer account tokens and private game state.
- Disabling the new `.rdp` redirection warning reduces a safety prompt that helps detect malicious `.rdp` files.
- RDP Wrapper is third-party software and may be flagged by security products.

## Operator Responsibility

You are responsible for:

- knowing whether this is legal and acceptable for your Windows edition and use case
- keeping RDP off the public internet
- using a strong password if the machine is reachable by other people
- reviewing every copied path and registry key
- deleting or rotating credentials if a sidecar account is no longer needed
- understanding that scripts may break after Windows updates

## Safer Defaults

- Use a non-admin sidecar account unless your automation genuinely needs elevation.
- Copy only one required Codex session first.
- Do not copy `auth.json` unless you understand the credential implications.
- Keep `.rdp` files signed instead of globally allowing unsigned files where possible.
- Prefer LAN-only or VPN-only access.

## Cleanup Checklist

```powershell
Remove-LocalUser codex
cmdkey /delete:TERMSRV/127.0.0.20
Remove-Item "C:\Users\codex" -Recurse -Force
```

Only remove a user profile after confirming no needed files remain.

