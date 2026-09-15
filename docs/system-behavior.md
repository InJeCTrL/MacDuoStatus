# System behavior verification

## Wi-Fi

Inspected macOS 26.6.2 (25G83), using the installed binary:

`/System/Library/CoreServices/ControlCenter.app/Contents/MacOS/ControlCenter`

SHA-256: `a3eed2b953cff36f44de8e1b6d9a579c7203425717ddb9503f8480796c6c971d`

The x86_64 RSSI call sites at `0x100402a6f` and `0x100403c4b` call
`0x1003f7fdd`. The matching arm64e conversion is at `0x10048ee1c`.
Both implement the following conversion for nonzero RSSI:

```text
x = RSSI + 77.5
quality = 0.5 + x / (2 * sqrt(x*x + 450))
bars = clamp(ceil(quality * 3), 0, 3)
```

arm64e constants at `0x1006f5350` are doubles `77.5, 450.0`;
`frintp` at `0x10048ee80` rounds toward positive infinity.
For integer negative RSSI: > -70 is three bars, > -85 is two, otherwise one.
The app deliberately treats RSSI 0 as unavailable rather than using the
conversion function's default of three bars; CoreWLAN documents 0 as an error
or an unassociated interface.

This reproduces the inspected conversion, not the ControlCenter process's
cached state or its complete connection-state UI. Wi-Fi events plus a one-second
poll reduce sampling delay but cannot guarantee frame-for-frame synchronization.
Future system versions may change the conversion. No private API is called.

Recheck using `xcrun llvm-objdump --macho --arch=arm64e --disassemble` on the
binary and inspect the conversion around the address above.

## MagSafe-style colors

Historical design research only: the current UI uses a monochrome system
template and does not apply charging colors. Power state remains visible in
the bottom horizontal plug indicator, tooltip, and menu. The solid plug indicates
external power, including charging pauses. The green preview mode has been removed.

Apple: https://support.apple.com/en-gb/102397

Apple documents amber for charging or charging on hold, green for fully charged.
No fixed percentage threshold is specified. This app uses the IOKit power source
state and `kIOPSIsChargedKey`, not a guessed percentage or the physical LED.
An attached but not fully charged battery remains amber even if charging pauses.
Charge-limit behavior depends on what the OS reports as fully charged.
The colors also apply to USB-C power; this is not MagSafe cable detection.
