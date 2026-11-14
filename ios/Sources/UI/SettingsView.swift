import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var toasts: ToastCenter
    @Environment(\.colorScheme) private var scheme

    let onOpenFavorites: () -> Void

    @State private var keyDraft = ""
    @State private var validating = false
    @State private var keyMessage: String?
    @State private var cacheSize = ""
    @State private var confirmClearFavorites = false

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

                sectionLabel("账户")
                apiKeyCard

                sectionLabel("浏览")
                browseCard

                sectionLabel("外观")
                appearanceCard

                sectionLabel("下载与存储")
                storageCard

                sectionLabel("关于")
                aboutCard

                footer
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .background(palette.background)
        .onAppear {
            if keyDraft.isEmpty { keyDraft = settings.apiKey }
            refreshCacheSize()
        }
        .confirmationDialog(
            "清空全部收藏？",
            isPresented: $confirmClearFavorites,
            titleVisibility: .visible
        ) {
            Button("清空收藏", role: .destructive) {
                favorites.clear()
                toasts.show("收藏已清空")
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("共 \(favorites.count) 张，清空后无法恢复")
        }
    }

    // MARK: 头部

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("设置")
                .font(F.display())
                .foregroundStyle(palette.textPrimary)
            Text("账户、浏览、外观与存储")
                .font(.system(size: 12))
                .foregroundStyle(palette.textTertiary)
        }
        .padding(.leading, 2)
        .padding(.top, 12)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(palette.textTertiary)
            .padding(.leading, 2)
            .padding(.top, 26)
            .padding(.bottom, 9)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(palette.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var divider: some View {
        Rectangle()
            .fill(palette.line)
            .frame(height: 1)
            .padding(.leading, 48)
    }

    // MARK: 账户

    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "key.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(palette.textTertiary)
                    .frame(width: 22, alignment: .leading)
                Text("API 密钥")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(palette.textPrimary)
                Spacer(minLength: 8)
                statusPill
            }

            // 普通键盘，不是系统密码键盘：不弹自动填充、不弹强密码建议。
            HStack(spacing: 8) {
                KeyField(
                    text: $keyDraft,
                    placeholder: "粘贴你的 API 密钥",
                    textColor: UIColor(palette.textPrimary),
                    placeholderColor: UIColor(palette.textTertiary)
                )
                .frame(height: 20)

                if !keyDraft.isEmpty {
                    Button {
                        keyDraft = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(palette.textTertiary)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    pasteKey()
                } label: {
                    Text("粘贴")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(palette.surfaceAlt)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
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
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(palette.onInk)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(palette.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .opacity(validating ? 0.65 : 1)
                }
                .buttonStyle(.plain)
                .disabled(validating)

                if settings.hasApiKey {
                    Button {
                        removeKey()
                    } label: {
                        Text("移除")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(palette.like)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(palette.line, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            if let keyMessage {
                Text(keyMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 3) {
                Text("密钥只保存在本机 Keychain。")
                Link(
                    "去获取 ↗",
                    destination: URL(string: "https://wallhaven.cc/settings/account")!
                )
                .foregroundStyle(palette.textSecondary)
            }
            .font(.system(size: 11))
            .foregroundStyle(palette.textTertiary)
        }
        .padding(16)
        .background(palette.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statusPill: some View {
        let on = settings.hasApiKey
        return HStack(spacing: 5) {
            Circle()
                .fill(on ? palette.downloaded : palette.textTertiary)
                .frame(width: 6, height: 6)
            Text(on ? "已连接" : "未连接")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(on ? palette.textSecondary : palette.textTertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(palette.surface)
        .clipShape(Capsule())
    }

    // MARK: 浏览

    private var browseCard: some View {
        card {
            block(icon: "square.grid.2x2", title: "每行显示") {
                segmented([(2, "两列"), (3, "三列")], selection: $settings.columns)
            }
            divider
            switchRow(
                icon: "info.circle",
                title: "卡片角标",
                subtitle: "卡片上的体积、浏览与收藏量",
                isOn: $settings.showMeta
            )
            divider
            row(
                icon: "heart",
                title: "我的收藏",
                value: "\(favorites.count) 张",
                chevron: true
            ) { onOpenFavorites() }
        }
    }

    // MARK: 外观

    private var appearanceCard: some View {
        card {
            block(icon: "circle.lefthalf.filled", title: "深浅模式") {
                segmented(
                    ThemeMode.allCases.map { ($0, $0.label) },
                    selection: $settings.theme
                )
            }
        }
    }

    // MARK: 下载与存储

    private var storageCard: some View {
        card {
            switchRow(
                icon: "wifi",
                title: "仅 Wi-Fi 下载",
                subtitle: "仅作提醒，下载始终可用",
                isOn: $settings.wifiOnly
            )
            divider
            row(icon: "photo.on.rectangle", title: "保存位置", value: "照片 / Haven")
            divider
            row(
                icon: "internaldrive",
                title: "图片缓存",
                value: cacheSize.isEmpty ? "已清空" : cacheSize,
                chevron: true
            ) { clearCache() }
            divider
            row(
                icon: "clock.arrow.circlepath",
                title: "搜索历史",
                value: "\(settings.recentSearches.count) 条",
                chevron: true
            ) {
                settings.clearRecent()
                toasts.show("搜索历史已清空")
            }
            divider
            row(
                icon: "trash",
                title: "清空收藏",
                value: "\(favorites.count) 张",
                tint: palette.like
            ) { confirmClearFavorites = true }
        }
    }

    // MARK: 关于

    private var aboutCard: some View {
        card {
            row(icon: "app.badge", title: "版本", value: versionLabel)
            divider
            row(icon: "globe", title: "数据来源", value: "wallhaven.cc")
            divider
            Link(destination: URL(string: "https://github.com/kdjsn754/Haven-iOS")!) {
                rowContent(icon: "link", title: "源代码", value: "GitHub", chevron: true, tint: nil)
            }
            .buttonStyle(.plain)
        }
    }

    private var footer: some View {
        Text("Haven 是 Wallhaven.cc 的第三方客户端，与 Wallhaven 官方无关。壁纸版权归原作者所有，仅供个人浏览与收藏。")
            .font(.system(size: 11))
            .foregroundStyle(palette.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 2)
            .padding(.top, 20)
    }

    // MARK: 行

    private func rowContent(
        icon: String,
        title: String,
        value: Pepcte,
        chevron: Bool,
        tint: Color?
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(tint ?? palette.textTertiary)
                .frame(width: 22, alignment: .leading)
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(tint ?? palette.textPrimary)
            Spacer(minLength: 8)
            if let value, !value.isEmpty {
                Text(value)
                    .font(.system(size: 14))
                    .foregroundStyle(palette.textTertiary)
                    .lineLimit(1)
            }
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(palette.textTertiary)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func row(
        icon: String,
        title: String,
        value: Pepcte = nil,
        chevron: Bool = false,
        tint: Color? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        if let action {
            Button(action: action) {
                rowContent(icon: icon, title: title, value: value, chevron: chevron, tint: tint)
            }
            .buttonStyle(.plain)
        } else {
            rowContent(icon: icon, title: title, value: value, chevron: chevron, tint: tint)
        }
    }

    private func switchRow(
        icon: String,
        title: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(palette.textTertiary)
                .frame(width: 22, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(palette.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(palette.textTertiary)
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(palette.ink)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, subtitle == nil ? 0 : 10)
        .frame(minHeight: 52)
    }

    private func block<Content: View>(
        icon: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(palette.textTertiary)
                    .frame(width: 22, alignment: .leading)
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(palette.textPrimary)
                Spacer(minLength: 0)
            }
            content()
                .padding(.leading, 32)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private func segmented<T: Hashable>(
        _ options: [(T, String)],
        selection: Binding<T>
    ) -> some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let selected = selection.wrappedValue == option.0
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        selection.wrappedValue = option.0
                    }
                } label: {
                    Text(option.1)
                        .font(.system(size: 13, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected ? palette.onInk : palette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selected ? palette.ink : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: 动作

    private func pasteKey() {
        guard let raw = UIPasteboard.general.string else {
            toasts.show("剪贴板里没有内容")
            return
        }
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            toasts.show("剪贴板里没有内容")
            return
        }
        keyDraft = key
    }

    private func removeKey() {
        settings.apiKey = ""
        keyDraft = ""
        keyMessage = nil
        toasts.show("API 密钥已移除")
    }

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
