# Duo Status

**简体中文** | [English](README.en.md)

[![Build and Release](https://github.com/InJeCTrL/MacDuoStatus/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/InJeCTrL/MacDuoStatus/actions/workflows/build.yml)

将 Wi-Fi 信号、电池电量和供电状态合并为一个 macOS 菜单栏图标。

## 安装

1. 从 [Releases](https://github.com/InJeCTrL/MacDuoStatus/releases/latest) 下载 `MacDuoStatus-universal.zip`。
2. 解压，将 `Duo Status.app` 拖入「应用程序」并打开。
3. 首次启动允许定位权限，以显示 Wi-Fi 网络名称；不采集或上传地理位置。

支持 macOS 13+，兼容 Apple Silicon 和 Intel。目前未做 Apple 公证；若启动被阻止，确认下载来源后，在「系统设置 → 隐私与安全性」中选择「仍要打开」。

开发版：[Actions](https://github.com/InJeCTrL/MacDuoStatus/actions/workflows/build.yml?query=branch%3Amain) 中最新成功构建的 **Artifacts → MacDuoStatus-universal**（下载需登录 GitHub）。正式版在推送版本标签后发布到 Releases。

## 使用

- 外圈长度表示电量，中间显示 Wi-Fi 信号；底部插头实色表示接入电源，淡色表示使用电池。
- 点击图标查看电池和网络详情、开关 Wi-Fi，或切换电量百分比。
- 按住 Command 拖动图标调整位置；系统自带的电池、Wi-Fi 图标可自行在系统设置中隐藏。
- 需要开机启动，可在系统设置的「登录项」中添加本应用。

后台以系统事件驱动更新，仅在图标状态变化时重绘。Wi-Fi 格数可能因系统版本或采样时刻而与系统图标略有差异。

## 源码构建

安装 Xcode Command Line Tools 后运行：

```sh
zsh build.sh
open "build/Duo Status.app"
```

通用构建、测试及发布流程见 [开发说明](docs/development.md)。许可证：[GPL-3.0](LICENSE)。
