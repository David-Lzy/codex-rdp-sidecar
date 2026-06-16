# codex-rdp-sidecar

[English README](README.md)

这个项目用于在本地 Windows 机器上创建一个隔离的 RDP sidecar 账户，让 Codex 或游戏自动化运行在另一个交互式桌面会话里，避免抢占主账户的窗口焦点。

默认场景是个人家用机或实验机。请自行承担风险。

## 前置条件

- Windows 10/11 Pro、Enterprise、Education 或 Pro for Workstations。
- 本地管理员权限。
- Windows sudo 已启用，或者你手动使用管理员 PowerShell。
- 如果想要无提示自动化流程，建议在家用/实验机上关闭 UAC，或确认提升流程不会卡住。
- 单独下载 RDP Wrapper：<https://github.com/sergiye/rdpWrapper>。
- Windows 自带 `rdpsign.exe`，用于签名 `.rdp` 文件。
- 只在内网或 VPN 环境使用，不要直接暴露到公网。

2026 年 6 月 Windows 更新后 RDP Wrapper 2.14 多用户失效的问题见：

<https://github.com/sergiye/rdpWrapper/issues/27>

## 能做什么

- 创建本地 sidecar 用户。
- 将用户加入 `Remote Desktop Users`，可选加入 `Administrators`。
- 初始化目标用户 profile。
- 复制指定 Codex session/config。
- 可选复制 Codex auth/state 文件。
- 可选复制本地 Codex 宠物资源。
- 通过 manifest 复制游戏配置目录和 `HKCU` 注册表键。
- 使用外部 `rdpWrapper.exe` 安装/配置 RDP Wrapper。
- 配置 `TermService` 多会话策略。
- 生成桌面 `.rdp` 文件。
- 可选用 `cmdkey` 保存 RDP 凭据。
- 用本地证书签名 `.rdp` 文件。
- 可选关闭新版“未知 .rdp 发布者”安全提示。

## 不做什么

- 不 patch `termsrv.dll` 二进制文件。
- 不分发 RDP Wrapper。
- 不保证 Windows 更新后永远可用。
- 不保证任何公网 RDP 安全性。
- 不替你承担系统安全、软件授权、游戏账号或法律/政策风险。

## 快速使用

除特别说明外，在管理员 PowerShell 中运行：

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

更稳妥的方式是签名 `.rdp`，再把证书 thumbprint 加入信任，而不是允许所有 unsigned `.rdp`：

```powershell
.\scripts\60-disable-rdp-warning.ps1 -TrustedCertThumbprint "<thumbprint>"
```

## 经常改 RDP 配置怎么办

`.rdp` 文件一旦编辑，签名会失效。改完后重新运行：

```powershell
.\scripts\50-create-rdp-launcher.ps1 `
  -RdpPath "$env:USERPROFILE\Desktop\Codex.rdp" `
  -FullAddress 127.0.0.20 `
  -UserName "$env:COMPUTERNAME\codex" `
  -Password "change-this-password" `
  -SaveCredential `
  -Sign
```

## RDP 分辨率和缩放

`50-create-rdp-launcher.ps1` 默认使用一套在 4K 级本地显示器上更实用的 sidecar 配置：

- `desktopwidth:i:3840`
- `desktopheight:i:2060`
- `smart sizing:i:1`
- `dynamic resolution:i:0`
- `desktopscalefactor:i:150`
- `devicescalefactor:i:100`

这套配置优先保证 RDP 窗口最大化时没有横向/纵向滚动条。`smart sizing` 的本质是缩放远端画布；如果本地 RDP 客户区和远端桌面尺寸没有完全一致，就不能保证点对点清晰。真正点对点要求远端分辨率刚好等于本地 RDP 客户区大小。

理论上 `dynamic resolution:i:1` 更理想，因为远端桌面会跟随客户端窗口大小变化；但在 RDP Wrapper 或改造后的 `TermService` 链路上可能不生效。只有在你确认本机支持时才使用 `-EnableDynamicResolution`。

## 关于 Codex session

默认只复制基础配置。敏感文件必须显式打开：

- `-IncludeAuth`：复制 `auth.json` 等认证相关文件。
- `-IncludeState`：复制本地 Codex SQLite 状态。
- `-IncludePets`：复制 `.codex\pets` 本地宠物资源。
- `-MoveSession`：复制后删除源 session 文件，会触发 PowerShell 确认语义。

不要把复制出来的 `.codex` 数据提交到 git。

## Codex Agent 沙盒更新失败

如果 sidecar 账户里出现“无法更新 Agent 沙盒”，先检查是不是同一个 Codex MSIX/AppX 包同时被主账户和 RDP 账户占用。

当主账户和 RDP sidecar 账户同时运行 Codex 时，Windows 事件日志里可能出现：

- `StoreAgentInstallFailure1`
- `Update;Codex-SearchForUpdatesWithPausedAddAsync`
- 错误码 `80073d02`

这个错误通常表示包正在使用中，Windows 不能替换更新文件。处理方式是关闭所有本地和 RDP 会话里的 Codex，等待 `Codex.exe` 和 `codex.exe` 全部退出，然后只打开一个 Codex 实例并重试更新。

排查命令：

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

## 关于游戏配置

游戏配置通过 JSON manifest 控制。运行前必须检查路径和注册表键。

示例文件：`profiles/foundation-galactic-frontier.example.json`

当前脚本只支持复制 `HKCU` 注册表键。

## 风险和责任

请阅读 [docs/security-notes.md](docs/security-notes.md)。

使用这些脚本代表你接受相应安全、法律和操作风险。项目按 MIT License 以 as-is 形式提供。

## License

MIT。见 [LICENSE](LICENSE)。
