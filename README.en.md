# Duo Status

[简体中文](README.md) | **English**

[![Build and Release](https://github.com/InJeCTrL/MacDuoStatus/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/InJeCTrL/MacDuoStatus/actions/workflows/build.yml)

A native macOS menu bar app combining Wi-Fi signal, battery level, and power status in one icon.

<img src="docs/assets/icon-demo.gif" width="440" alt="Battery, power, and Wi-Fi signal demo">

<details>
<summary>View the menu panel demo</summary>

<img src="docs/assets/menu-demo.gif" width="370" alt="Battery and Wi-Fi menu panel demo">

</details>

*Animations use the actual UI components with simulated data, not live device readings.*

## Install

1. Download `MacDuoStatus-universal.zip` from [Releases](https://github.com/InJeCTrL/MacDuoStatus/releases/latest).
2. Extract it, move `Duo Status.app` to Applications, and launch it.
3. Allow Location Services on first launch to display the Wi-Fi network name. The app does not collect or upload your location.

The app requests location permission at startup when the system authorization status is not determined. It does not request again if permission is already granted or denied. You can change it in **System Settings > Privacy & Security > Location Services**.

Requires macOS 13 or later. Supports Apple Silicon and Intel. The app is not notarized; if macOS blocks it, verify the download source and choose **Open Anyway** in **System Settings > Privacy & Security**.

Development builds: open the latest successful main-branch run in [Actions](https://github.com/InJeCTrL/MacDuoStatus/actions/workflows/build.yml?query=branch%3Amain) and download **Artifacts > MacDuoStatus-universal** (GitHub sign-in required). Version tags publish stable builds to Releases.

## Use

- The outer ring shows battery level; the center shows Wi-Fi signal. A solid plug means external power, and a dim plug means battery power.
- Click the icon for battery and network details, the Wi-Fi switch, and the battery percentage option.
- Command-drag the icon to reposition it. You can hide the system battery and Wi-Fi icons in System Settings.
- Launch at login is requested by default and can be disabled in the menu. If macOS requires approval, allow the app in Login Items.

Background updates are event-driven, and the icon redraws only when its visual state changes. Wi-Fi bars may differ from the system icon across macOS versions or sampling times. The app interface is currently in Simplified Chinese.

## Build from source

Install Xcode Command Line Tools, then run:

```sh
zsh build.sh
open "build/Duo Status.app"
```

See [development notes](docs/development.md) for universal builds, tests, and releases. License: [GPL-3.0](LICENSE).
