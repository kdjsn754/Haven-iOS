import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var toasts: ToastCenter
    @Environment(\.colorScheme) private var scheme

    let onOpenFavorites: () -> Void

    @State private var keyDraft = ""
    @State private var showKey = false
    @State private var validating = false
    @State private var keyMessage: String?
    @State private var cacheSize = ""

    private var palette: Palette { Palette(dark: scheme == .dark) }

    private var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "v\(short) (\(build))"
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                header

                groupLabel("账户")
                apiKeyCard
                card {
                    toggleRow(
                        "显示限制级内容",
                        subtitle: settings.hasApiKey ? nil : "需要先填写有效的 API 密钥",
                        isOn: $settings.showNsfw,
                        enabled: settings.hasApiKey
                    )
                }

                groupLabel("浏览")
                card {
                    columnsRow
                    divider
                    toggleRow("卡片信息", subtitle: "卡片上的体积、浏览与收藏角标", isOn: $settings.showMeta)
                    divider
                    tapRow("我的收藏", value: "\(favorites.count)") { onOpenFavorites() }
                }

                groupLabel("外观")
                card { themeRow }

                groupLabel("下载")
                card {
                    toggleRow("仅 Wi-Fi 下载", subtitle: "仅作提醒，下载始终可用", isOn: $settings.wifiOnly)
                    divider
                    tapRow("保存位置", value: "照片 / 自建相簿 Haven", action: nil)
                }

                groupLabel("存储")
                card {
                    tapRow("清除图片缓存", value: cacheSize) { clearCache() }
                    divider
                    tapRow("清除搜索历史", value: nil) { settings.clearRecent(); toasts.show("搜索历史已清空") }
                    divider
                    Button {
                        favorites.clear()
                        toasts.show("收藏已清空")
                    } label: {
                        HStack {
                            Text("清空收藏")
                                .font(F.body())
                                .foregroundStyle(palette.like)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                groupLabel("关于")
                card {
                    tapRow("版本", value: versionLabel, action: nil)
                    divider
                    tapRow("数据来源", value: "wallhaven.cc", action: nil)
                }
                disclaimer
            }
            .padding(.bottom, 110)
        }
        .background(palette.background)
        .onAppear {
            if keyDraft.isEmpty { keyDraft = settings.apiKey }
            refreshCacheSize()
        }
    }

    // MARK: 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("设置")
                .font(F.display())
                .foregroundStyle(palette.textPrimary)
            Text("账户、外观与存储")
                .font(F.bodySmall())
                .foregroundStyle(palette.textTertiary)
        }
        .padding(.leading, 20)
        .padding(.trailing, 20)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private func groupLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(palette.textTertiary)
            .padding(.leading, 22)
            .padding(.top, 22)
            .padding(.bottom, 10)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .background(palette.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 20)
    }

    private var divider: some View {
        Rectangle()
            .fill(palette.line)
            .frame(height: 1)
            .padding(.leading, 16)
    }

    // MARK: API 密钥卡

    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("API 密钥")
                    .font(F.titleSmall())
                    .foregroundStyle(palette.textPrimary)
                Spacer()
                Link(destination: URL(string: "https://wallhaven.cc/settings/account")!) {
                    Text("获取 ↗")
                        .font(F.label())
                        .foregroundStyle(palette.textSecondary)
                }
            }

            HStack(spacing: 8) {
                Group {
                    if showKey {
                        TextField("粘贴你的 API 密钥", text: $keyDraft)
                    } else {
                        SecureField("粘贴你的 API 密钥", text: $keyDraft)
                    }
                }
                .font(F.body())
                .foregroundStyle(palette.textPrimary)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

                Button {
                    showKey.toggle()
                } label: {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                        .font(.system(size: 15))
                        .foregroundStyle(palette.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 10) {
                Button {
                    validateKey()
                } label: {
                    HStack(spacing: 6) {
                        if validating {
                            ProgressView()
                                .scaleEffect(0.7)
                                .tint(palette.onInk)
                        }
                        Text(validating ? "验证中…" : "保存并验证")
                            .font(F.pill())
                            .foregroundStyle(palette.onInk)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(palette.ink)
                    .clipShape(Capsule())
                    .opacity(validating ? 0.7 : 1)
                }
                .buttonStyle(.plain)
                .disabled(validating)

                Button {
                    settings.apiKey = ""
                    keyDraft = ""
                    keyMessage = nil
                    toasts.show("API 密钥已移除")
                } label: {
                    Text("移除")
                        .font(F.pill())
                        .foregroundStyle(palette.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .overlay(Capsule().stroke(palette.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            if let keyMessage {
                Text(keyMessage)
                    .font(F.label())
                    .foregroundStyle(palette.textSecondary)
            }

            Text("密钥只保存在本机（Keychain），不会上传到任何服务器。")
                .font(F.label())
                .foregroundStyle(palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(palette.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 20)
    }

    // MARK: 行

    private func toggleRow(
        _ title: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>,
        enabled: Bool = true
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(F.body())
                    .foregroundStyle(palette.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(F.label())
                        .foregroundStyle(palette.textTertiary)
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(palette.ink)
                .disabled(!enabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .opacity(enabled ? 1 : 0.55)
    }

    private func tapRow(_ title: String, value: String?, action: (() -> Void)?) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(F.body())
                    .foregroundStyle(palette.textPrimary)
                Spacer(minLength: 8)
                if let value, !value.isEmpty {
                    Text(value)
                        .font(F.body())
                        .foregroundStyle(palette.textTertiary)
                        .lineLimit(1)
                }
                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(palette.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }

    private var columnsRow: some View {
        HStack {
            Text("每行显示")
                .font(F.body())
                .foregroundStyle(palette.textPrimary)
            Spacer()
            HStack(spacing: 8) {
                PillChip(title: "两列", selected: settings.columns == 2) { settings.columns = 2 }
                PillChip(title: "三列", selected: settings.columns == 3) { settings.columns = 3 }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private var themeRow: some View {
        HStack(spacing: 8) {
            ForEach(ThemeMode.allCases) { mode in
                PillChip(title: mode.label, selected: settings.theme == mode) { settings.theme = mode }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private var disclaimer: some View {
        Text("Haven 是 Wallhaven.cc 的第三方客户端，与 Wallhaven 官方无关。所有壁纸版权归原作者所有，仅供个人浏览与收藏。")
            .font(F.bodySmall())
            .foregroundStyle(palette.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 22)
            .padding(.top, 14)
    }

    // MARK: 动作

    private func validateKey() {
        let key = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            keyMessage = "请先填写 API 密钥"
            return
        }
        validating = true
        keyMessage = nil
        Task {
            let error = await WallhavenAPI.shared.validateKey(key)
            validating = false
            if let error {
                keyMessage = error
            } else {
                settings.apiKey = key
                keyMessage = "已验证并保存"
                toasts.show("API 密钥已保存")
            }
        }
    }

    private func refreshCacheSize() {
        let mb = ImageCache.shared.diskSizeMB()
        cacheSize = mb < 0.1 ? "" : String(format: "%.1f MB", mb)
    }

    private func clearCache() {
        ImageCache.shared.clear()
        refreshCacheSize()
        toasts.show("图片缓存已清除")
    }
}
