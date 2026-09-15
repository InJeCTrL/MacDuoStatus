import AppKit
import CoreWLAN
import IOKit.ps
import SwiftUI
import CoreLocation

struct Status {
    var percent: Int?
    var charging = false
    var fullyCharged = false
    var pluggedIn = false
    var wifiOn = false
    var rssi = 0
    var ssid: String?
    var minutesToFull: Int?
    var lowPower = false
    var wifiAvailable = false
    var security: CWSecurity = .unknown

    var bars: Int {
        guard wifiOn, rssi < 0 else { return 0 }
        // ControlCenter's RSSI conversion (verified against the local system binary).
        let shifted = Double(rssi) + 77.5
        let quality = 0.5 + shifted / (2 * sqrt(shifted * shifted + 450))
        return min(3, max(0, Int(ceil(quality * 3))))
    }

    static func read() -> Status {
        var result = Status()
        result.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        if let wifi = CWWiFiClient.shared().interface() {
            result.wifiAvailable = true
            result.wifiOn = wifi.powerOn()
            result.rssi = wifi.rssiValue()
            result.ssid = wifi.ssid()
            result.security = wifi.security()
        }
        if let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
            for source in sources {
                guard let data = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                      data[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                      let current = data[kIOPSCurrentCapacityKey] as? Int,
                      let maximum = data[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { continue }
                result.percent = min(100, max(0, Int((Double(current) / Double(maximum) * 100).rounded())))
                result.charging = data[kIOPSIsChargingKey] as? Bool ?? false
                result.fullyCharged = data[kIOPSIsChargedKey] as? Bool ?? false
                result.pluggedIn = data[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
                if let minutes = data[kIOPSTimeToFullChargeKey] as? Int, minutes > 0 {
                    result.minutesToFull = minutes
                }
                break
            }
        }
        return result
    }

    var description: String {
        let battery = percent.map { "电量 \($0)% · \(charging ? "正在充电" : (pluggedIn ? (fullyCharged ? "已插电 · 已充满" : "已插电 · 未充电") : "使用电池"))" } ?? "未检测到内置电池"
        let wifi = !wifiOn ? "Wi-Fi 已关闭" : (bars == 0 ? "Wi-Fi 未连接或信号不可用" : "Wi-Fi \(bars)/3 格 · \(rssi) dBm")
        return "\(battery)\n\(wifi)"
    }

    var chargeDetail: String {
        guard percent != nil else { return "未检测到内置电池" }
        if fullyCharged { return "已充满" }
        if charging {
            return minutesToFull.map { "完全充满电还需 \($0) 分钟" } ?? "正在充电 · 正在估算剩余时间…"
        }
        return pluggedIn ? "电池未在充电" : "正在使用电池"
    }
}

enum DuoIcon {
    static func draw(_ status: Status, foreground: NSColor) -> NSImage {
        let powerColor = foreground
        let image = NSImage(size: NSSize(width: 28, height: 24), flipped: false) { _ in
            let transform = NSAffineTransform()
            transform.translateX(by: 2, yBy: 0)
            transform.scale(by: 1.09)
            transform.concat()
            let ringCenter = NSPoint(x: 11, y: 11)
            func ring(fraction: CGFloat, opacity: CGFloat) {
                guard fraction > 0 else { return }
                powerColor.withAlphaComponent(opacity).setStroke()
                let path = NSBezierPath()
                path.appendArc(withCenter: ringCenter, radius: 9, startAngle: 210,
                               endAngle: 210 - 240 * fraction, clockwise: true)
                path.lineWidth = 1.9
                path.lineCapStyle = .round
                path.stroke()
            }
            ring(fraction: 1, opacity: 0.18)
            ring(fraction: CGFloat(status.percent ?? 0) / 100, opacity: 1)

            let center = NSPoint(x: 11, y: 7.5)
            for index in 1...2 {
                foreground.withAlphaComponent(status.bars > index ? 1 : 0.2).setStroke()
                let arc = NSBezierPath()
                arc.appendArc(withCenter: center, radius: CGFloat(index) * 3.1, startAngle: 43, endAngle: 137)
                arc.lineWidth = 1.8
                arc.lineCapStyle = .round
                arc.stroke()
            }
            foreground.withAlphaComponent(status.bars > 0 ? 1 : 0.2).setFill()
            NSBezierPath(ovalIn: NSRect(x: center.x - 1.1, y: center.y - 1.1, width: 2.2, height: 2.2)).fill()
            if !status.wifiOn {
                let slash = NSBezierPath()
                slash.move(to: NSPoint(x: 7, y: 8))
                slash.line(to: NSPoint(x: 15, y: 14))
                slash.lineWidth = 1.2
                foreground.setStroke()
                slash.stroke()
            }
            foreground.withAlphaComponent(status.pluggedIn ? 1 : 0.28).setFill()
            // A horizontal plug uses the bottom gap without shrinking the Wi-Fi.
            let plug = NSBezierPath(roundedRect: NSRect(x: 8.8, y: 1.2, width: 4.4, height: 3.6),
                                    xRadius: 1.1, yRadius: 1.1)
            plug.append(NSBezierPath(roundedRect: NSRect(x: 5.5, y: 2.4, width: 3.7, height: 1.2),
                                     xRadius: 0.6, yRadius: 0.6))
            for y in [1.6, 3.2] {
                plug.append(NSBezierPath(roundedRect: NSRect(x: 12.8, y: y, width: 2.4, height: 1.2),
                                         xRadius: 0.4, yRadius: 0.4))
            }
            plug.windingRule = .nonZero
            let centerPlug = AffineTransform(translationByX: 0.65, byY: 0)
            plug.transform(using: centerPlug)
            plug.fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, CWEventDelegate, NSPopoverDelegate, CLLocationManagerDelegate {
    private var item: NSStatusItem!
    private var timer: Timer?
    private var status = Status()
    private let panel = PanelModel()
    private let popover = NSPopover()
    private let locationManager = CLLocationManager()
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var showPercent: Bool {
        get { UserDefaults.standard.object(forKey: "showPercent") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "showPercent") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        panel.showPercent = showPercent
        panel.onPercentChange = { [weak self] value in
            guard let self = self else { return }
            self.showPercent = value
            self.popover.performClose(nil)
            self.refresh()
        }
        panel.onWiFiChange = { [weak self] value in self?.setWiFi(value) }
        panel.onSettings = { [weak self] section in self?.openSettings(section) }
        locationManager.delegate = self
        popover.behavior = .transient
        popover.delegate = self
        let host = NSHostingController(rootView: StatusPanel(model: panel))
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
        refresh()
        let wifi = CWWiFiClient.shared()
        wifi.delegate = self
        for event: CWEventType in [.linkQualityDidChange, .powerDidChange, .linkDidChange] {
            try? wifi.startMonitoringEvent(with: event)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.refresh() }
        timer?.tolerance = 0.2
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refresh), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(closePanel), name: NSApplication.didResignActiveNotification, object: nil)
        if locationManager.authorizationStatus == .notDetermined {
            NSApp.activate(ignoringOtherApps: true)
            locationManager.requestWhenInUseAuthorization()
        }
    }

    @objc private func refresh() {
        status = Status.read()
        panel.status = status
        guard let button = item.button else { return }
        button.image = DuoIcon.draw(status, foreground: .black)
        button.imagePosition = .imageLeading
        button.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        // Keep the popover anchor stationary until it has closed.
        if !popover.isShown {
            button.title = showPercent ? status.percent.map { " \($0)%" } ?? " --" : ""
        }
        button.toolTip = status.description
        button.setAccessibilityLabel(status.description)
    }

    private func refreshFromWiFiEvent() {
        DispatchQueue.main.async { [weak self] in self?.refresh() }
    }

    func popoverDidClose(_ notification: Notification) {
        stopMonitoringOutsideClicks()
        refresh()
    }

    @objc private func closePanel() {
        if popover.isShown { popover.performClose(nil) }
    }

    private func startMonitoringOutsideClicks() {
        stopMonitoringOutsideClicks()
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: clicks) { [weak self] _ in
            self?.closePanel()
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: clicks) { [weak self] event in
            guard let self = self else { return event }
            if event.window != self.popover.contentViewController?.view.window,
               event.window != self.item.button?.window {
                self.closePanel()
            }
            return event
        }
    }

    private func stopMonitoringOutsideClicks() {
        if let monitor = globalClickMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localClickMonitor { NSEvent.removeMonitor(monitor) }
        globalClickMonitor = nil
        localClickMonitor = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if item != nil { refresh() }
    }

    func linkQualityDidChangeForWiFiInterface(withName interfaceName: String, rssi: Int, transmitRate: Double) {
        refreshFromWiFiEvent()
    }
    func powerStateDidChangeForWiFiInterface(withName interfaceName: String) { refreshFromWiFiEvent() }
    func linkDidChangeForWiFiInterface(withName interfaceName: String) { refreshFromWiFiEvent() }

    @objc private func togglePanel() {
        if popover.isShown { popover.performClose(nil); return }
        refresh()
        guard let button = item.button else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        startMonitoringOutsideClicks()
    }

    private func setWiFi(_ enabled: Bool) {
        panel.wifiBusy = true
        panel.error = nil
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var message: String?
            do {
                guard let wifi = CWWiFiClient.shared().interface() else {
                    throw NSError(domain: "DuoStatus", code: 1, userInfo: [NSLocalizedDescriptionKey: "未找到 Wi-Fi 接口"])
                }
                try wifi.setPower(enabled)
            } catch { message = error.localizedDescription }
            DispatchQueue.main.async {
                self?.panel.wifiBusy = false
                self?.panel.error = message
                self?.refresh()
            }
        }
    }

    private func openSettings(_ section: String) {
        popover.performClose(nil)
        let pane = section == "battery" ? "com.apple.preference.battery" : "com.apple.wifi-settings-extension"
        if let url = URL(string: "x-apple.systempreferences:\(pane)"), NSWorkspace.shared.open(url) { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
}

if CommandLine.arguments.contains("--self-test") {
    for (rssi, expected) in [(-100, 1), (-86, 1), (-85, 1), (-84, 2), (-71, 2), (-70, 2), (-69, 3), (-60, 3), (0, 0)] {
        var status = Status()
        status.wifiOn = true
        status.rssi = rssi
        precondition(status.bars == expected, "RSSI \(rssi): \(status.bars) != \(expected)")
        status.wifiOn = false
        precondition(status.bars == 0)
    }
    var battery = Status()
    precondition(battery.chargeDetail == "未检测到内置电池")
    battery.percent = 80
    battery.pluggedIn = true
    battery.charging = true
    battery.minutesToFull = 36
    precondition(battery.chargeDetail == "完全充满电还需 36 分钟")
    battery.minutesToFull = nil
    precondition(battery.chargeDetail.contains("估算"))
    battery.charging = false
    precondition(battery.chargeDetail == "电池未在充电")
    battery.fullyCharged = true
    precondition(battery.chargeDetail == "已充满")
    print("PASS: Wi-Fi boundaries and battery panel states")
} else if CommandLine.arguments.contains("--diagnose") {
    print(Status.read().description)
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
