import SwiftUI
import UIKit

// MARK: - 账户

struct AccountPage: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var toasts: ToastCenter
    @Environment(\.colorScheme) private var scheme

    @State private var keyDraft = ""
    @State private var validating = false
    @State private var keyMessage = ""

    private var palette: Palette { Palette(dark: scheme == .dark) }

    private var defaultHint: String {
        settings.hasApiKey
            ? "已连接 Wallhaven，密钥保存在本机 Keychain"
            : "未连接。密钥可选，填写后可浏览限制级内容"
    }

    var body: some View {
        SettingsPage("账户") {
            SettingsCard {
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
                .padding(.horizontal, SettingsMetrics.rowInset)
                .padding(.vertical, 15)

                SettingsDivider(inset: SettingsMetrics.rowInset)

                Button {
                    validateKey()
                } label: {
                    HStack(spacing: SettingsMetrics.iconGap) {
                        SettingsIconTile(symbol: "checkmark.seal.fill")
                        Text("验证并保存")
                            .font(.system(size: 16))
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
                    .padding(.horizontal, SettingsMetrics.rowInset)
                    .frame(minHeight: SettingsMetrics.rowHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(validating)

                if settings.hasApiKey {
                    SettingsDivider()
                    Button {
                        removeKey()
                    } label: {
                        SettingsRowBody(symbol: "trash", title: "移除密钥", destructive: true)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                Text(keyMessage.isEmpty ? defaultHint : keyMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(keyMessage.isEmpty ? palette.textTertiary : palette.like)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                if keyMessage.isEmpty {
                    Link(
                        "获取密钥",
                        destination: URL(string: "https://wallhaven.cc/settings/account")!
                    )
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(palette.textSecondary)
                }
            }
            .padding(.horizontal, 2)
            .padding(.top, 10)
        }
        .onAppear {
            if keyDraft.isEmpty { keyDraft = settings.apiKey }
        }
    }

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
}

// MARK: - 浏览与外观

struct BrowsePage: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var favorites: FavoritesStore

    let onOpen: (Route) -> Void

    var body: some View {
        SettingsPage("浏览与外观") {
            SettingsSectionLabel(text: "浏览")
            SettingsCard {
                SettingsSegmentedRow(
                    symbol: "square.grid.2x2",
                    title: "每行显示",
                    options: [(2, "两列"), (3, "三列")],
                    selection: $settings.columns
                )
                SettingsDivider()
                SettingsSwitchRow(
                    symbol: "tag",
                    title: "卡片角标",
                    isOn: $settings.showMeta
                )
            }

            SettingsSectionLabel(text: "外观")
            SettingsCard {
                SettingsSegmentedRow(
                    symbol: "circle.lefthalf.filled",
                    title: "深浅模式",
                    options: ThemeMode.allCases.map { ($0, $0.label) },
                    selection: $settings.theme
                )
            }

            SettingsSectionLabel(text: "收藏")
            SettingsCard {
                Button {
                    onOpen(.favorites)
                } label: {
                    SettingsRowBody(
                        symbol: "heart",
                        title: "我的收藏",
                        value: "\(favorites.count) 张",
                        chevron: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 存储

struct StoragePage: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var toasts: ToastCenter
    @Environment(\.colorScheme) private var scheme

    @State private var cacheSize = ""
    @State private var confirmClearFavorites = false

    private var palette: Palette { Palette(dark: scheme == .dark) }

    var body: some View {
        SettingsPage("存储") {
            SettingsCard {
                SettingsSwitchRow(
                    symbol: "wifi",
                    title: "仅 Wi-Fi 下载",
                    isOn: $settings.wifiOnly
                )
                SettingsDivider()
                SettingsRowBody(
                    symbol: "photo.on.rectangle",
                    title: "保存位置",
                    value: "照片 / Haven"
                )
                SettingsDivider()
                Button {
                    clearCache()
                } label: {
                    SettingsRowBody(
                        symbol: "internaldrive",
                        title: "图片缓存",
                        value: cacheSize.isEmpty ? "已清空" : cacheSize,
                        chevron: true
                    )
                }
                .buttonStyle(.plain)
                SettingsDivider()
                Button {
                    settings.clearRecent()
                    toasts.show("搜索历史已清空")
                } label: {
                    SettingsRowBody(
                        symbol: "clock.arrow.circlepath",
                        title: "搜索历史",
                        value: "\(settings.recentSearches.count) 条",
                        chevron: true
                    )
                }
                .buttonStyle(.plain)
                SettingsDivider()
                Button {
                    confirmClearFavorites = true
                } label: {
                    SettingsRowBody(
                        symbol: "trash",
                        title: "清空收藏",
                        value: "\(favorites.count) 张",
                        destructive: true
                    )
                }
                .buttonStyle(.plain)
            }

            Text("图片缓存用于加速预览与查看，清除后再次浏览会重新下载。")
                .font(.system(size: 11))
                .foregroundStyle(palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)
                .padding(.top, 10)
        }
        .onAppear { refreshCacheSize() }
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

// MARK: - 关于

struct AboutPage: View {
    @Environment(\.colorScheme) private var scheme

    private var palette: Palette { Palette(dark: scheme == .dark) }

    private var versionLabel: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "v\(short) (\(build))"
    }

    var body: some View {
        SettingsPage("关于") {
            SettingsCard {
                SettingsRowBody(symbol: "app.badge", title: "版本", value: versionLabel)
                SettingsDivider()
                SettingsRowBody(symbol: "globe", title: "数据来源", value: "wallhaven.cc")
                SettingsDivider()
                Link(destination: URL(string: "https://github.com/kdjsn754/Haven-iOS")!) {
                    SettingsRowBody(
                        symbol: "chevron.left.forwardslash.chevron.right",
                        title: "源代码",
                        value: "GitHub",
                        chevron: true
                    )
                }
                .buttonStyle(.plain)
            }

            Text("Haven 是 Wallhaven.cc 的第三方客户端，与 Wallhaven 官方无关。壁纸版权归原作者所有，仅供个人浏览与收藏。")
                .font(.system(size: 11))
                .foregroundStyle(palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)
                .padding(.top, 10)
        }
    }
}
