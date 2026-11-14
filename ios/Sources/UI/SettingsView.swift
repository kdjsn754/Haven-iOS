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
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(palette.textPrimary)
                        .padding(.leading, 2)
                        .padding(.top, 14)

                    brandRow

                    sectionLabel("通用")
                    SettingsCard {
                        navRow(
                            symbol: "key.fill",
                            tint: SettingsTint.blue,
                            title: "账户",
                            value: settings.hasApiKey ? "已连接" : "未连接",
                            route: .settingsAccount
                        )
                        SettingsDivider()
                        navRow(
                            symbol: "square.grid.2x2.fill",
                            tint: SettingsTint.cyan,
                            title: "浏览与外观",
                            value: browseDetail,
                            route: .settingsBrowse
                        )
                        SettingsDivider()
                        navRow(
                            symbol: "internaldrive.fill",
                            tint: SettingsTint.indigo,
                            title: "存储",
                            value: cacheSize.isEmpty ? "已清空" : cacheSize,
                            route: .settingsStorage
                        )
                    }

                    sectionLabel("其他")
                    SettingsCard {
                        navRow(
                            symbol: "info.circle.fill",
                            tint: SettingsTint.neutral,
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
                .padding(.horizontal, 22)
                .padding(.bottom, 44)
            }
            .onChange(of: scrollTop.settingsTick) { _, _ in
                withAnimation(.easeOut(duration: 0.28)) {
                    proxy.scrollTo("top", anchor: .top)
                }
            }
        }
        .background(SettingsBackground())
        .onAppear { refreshCacheSize() }
    }

    /// 顶部品牌区：渐变字标 + 名称版本，给页面一个视觉重心。
    private var brandRow: some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x357EF6), Color(hex: 0x1BBEB7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.25), Color.white.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                Text("H")
                    .font(.system(size: 33, weight: .bold, design: .serif))
                    .italic()
                    .foregroundStyle(Color.white)
            }
            .frame(width: 60, height: 60)
            .shadow(color: Color(hex: 0x1B8FB0).opacity(0.32), radius: 12, x: 0, y: 6)

            VStack(alignment: .leading, spacing: 5) {
                Text("Haven")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
                Text("Wallhaven 第三方客户端 · \(versionLabel)")
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 24)
        .padding(.leading, 2)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(palette.textTertiary)
            .padding(.leading, 2)
            .padding(.top, 30)
            .padding(.bottom, 10)
    }

    private func navRow(
        symbol: String,
        tint: [Color],
        title: String,
        value: String,
        route: Route
    ) -> some View {
        Button {
            onOpen(route)
        } label: {
            SettingsRowBody(
                symbol: symbol,
                tint: tint,
                title: title,
                value: value,
                chevron: true
            )
        }
        .buttonStyle(.plain)
    }

    private func refreshCacheSize() {
        let mb = ImageCache.shared.diskSizeMB()
        cacheSize = mb < 0.1 ? "" : String(format: "%.1f MB", mb)
    }
}
