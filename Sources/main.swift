import AppKit
import CoreWLAN
import IOKit.ps
import SwiftUI
import CoreLocation

struct Status: Equatable {
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
    var interfaceName: String?
    var security: CWSecurity = .unknown

    var bars: Int {
        guard wifiOn, rssi < 0 else { return 0 }
        // ControlCenter's RSSI conversion (verified against the local system binary).
        let shifted = Double(rssi) + 77.5
        let quality = 0.5 + shifted / (2 * sqrt(shifted * shifted + 450))
        return min(3, max(0, Int(ceil(quality * 3))))
    }

    static func read(includeDetails: Bool = true, keepingWiFiFrom cached: Status? = nil) -> Status {
        var result = cached ?? Status()
        result.percent = nil
        result.charging = false
        result.fullyCharged = false
        result.pluggedIn = false
        result.minutesToFull = nil
        result.lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        if cached == nil, let wifi = CWWiFiClient.shared().interface() {
            result.wifiAvailable = true
            result.interfaceName = wifi.interfaceName
            result.wifiOn = wifi.powerOn()
            result.rssi = wifi.rssiValue()
            if includeDetails {
                result.ssid = wifi.ssid()
                result.security = wifi.security()
            }
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
                if let minutes = data[kIOPSTimeToFullChargeKey] as? Int, minutes >= 0 {
                    result.minutesToFull = minutes
                }
                break
            }
        }
        return result
    }

    var description: String {
        let battery = percent.map { "电量 \($0)% · \(displayFullyCharged ? "已充满" : (charging ? "正在充电" : (pluggedIn ? "已插电 · 未充电" : "使用电池")))" } ?? "未检测到内置电池"
        let wifi = !wifiOn ? "Wi-Fi 已关闭" : (bars == 0 ? "Wi-Fi 未连接或信号不可用" : "Wi-Fi \(bars)/3 格 · \(rssi) dBm")
        return "\(battery)\n\(wifi)"
    }

    var displayFullyCharged: Bool {
        fullyCharged || (pluggedIn && percent == 100 && minutesToFull == 0)
    }

    var chargeDetail: String {
        guard percent != nil else { return "未检测到内置电池" }
        if displayFullyCharged { return "已充满" }
        if charging {
            if minutesToFull == 0 { return "正在完成充电" }
            return minutesToFull.map { "完全充满电还需 \($0) 分钟" } ?? "正在充电"
        }
        return pluggedIn ? "电池未在充电" : "正在使用电池"
    }
}

struct IconState: Equatable {
    let percent: Int?
    let pluggedIn: Bool
    let wifiOn: Bool
    let bars: Int

    init(_ status: Status) {
        percent = status.percent
        pluggedIn = status.pluggedIn
        wifiOn = status.wifiOn
        bars = status.bars
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

final class AppDelegate: NSObject, NSApplicationDelegate, CWEventDelegate, NSMenuDelegate, CLLocationManagerDelegate {
    private var item: NSStatusItem!
    private var timer: Timer?
    private var status = Status()
    private let panel = PanelModel()
    private let menu = NSMenu()
    private var menuVisible = false
    private var menuHost: NSView?
    private let locationManager = CLLocationManager()
    private var renderedIcon: IconState?
    private var pendingRefresh: DispatchWorkItem?
    private var powerSource: CFRunLoopSource?
    private var sleeping = false
    private var fallbackInterval: TimeInterval = 30
    private var estimateWaitStarted: Date?
    private var timerInterval: TimeInterval?
    private var showPercent: Bool {
        get { UserDefaults.standard.object(forKey: "showPercent") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "showPercent") }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        panel.showPercent = showPercent
        panel.onPercentChange = { [weak self] value in
            guard let self = self else { return }
            self.showPercent = value
            self.closePanel()
            self.renderStatus()
        }
        panel.onWiFiChange = { [weak self] value in self?.setWiFi(value) }
        panel.onSettings = { [weak self] section in self?.openSettings(section) }
        locationManager.delegate = self
        menu.delegate = self
        menu.autoenablesItems = false
        let host = NSHostingView(rootView: StatusPanel(model: panel).environment(\.controlActiveState, .active))
        host.setFrameSize(host.fittingSize)
        menuHost = host
        let content = NSMenuItem()
        content.view = host
        menu.addItem(content)
        item.menu = menu
        item.button?.imagePosition = .imageLeading
        item.button?.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        refresh()
        let wifi = CWWiFiClient.shared()
        wifi.delegate = self
        for event: CWEventType in [.linkQualityDidChange, .powerDidChange, .linkDidChange] {
            do { try wifi.startMonitoringEvent(with: event) }
            catch { fallbackInterval = 5 }
        }
        powerSource = IOPSNotificationCreateRunLoopSource({ context in
            guard let context = context else { return }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            delegate.refreshBattery()
        }, Unmanaged.passUnretained(self).toOpaque())?.takeRetainedValue()
        if let source = powerSource { CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes) }
        else { fallbackInterval = 5 }
        configureTimer()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(didWake), name: NSWorkspace.didWakeNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(willSleep), name: NSWorkspace.willSleepNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(powerModeChanged), name: .NSProcessInfoPowerStateDidChange, object: nil)
        if locationManager.authorizationStatus == .notDetermined {
            NSApp.activate(ignoringOtherApps: true)
            locationManager.requestWhenInUseAuthorization()
        }
    }

    @objc private func refresh() {
        refresh(includeDetails: menuVisible)
    }

    private func refresh(includeDetails: Bool) {
        guard !sleeping else { return }
        pendingRefresh?.cancel()
        pendingRefresh = nil
        status = Status.read(includeDetails: includeDetails)
        publishStatus(includeDetails: includeDetails)
    }

    private func refreshBattery() {
        guard !sleeping else { return }
        status = Status.read(includeDetails: false, keepingWiFiFrom: status)
        publishStatus(includeDetails: menuVisible)
    }

    private func publishStatus(includeDetails: Bool) {
        if status.charging && status.minutesToFull == nil && !status.displayFullyCharged {
            if estimateWaitStarted == nil { estimateWaitStarted = Date() }
        } else { estimateWaitStarted = nil }
        if includeDetails && panel.status != status { panel.status = status }
        renderStatus()
        configureTimer()
    }

    private func renderStatus() {
        guard let button = item.button else { return }
        let iconState = IconState(status)
        if renderedIcon != iconState {
            button.image = DuoIcon.draw(status, foreground: .black)
            renderedIcon = iconState
        }
        // Keep the menu anchor stationary until tracking has ended.
        if !menuVisible {
            let title = showPercent ? status.percent.map { " \($0)%" } ?? " --" : ""
            if button.title != title { button.title = title }
        }
        let description = status.description
        if button.toolTip != description {
            button.toolTip = description
            button.setAccessibilityLabel(description)
        }
    }

    private func refreshFromWiFiEvent() {
        DispatchQueue.main.async { [weak self] in self?.queueRefresh() }
    }

    private func queueRefresh() {
        guard !sleeping, pendingRefresh == nil else { return }
        let work = DispatchWorkItem { [weak self] in self?.refresh() }
        pendingRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    private func configureTimer() {
        guard !sleeping else {
            timer?.invalidate()
            timer = nil
            timerInterval = nil
            return
        }
        let awaitingEstimate = estimateWaitStarted.map { Date().timeIntervalSince($0) < 90 } ?? false
        let interval: TimeInterval = menuVisible ? (awaitingEstimate ? 1 : 5) : fallbackInterval
        guard timerInterval != interval else { return }
        timer?.invalidate()
        timerInterval = interval
        timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.menuVisible && self.timerInterval == 1 { self.refreshBattery() }
            else { self.refresh() }
        }
        timer?.tolerance = interval * 0.2
        if let timer = timer { RunLoop.main.add(timer, forMode: .common) }
    }

    @objc private func willSleep() {
        sleeping = true
        pendingRefresh?.cancel()
        pendingRefresh = nil
        closePanel()
        configureTimer()
    }

    @objc private func didWake() {
        sleeping = false
        refresh()
        configureTimer()
    }

    @objc private func powerModeChanged() { queueRefresh() }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        pendingRefresh?.cancel()
        if let source = powerSource { CFRunLoopSourceInvalidate(source) }
        try? CWWiFiClient.shared().stopMonitoringAllEvents()
    }

    func menuWillOpen(_ menu: NSMenu) {
        menuVisible = true
        refresh(includeDetails: true)
        if let host = menuHost { host.setFrameSize(host.fittingSize) }
        configureTimer()
    }

    func menuDidClose(_ menu: NSMenu) {
        menuVisible = false
        DispatchQueue.main.async { [weak self] in self?.renderStatus() }
        configureTimer()
    }

    private func closePanel() {
        if menuVisible { menu.cancelTracking() }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if item != nil { refresh() }
    }

    func linkQualityDidChangeForWiFiInterface(withName interfaceName: String, rssi: Int, transmitRate: Double) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, !self.sleeping else { return }
            guard self.status.interfaceName == interfaceName else { return }
            guard self.status.rssi != rssi else { return }
            self.status.rssi = rssi
            self.renderStatus()
            if self.menuVisible && self.panel.status != self.status { self.panel.status = self.status }
        }
    }
    func powerStateDidChangeForWiFiInterface(withName interfaceName: String) { refreshFromWiFiEvent() }
    func linkDidChangeForWiFiInterface(withName interfaceName: String) { refreshFromWiFiEvent() }

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
        closePanel()
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
    precondition(battery.chargeDetail == "正在充电")
    battery.charging = false
    precondition(battery.chargeDetail == "电池未在充电")
    battery.fullyCharged = true
    precondition(battery.chargeDetail == "已充满")
    battery.fullyCharged = false
    battery.charging = true
    battery.percent = 100
    battery.minutesToFull = 0
    precondition(battery.chargeDetail == "已充满")
    precondition(battery.description.contains("已充满"))
    battery.minutesToFull = nil
    precondition(battery.chargeDetail == "正在充电")
    battery.minutesToFull = 5
    precondition(battery.chargeDetail == "完全充满电还需 5 分钟")
    battery.percent = 80
    battery.minutesToFull = 0
    precondition(battery.chargeDetail == "正在完成充电")
    battery.pluggedIn = false
    battery.charging = false
    precondition(battery.chargeDetail == "正在使用电池")
    var original = Status()
    original.percent = 80
    original.wifiOn = true
    original.rssi = -55
    var changed = original
    changed.rssi = -56
    changed.ssid = "Test Network"
    changed.minutesToFull = 20
    precondition(original != changed)
    precondition(IconState(original) == IconState(changed), "Detail changes must not redraw the icon")
    changed.rssi = -80
    precondition(IconState(original) != IconState(changed))
    changed = original
    changed.pluggedIn = true
    precondition(IconState(original) != IconState(changed))
    changed = original
    changed.percent = 81
    precondition(IconState(original) != IconState(changed))
    print("PASS: Wi-Fi boundaries, battery states, and icon change detection")
} else if CommandLine.arguments.contains("--diagnose") {
    print(Status.read().description)
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
