import SwiftUI

/// 设置页共用的小组件：所有页面都只用这一套骨架，
/// 让总览页与各二级页的圆角、行高、描边、图标尺寸完全一致。
enum SettingsMetrics {
    static let rowHeight: CGFloat = 52
    static let tile: CGFloat = 28
    static let iconGap: CGFloat = 12
    static let rowInset: CGFloat = 16
    /// 分割线左缩进 = 卡片内边距 + 图标宽 + 间距，正好从文字起始处开始
    static let dividerInset: CGFloat = rowInset + tile + iconGap
    static let cardRadius: CGFloat = 14
}

/// 行首的图标块：中性灰底 + 黑色线性图标，与全站黑白灰配色一致。
struct SettingsIconTile: View {
    private let symbol: String
    private let size: CGFloat

    init(symbol: String, size: CGFloat = SettingsMetrics.tile) {
        self.symbol = symbol
        self.size = size
    }

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette(dark: scheme == .dark)
        return RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            .fill(palette.surfaceAlt)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.46, weight: .semibold))
                    .foregroundStyle(palette.textPrimary)
            }
    }
}

struct SettingsCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette(dark: scheme == .dark)
        return VStack(spacing: 0) { content }
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: SettingsMetrics.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SettingsMetrics.cardRadius, style: .continuous)
                    .strokeBorder(palette.line, lineWidth: 1)
            }
    }
}

struct SettingsDivider: View {
    private let inset: CGFloat

    init(inset: CGFloat = SettingsMetrics.dividerInset) {
        self.inset = inset
    }

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Rectangle()
            .fill(Palette(dark: scheme == .dark).line)
            .frame(height: 1)
            .padding(.leading, inset)
    }
}

/// 一行：图标 + 标题 + 右侧值 / 箭头。本身不带点击，外面用 Button 包。
struct SettingsRowBody: View {
    private let symbol: String
    private let title: String
    private let value: String
    private let chevron: Bool
    private let destructive: Bool

    init(
        symbol: String,
        title: String,
        value: String = "",
        chevron: Bool = false,
        destructive: Bool = false
    ) {
        self.symbol = symbol
        self.title = title
        self.value = value
        self.chevron = chevron
        self.destructive = destructive
    }

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette(dark: scheme == .dark)
        return HStack(spacing: SettingsMetrics.iconGap) {
            SettingsIconTile(symbol: symbol)

            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(destructive ? palette.like : palette.textPrimary)

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
        .padding(.horizontal, SettingsMetrics.rowInset)
        .frame(minHeight: SettingsMetrics.rowHeight)
        .contentShape(Rectangle())
    }
}

struct SettingsSwitchRow: View {
    private let symbol: String
    private let title: String
    @Binding private var isOn: Bool

    init(symbol: String, title: String, isOn: Binding<Bool>) {
        self.symbol = symbol
        self.title = title
        self._isOn = isOn
    }

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette(dark: scheme == .dark)
        return HStack(spacing: SettingsMetrics.iconGap) {
            SettingsIconTile(symbol: symbol)
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(palette.textPrimary)
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.horizontal, SettingsMetrics.rowInset)
        .frame(minHeight: SettingsMetrics.rowHeight)
    }
}

/// 分段控件行：标题一行，控件占满整行宽（避免中文标签被挤断）。
struct SettingsSegmentedRow<T: Hashable>: View {
    private let symbol: String
    private let title: String
    private let options: [(T, String)]
    @Binding private var selection: T

    init(
        symbol: String,
        title: String,
        options: [(T, String)],
        selection: Binding<T>
    ) {
        self.symbol = symbol
        self.title = title
        self.options = options
        self._selection = selection
    }

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette(dark: scheme == .dark)
        return VStack(spacing: 12) {
            HStack(spacing: SettingsMetrics.iconGap) {
                SettingsIconTile(symbol: symbol)
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(palette.textPrimary)
                Spacer(minLength: 0)
            }

            Picker(title, selection: $selection) {
                ForEach(options.indices, id: \.self) { index in
                    Text(options[index].1).tag(options[index].0)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.horizontal, SettingsMetrics.rowInset)
        .padding(.vertical, 14)
    }
}

struct SettingsSectionLabel: View {
    private let text: String

    init(text: String) {
        self.text = text
    }

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Palette(dark: scheme == .dark).textTertiary)
            .padding(.leading, 2)
            .padding(.top, 22)
            .padding(.bottom, 8)
    }
}

/// 二级页外壳：统一左右边距、底部留白与背景色。
struct SettingsPage<Content: View>: View {
    private let title: String
    private let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 34)
        }
        .background(Palette(dark: scheme == .dark).background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}
