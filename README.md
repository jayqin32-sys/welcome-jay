# Welcome Jay

Welcome Jay 是一款为 macOS 版 ChatGPT 添加手写开场动画的菜单栏应用。每当 ChatGPT 完全退出后重新启动，约 8.5 秒的动画会在它的窗口上播放。彩色笔迹写出 “Welcome Jay”，延伸为图标，再淡出露出 ChatGPT 界面。

这是独立的社区项目。动画使用 Swift、AppKit 和 Core Graphics 在本地绘制，ChatGPT 应用本身无需修改。

## 下载与安装

**系统要求**：Apple 芯片的 Mac、macOS 13 或更新版本，已安装 ChatGPT 桌面客户端。

1. 下载 [Welcome-Jay-Mac.zip](https://github.com/jayqin32-sys/welcome-jay/raw/refs/heads/main/Welcome-Jay-Mac.zip)，也可以在 [Releases](https://github.com/jayqin32-sys/welcome-jay/releases) 查看版本说明。
2. 解压后，把 `Welcome Jay.app` 拖到「应用程序」，双击打开。运行后，菜单栏会出现一个 ✨ 图标。
3. 在 ChatGPT 窗口按 **⌘Q** 完全退出，再从 Dock 或「应用程序」打开 ChatGPT。

发布包使用临时签名，未经过 Apple 公证。确认下载来源和文件校验值后，若 macOS 阻止首次打开，可以按 [Apple 的说明](https://support.apple.com/zh-cn/102445) 在「系统设置 → 隐私与安全性」为这一个应用选择「仍要打开」。

安装包的 SHA-256：

```text
cd03344b5fb37ae845583bd7f3ae5b290aa43419f223ccd5cf498cf3d7bbc9c5
```

## 日常使用

- **重播动画**：保持 Welcome Jay 运行，用 **⌘Q** 退出 ChatGPT 后重新打开。点击窗口左上角的红色关闭按钮通常只会关闭窗口。
- **开机登录后自动运行**：点击菜单栏 ✨，选择「登录后自动运行」。如系统要求批准，可从菜单打开登录项设置。
- **卸载**：先取消「登录后自动运行」，再从菜单退出 Welcome Jay，最后将应用拖到废纸篓。

## 从源码构建

在 Apple 芯片的 Mac 上安装 Xcode 或 Command Line Tools。打开终端并运行：

```bash
git clone https://github.com/jayqin32-sys/welcome-jay.git
cd welcome-jay
bash build.sh
open "build/Welcome Jay.app"
```

| 文件 | 用途 |
| --- | --- |
| `WelcomeApp.swift` | 菜单栏、登录项、ChatGPT 启动监听与动画窗口 |
| `Scene.swift` | 手写笔迹、动画编排和应用图标绘制 |
| `RenderIcon.swift` | 从绘制代码生成图标 PNG 的入口 |
| `Info.plist` | macOS 应用配置 |
| `WelcomeJay.icns` | 打包使用的应用图标 |

动画若能读取当前 Mac 自带的欢迎字样笔迹，会使用该笔迹渲染，系统资源不可用时会使用项目内置的路径。仓库中的 MIT 许可证适用于本项目代码。系统资源随 macOS 提供。

## 许可证

[MIT](LICENSE)
