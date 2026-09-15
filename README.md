# Duo Status

[![Build and Release](https://github.com/InJeCTrL/MacDuoStatus/actions/workflows/build.yml/badge.svg)](https://github.com/InJeCTrL/MacDuoStatus/actions/workflows/build.yml)

[下载最新版本](https://github.com/InJeCTrL/MacDuoStatus/releases/latest) · macOS 13+ · Apple Silicon / Intel

原生 macOS 菜单栏小工具：外圈电量弧线 + 中心 Wi-Fi + 底部横向插头供电指示。全图使用系统单色模板，自动适配浅色 / 深色菜单栏。外圈亮起的长度表示实际电量，底部插头插电时实色，未插电时保留淡色形状（28% 不透明度），布局不变。实色插头表示外部供电，不保证电池正在充电；充电及充满状态可在悬停提示和菜单查看，默认不显示百分比。

## 构建与运行

需要 macOS 13+ 和 Xcode Command Line Tools，无第三方依赖。

```sh
zsh build.sh
open "build/Duo Status.app"
```

构建双架构通用包：`UNIVERSAL=1 zsh build.sh`。

## 自动构建与发布

- 推送 `main`、提交 PR 或手动运行 Actions：构建、测试并生成下载产物。
- 推送 `vX.Y.Z` 标签：自动构建通用 App，生成 ZIP 与 SHA-256 校验文件，发布到 GitHub Releases。
- 发布不需要额外 secrets，使用工作流内置 `GITHUB_TOKEN`。产物是临时签名，未公证。

```sh
git tag -a v0.1.0 -m "Release v0.1.0"
git push origin v0.1.0
```

可将 App 拖入「应用程序」。需要开机启动时，可在系统设置的「登录项」中手动添加。

## 使用

- 点击图标打开原生半透明面板，按电池 / Wi-Fi 分区展示信息。
- 电池区显示电量、供电来源、系统预计充满时间和低电量模式状态；点击能耗模式或电池设置可进入系统设置。
- Wi-Fi 区提供真实开关、当前网络、安全性提示及 RSSI。开关失败会显示错误，不会伪造成功状态。
- 首次启动、定位权限尚未决定时自动请求授权，以读取 Wi-Fi 网络名称；已拒绝时不重复弹窗，可在系统设置的「隐私与安全性 → 定位服务」中修改。不调用位置更新、不采集或上传坐标，不扫描周边网络，也不提供耗能 App 或已知网络列表。
- 点击「显示电量百分比」会保存选项并自动收起面板，再更新状态栏宽度；再次打开时，启用的选项前显示勾选标记。
- 菜单可切换电量百分比，设置会保留。
- Wi-Fi 变化事件触发刷新，每 1 秒轮询兜底；唤醒和打开菜单时立即刷新。
- 按住 Command 拖动图标可调整菜单栏位置。系统自带的 Wi-Fi / 电池图标需要自行在系统设置中隐藏；本应用不修改系统配置。
- Wi-Fi 使用本机 macOS ControlCenter 的 RSSI 换算公式，见 `docs/system-behavior.md`。同一有效 RSSI 对应相同格数，但不是直接镜像系统图标，事件与采样时刻仍可能存在短暂差异。这不是网络速度或互联网连通性检测。
- 无内置电池时显示 `--`；Wi-Fi 未关联或无法读取信号时显示灰色信号。无需 SSID、定位权限或扫描周边网络。

## 诊断

```sh
"build/Duo Status.app/Contents/MacOS/DuoStatusIcon" --diagnose
"build/Duo Status.app/Contents/MacOS/DuoStatusIcon" --self-test
```

使用 Apple CoreWLAN 和 IOKit 公共接口。构建产物仅本地临时签名，未做 Developer ID 签名或公证。当前图案是 Duo 风格的独立实现，并非参考图的像素级复刻。
