# 在另一台 Windows 电脑复刻流程

[English](replicate-on-another-windows-pc.md)

这个文档用于把当前这套 Codex RDP sidecar 流程迁移到另一台本地 Windows 电脑。

## 给目标电脑 Codex 的提示词

前置条件准备好后，把下面这段复制给目标电脑上的 Codex：

```text
请使用 codex-rdp-sidecar 工具，把这台 Windows 电脑配置成 Codex RDP sidecar 机器。

仓库或压缩包解压路径：
<在这里填 clone 后的 repo 路径，或 zip 解压路径>

目标 sidecar 账户：
- 用户名：codex
- 密码：<选择一个本地密码>
- 是否本地管理员：是；这是我的个人电脑，我接受风险

游戏路径：
E:\FunPlus\Foundation Galactic Frontier

要求：
- 使用管理员 PowerShell 执行脚本。
- 创建或修复 sidecar 用户。
- 复制我指定的 Codex session、Codex 宠物和游戏配置。
- sidecar 账户的 Codex 沙盒策略保持 workspace-write/on-request，不要保留 danger-full-access。
- 使用我下载好的 rdpWrapper.exe 安装/配置 RDP Wrapper。
- 生成签名的桌面 Codex.rdp，明确提供密码时才保存凭据，使用 150% 缩放，并尽量保证最大化时没有滚动条。
- 验证 RDP、TermService/RDP Wrapper 状态，以及 Codex 沙盒可用性。
- 关闭 RDP 警告或复制 auth/state 文件前，先说明风险。
```

## 人工前置条件

在目标电脑上先处理这些：

- Windows 10/11 Pro、Enterprise、Education 或 Pro for Workstations。
- 只在内网或 VPN 使用，不要把 RDP 直接暴露到公网。
- 当前登录用户可以运行管理员 PowerShell。
- 开启 Windows sudo，或者准备手动使用管理员 PowerShell。
- 如果想要同样的无提示实验机流程，关闭 UAC 或确认提升过程不会卡住。
- 主用户里安装并登录 Codex Desktop。
- 单独下载 RDP Wrapper：<https://github.com/sergiye/rdpWrapper>。
- 查看 RDP Wrapper 当前 Windows 兼容性，尤其是 <https://github.com/sergiye/rdpWrapper/issues/27>。
- 想清楚是否复制 Codex auth/state 文件；它们可能包含可复用凭据或 token。

## 转移方式

如果目标电脑 GitHub SSH 免密可用，推荐直接 clone：

```powershell
Set-Location H:\Codex
git clone git@github.com:David-Lzy/codex-rdp-sidecar.git
Set-Location H:\Codex\codex-rdp-sidecar
```

如果目标电脑没有配 GitHub SSH，就复制准备好的 zip，解压后在解压目录里运行命令。

## 标准命令顺序

运行前修改路径、密码、session ID 和 RDP Wrapper 路径。

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

如果要关掉新版“未知 .rdp 发布者”警告，优先使用 `50-create-rdp-launcher.ps1` 输出的证书 thumbprint：

```powershell
.\scripts\60-disable-rdp-warning.ps1 -TrustedCertThumbprint "<thumbprint>"
```

只有在你接受更大风险时才使用 `-AllowUnsignedFiles`。

## 重要沙盒说明

不要把 `danger-full-access` 复制到 sidecar 账户，除非你明确想禁用可管理沙盒约束。

`20-copy-codex-session.ps1` 现在默认会把 sidecar 账户规范化成：

```toml
sandbox_mode = "workspace-write"
approval_policy = "on-request"
```

这可以避免 Codex Desktop 错误：

```text
only managed permission profiles can be enforced by the Windows sandbox
```

改完配置后，需要完全退出 RDP 里的 Codex，再重新打开。

## 检查命令

常用进程和日志检查：

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

MSIX 安装的 Codex Desktop 日志通常在：

```text
C:\Users\<user>\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache\Local\Codex\Logs
```

## 风险提醒

这套配置会创建另一个可交互登录入口，可能保存 RDP 凭据，可能复制 Codex auth/state，并依赖第三方 RDP Wrapper 的兼容性。只在你接受这些风险的机器上使用。
