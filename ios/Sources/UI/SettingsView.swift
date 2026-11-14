import SwiftUI

/// 设置总览：只放带图标的入口，具体项都在二级页里。
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var scrollTop: ScrollTopCenter
    @Environment(\.colorScheme) private var scheme

    /// 跳二级页（复用设置栈的 Route，返回时逐级出栈）
    let onOpen: (Route) -> Void

    @State private var cacheSize = ""

    private var palette: Palette { Palette(dark: scheme == .dark) }

    private var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "v\(short) (\(build))"
    }

    private var browseDetail: String {
        "\(settings.columns) 列 · \(settings.theme.label)"
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear
                        .frame(height: 0)
                        .id("top")

                    Text("设置")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(palette.textPrimary)
                        .padding(.leading, 2)
                        .padding(.top, 10)

                    sectionLabel("通用")
                    SettingsCard {
                        navRow(
                            symbol: "key.fill",
                            title: "账户",
                            value: settings.hasApiKey ? "已连接" : "未连接",
                            route: .settingsAccount
                        )
                        SettingsDivider()
                        navRow(
                            symbol: "square.grid.2x2.fill",
                            title: "浏览与外观",
                            value: browseDetail,
                            route: .settingsBrowse
                        )
                        SettingsDivider()
                        navRow(
                            symbol: "internaldrive.fill",
                            title: "存储",
                            value: cacheSize.isEmpty ? "已清空" : cacheSize,
                            route: .settingsStorage
                        )
                    }

                    sectionLabel("其他")
                    SettingsCard {
                        navRow(
                            symbol: "info.circle.fill",
                            title: "关于",
                            value: versionLabel,
                            route: .settingsAbout
                        )
                    }

                    Text("Haven 是 Wallhaven.cc 的第三方客户端，与官方无关。")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.textTertiary)
                        .padding(.leading, 2)
                        .padding(.top, 22)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)
            }
            .onChange(of: scrollTop.settingsTick) { _, _ in
                withAnimation(.easeOut(duration: 0.28)) {
                    proxy.scrollTo("top", anchor: .top)
                }
            }
        }
        .background(palette.background)
        .onAppear { refreshCacheSize() }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(palette.textTertiary)
            .padding(.leading, 2)
            .padding(.top, 26)
            .padding(.bottom, 8)
    }

    private func navRow(symbol: String, title: String, value: String, route: Route) -> some View {
        Button {
            onOpen(route)
        } label: {
            SettingsRowBody(symbol: symbol, title: title, value: value, chevron: true)
        }
        .buttonStyle(.plain)
    }

    private func refreshCacheSize() {
        let mb = ImageCache.shared.diskSizeMB()
        cacheSize = mb < 0.1 ? "" : String(format: "%.1f MB", mb)
    }
}
