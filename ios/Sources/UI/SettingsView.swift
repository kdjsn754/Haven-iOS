import SwiftUI
import UIKit

/// 设置页：克制的分组列表。
///
/// 设计约定（避免"杂乱"）：
///  · 一行只说一件事，行首不放图标，靠文字对齐形成竖线
///  · 每张卡只有一个层级：无嵌套小方块、无胶囊、无彩色底
///  · 开关/分段用系统控件，样式交给 iOS
///  · 说明文字一律放在卡片下面的小灰字里，不塞进卡片内部
struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var toasts: ToastCenter
    @EnvironmentObject private var scrollTop: ScrollTopCenter
    @Environment(\.colorScheme) private var scheme

    let onOpenFavorites: () -> Void

    @State private var keyDraft = ""
    @State private var validating = false
    @State private var keyMessage = ""
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

                    sectionLabel("账户")
                    accountCard
                    keyHint

                    sectionLabel("浏览")
                    browseCard

                    sectionLabel("外观")
                    appearanceCard

                    sectionLabel("存储")
                    storageCard

                    sectionLabel("关于")
                    aboutCard

                    Text("Haven 是 Wallhaven.cc 的第三方客户端，与官方无关。壁纸版权归原作者所有。")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 2)
                        .padding(.top, 22)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .onChange(of: scrollTop.settingsTick) { _, _ in
                withAnimation(.easeOut(duration: 0.28)) {
                    proxy.scrollTo("top", anchor: .top)
                }
            }
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

    private var defaultKeyHint: String {
        settings.hasApiKey
            ? "已连接 Wallhaven，密钥保存在本机 Keychain"
            : "未连接。密钥可选，填写后可浏览限制级内容"
    }

    // MARK: 骨架

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(palette.textTertiary)
            .padding(.leading, 2)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(palette.line, lineWidth: 1)
        )
    }

    private var divider: some View {
        Rectangle()
            .fill(palette.line)
            .frame(height: 1)
            .padding(.leading, 16)
    }

    /// 密钥说明：一行小灰字，右侧挂"获取密钥"链接，不占卡片空间。
    private var keyHint: some View {
        HStack(spacing: 8) {
            Text(keyMessage.isEmpty ? defaultKeyHint : keyMessage)
                .font(.system(size: 11))
                .foregroundStyle(keyMessage.isEmpty ? palette.textTertiary : palette.like)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if keyMessage.isEmpty {
                Link("获取密钥", destination: URL(string: "https://wallhaven.cc/settings/account")!)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
            }
        }
        .padding(.horizontal, 2)
        .padding(.top, 9)
    }

    // MARK: 账户

    private var accountCard: some View {
        card {
            HStack(spacing: 10) {
                KeyField(
                    text: $keyDraft,
                    placeholder: "粘贴你的 API 密钥",
                    textColor: UIColor(palette.textPrimary),
                    placeholderColor: UIColor(palette.textTertiary)
                )
                .frame(height: 22)

                if !keyDraft.isEmpty {
                    Button {
                        keyDraft = ""
                        keyMessage = ""
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
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(palette.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            divider

            Button {
                validateKey()
            } label: {
                HStack(spacing: 8) {
                    Text("验证并保存")
                        .font(.system(size: 15))
                        .foregroundStyle(palette.textPrimary)
                    Spacer(minLength: 8)
                    if validating {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Text(settings.hasApiKey ? "已连接" : "未连接")
                            .font(.system(size: 14))
                            .foregroundStyle(palette.textTertiary)
                    }
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(validating)

            if settings.hasApiKey {
                divider
                Button {
                    removeKey()
                } label: {
                    HStack {
                        Text("移除密钥")
                            .font(.system(size: 15))
                            .foregroundStyle(palette.like)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: 浏览

    private var browseCard: some View {
        card {
            segmentedRow(
                title: "每行显示",
                width: 122,
                options: [(2, "两列"), (3, "三列")],
                selection: $settings.columns
            )
            divider
            switchRow(title: "卡片角标", isOn: $settings.showMeta)
            divider
            row(title: "我的收藏", value: "\(favorites.count) 张", chevron: true) {
                onOpenFavorites()
            }
        }
    }

    // MARK: 外观

    private var appearanceCard: some View {
        card {
            segmentedRow(
                title: "深浅模式",
                width: 200,
                options: ThemeMode.allCases.map { ($0, $0.label) },
                selection: $settings.theme
            )
        }
    }

    // MARK: 存储

    private var storageCard: some View {
        card {
            switchRow(title: "仅 Wi-Fi 下载", isOn: $settings.wifiOnly)
            divider
            row(title: "保存位置", value: "照片 / Haven")
            divider
            row(title: "图片缓存", value: cacheSize.isEmpty ? "已清空" : cacheSize, chevron: true) {
                clearCache()
            }
            divider
            row(title: "搜索历史", value: "\(settings.recentSearches.count) 条", chevron: true) {
                settings.clearRecent()
                toasts.show("搜索历史已清空")
            }
            divider
            row(title: "清空收藏", value: "\(favorites.count) 张", tint: palette.like) {
                confirmClearFavorites = true
            }
        }
    }

    // MARK: 关于

    private var aboutCard: some View {
        card {
            row(title: "版本", value: versionLabel)
            divider
            row(title: "数据来源", value: "wallhaven.cc")
            divider
            Link(destination: URL(string: "https://github.com/kdjsn754/Haven-iOS")!) {
                rowBody(title: "源代码", value: "GitHub", chevron: true, tint: nil)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: 行

    private func rowBody(title: String, value: String, chevron: Bool, tint: Color?) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(tint ?? palette.textPrimary)
            Spacer(minLength: 8)
            if !value.isEmpty {
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
        .frame(minHeight: 50)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func row(
        title: String,
        value: String = "",
        chevron: Bool = false,
        tint: Color? = nil,
        action: (() -> Void)? = nil
    ) -> some View {
        if let action {
            Button(action: action) {
                rowBody(title: title, value: value, chevron: chevron, tint: tint)
            }
            .buttonStyle(.plain)
        } else {
            rowBody(title: title, value: value, chevron: chevron, tint: tint)
        }
    }

    private func switchRow(title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(palette.textPrimary)
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 50)
    }

    private func segmentedRow<T: Hashable>(
        title: String,
        width: CGFloat,
        options: [(T, String)],
        selection: Binding<T>
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(palette.textPrimary)
            Spacer(minLength: 8)
            Picker(title, selection: selection) {
                ForEach(options.indices, id: \.self) { index in
                    Text(options[index].1).tag(options[index].0)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: width)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
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
        keyMessage = ""
    }

    private func removeKey() {
        settings.apiKey = ""
        keyDraft = ""
        keyMessage = ""
        toasts.show("API 密钥已移除")
    }

    private func validateKey() {
        let key = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            keyMessage = "请先填写 API 密钥"
            return
        }
        validating = true
        keyMessage = ""
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
