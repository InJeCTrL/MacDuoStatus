import SwiftUI
import CoreWLAN

final class PanelModel: ObservableObject {
    @Published var status = Status()
    @Published var showPercent = false
    @Published var wifiBusy = false
    @Published var error: String?
    @Published var launchAtLogin = false
    @Published var loginNeedsApproval = false
    @Published var loginError: String?
    var onLoginToggle: () -> Void = {}
    var onLoginSettings: () -> Void = {}
    var onPercentChange: (Bool) -> Void = { _ in }
    var onWiFiChange: (Bool) -> Void = { _ in }
    var onSettings: (String) -> Void = { _ in }
}

struct StatusPanel: View {
    @ObservedObject var model: PanelModel
    private var status: Status { model.status }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("电池").fontWeight(.semibold)
                Spacer()
                Text(status.percent.map { "\($0)%" } ?? "--").foregroundStyle(.secondary)
            }
            .padding(.bottom, 9)
            VStack(alignment: .leading, spacing: 4) {
                Text("电源：\(status.pluggedIn ? "电源适配器" : "电池")")
                Text(status.chargeDetail)
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            separator
            Text("能耗模式").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            HStack(spacing: 10) {
                badge("battery.50percent", active: status.lowPower)
                Text(status.lowPower ? "低电量" : "低电量模式未开启")
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .onTapGesture { model.onSettings("battery") }
            .accessibilityAddTraits(.isButton)
            settingsButton("电池设置…", section: "battery")
            separator

            HStack {
                Text("Wi-Fi").fontWeight(.semibold)
                Spacer()
                Toggle("Wi-Fi", isOn: Binding(get: { status.wifiOn }, set: model.onWiFiChange))
                    .labelsHidden().toggleStyle(.switch).controlSize(.small)
                    .disabled(model.wifiBusy || !status.wifiAvailable)
            }
            .padding(.bottom, 12)
            if status.wifiOn {
                Text(status.bars > 0 ? "当前网络" : "网络状态")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    badge(status.bars > 0 ? "wifi" : "wifi.slash", active: status.bars > 0)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(status.ssid ?? (status.bars > 0 ? "已连接 Wi-Fi" : "未连接或信号不可用"))
                            .lineLimit(1).truncationMode(.middle)
                        if status.bars > 0 {
                            Text("信号 \(status.bars)/3 · \(status.rssi) dBm").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                    if status.bars > 0 && status.security != .unknown && status.security != .none {
                        Image(systemName: "lock.fill").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 9)
                if status.bars > 0 && status.ssid == nil {
                    Text("网络名称不可用，可能受定位权限限制。")
                        .font(.system(size: 11)).foregroundStyle(.secondary).padding(.bottom, 8)
                }
                if status.bars > 0 && [CWSecurity.none, .WEP, .wpaPersonal, .wpaEnterprise].contains(where: { $0 == status.security }) {
                    Label(status.security == .none ? "开放网络" : "低安全性", systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 12)).foregroundStyle(.secondary).padding(.bottom, 8)
                }
            } else {
                Text(status.wifiAvailable ? "Wi-Fi 已关闭" : "未找到 Wi-Fi 接口")
                    .font(.system(size: 12)).foregroundStyle(.secondary).padding(.bottom, 10)
            }
            if let error = model.error {
                Text("无法切换 Wi-Fi：\(error)").font(.system(size: 11)).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            settingsButton("Wi-Fi 设置…", section: "wifi")
            separator
            Button {
                model.showPercent.toggle()
                model.onPercentChange(model.showPercent)
            } label: {
                HStack(spacing: 0) {
                    Text("显示电量百分比")
                    Spacer()
                }
                .overlay(alignment: .leading) {
                    if model.showPercent {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .semibold))
                            .offset(x: -13)
                    }
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .accessibilityValue(model.showPercent ? "已勾选" : "未勾选")
            Button(action: model.onLoginToggle) {
                HStack {
                    Text("登录时自动启动")
                    Spacer()
                }
                .overlay(alignment: .leading) {
                    if model.launchAtLogin {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .semibold)).offset(x: -13)
                    }
                }
                .padding(.vertical, 6).contentShape(Rectangle())
            }
            .buttonStyle(.plain).font(.system(size: 12))
            .accessibilityValue(model.launchAtLogin ? "已开启" : "未开启")
            if model.loginNeedsApproval {
                Button("需在系统登录项中允许…", action: model.onLoginSettings)
                    .buttonStyle(.link).font(.system(size: 11)).padding(.bottom, 6)
            }
            if let error = model.loginError {
                Text(error).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true).padding(.bottom, 6)
            }
            Divider().padding(.top, 10).padding(.horizontal, -16)
            HStack {
                Text("Duo Status").foregroundStyle(.secondary)
                Spacer()
                Button("退出") { NSApp.terminate(nil) }.buttonStyle(.plain).foregroundStyle(.secondary)
            }
            .font(.system(size: 11))
            .padding(.horizontal, 16).frame(height: 36)
            .padding(.horizontal, -16).padding(.bottom, -16)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .frame(width: 310)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var separator: some View { Divider().padding(.vertical, 12) }

    private func badge(_ symbol: String, active: Bool) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(active ? Color.white : Color.primary.opacity(0.65))
            .frame(width: 30, height: 30)
            .background(active ? Color.accentColor : Color.primary.opacity(0.07), in: Circle())
    }

    private func settingsButton(_ title: String, section: String) -> some View {
        Button { model.onSettings(section) } label: {
            HStack { Text(title); Spacer() }.contentShape(Rectangle()).padding(.vertical, 3)
        }
        .buttonStyle(.plain)
    }
}
