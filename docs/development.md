# Development

## Build and test

Requires macOS 13+ and Xcode Command Line Tools. No third-party dependencies.

```sh
UNIVERSAL=1 zsh build.sh
"build/Duo Status.app/Contents/MacOS/DuoStatusIcon" --self-test
"build/Duo Status.app/Contents/MacOS/DuoStatusIcon" --diagnose
```

Without `UNIVERSAL=1`, the build targets the host architecture. Set `VERSION=X.Y.Z`
to override the bundle version. Builds are ad-hoc signed, not notarized.

## GitHub Actions

Pushes to `main`, pull requests, and manual dispatch build and test a universal app.
Actions artifacts contain the ZIP and SHA-256 checksum. Pushing a new `vX.Y.Z` tag
also publishes those assets to Releases using the built-in `GITHUB_TOKEN`.

## Update policy

- CoreWLAN events report power, connection, and signal changes.
- RSSI events update signal state directly without rereading battery information.
- IOKit power-source notifications refresh battery data immediately, without
  waiting for Wi-Fi queries.
- Bursts of full-refresh events are coalesced over 150 ms.
- A fallback poll runs every 30 seconds with the panel closed, or every 5 seconds
  with it open. If event registration fails, the fallback is 5 seconds.
- While the visible menu is waiting for a charging estimate, battery-only polling
  runs every second for up to 90 seconds. Until the OS supplies an estimate, the
  menu simply says it is charging; it does not invent a remaining time.
- SSID and security details are read only when the panel opens or updates while
  visible. Hidden SwiftUI content is not republished on every background update.
- Image regeneration is keyed by battery percentage, external power, Wi-Fi power,
  and signal bars; RSSI changes within the same bar range do not redraw the icon.
- Timers stop during system sleep; wake triggers an immediate refresh.
- The panel is hosted in a native NSMenu, so menu tracking manages full-screen
  menu-bar visibility and dismissal. Timers run in common run-loop modes to keep
  battery information updating during menu tracking.

For a lightweight CPU comparison, sample the app with the panel closed using:

```sh
top -l 11 -s 3 -pid "$(pgrep -x DuoStatusIcon)" -stats pid,command,cpu,time,mem,idlew
```

Discard the first CPU sample. This measures process activity, not watts or battery
life. For a stronger comparison, use the same workload and duration, and compare
both open and closed panels. Sleep, charging transitions, and network changes
also need real-device validation.
