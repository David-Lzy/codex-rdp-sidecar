# RDP Wrapper Notes

This project does not vendor or redistribute RDP Wrapper binaries.

Use the upstream project:

- Repository: <https://github.com/sergiye/rdpWrapper>
- Relevant issue for the June 2026 breakage: <https://github.com/sergiye/rdpWrapper/issues/27>

## What The Script Does

`scripts/40-install-rdpwrap.ps1` expects a downloaded `rdpWrapper.exe` path.
It runs:

```powershell
rdpWrapper.exe -install -offline
```

Then it configures local Remote Desktop policy:

- `fDenyTSConnections = 0`
- `fSingleSessionPerUser = 0`
- policy `MaxConnections = 999999`
- `RDP-Tcp\MaxInstanceCount = 0xffffffff`

It also restarts `TermService` unless `-SkipServiceRestart` is used.

## What The Script Does Not Do

- It does not patch `C:\Windows\System32\termsrv.dll`.
- It does not bypass Windows licensing for a business or production environment.
- It does not make RDP safe to expose to the public internet.

RDP Wrapper is an external dependency. Review its source, release notes, and issue tracker before using it.

