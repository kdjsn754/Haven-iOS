import SwiftUI

/// 设置页共用组件。
///
/// 视觉基调：留白宽、字号大、层次靠"渐变 + 柔光 + 细描边"堆，
/// 不用大面积彩色块——颜色只出现在 36pt 的图标块上，其余保持黑白灰。
enum SettingsMetrics {
    static let rowHeight: CGFloat = 60
    static let tile: CGFloat = 36
    static let iconGap: CGFloat = 14
    static let rowInset: CGFloat = 18
    /// 分割线左缩进 = 卡片内边距 + 图标宽 + 间距，正好从文字起始处开始
    static let dividerInset: CGFloat = rowInset + tile + iconGap
    static let cardRadius: CGFloat = 18
}

/// 图标块的渐变配色：以项目家族的蓝(#357EF6)→青(#1BBEB7)为基准展开，
/// 每个分组换一个相邻色相，保持同一套语言的丰富度。
enum SettingsTint {
    static let blue: [Color] = [Color(hex: 0x5C8DFA), Color(hex: 0x2C5FE3)]
    static let cyan: [Color] = [Color(hex: 0x33D2D6), Color(hex: 0x149FB8)]
    static let indigo: [Color] = [Color(hex: 0x8E7CF8), Color(hex: 0x5A48DF)]
    static let pink: [Color] = [Color(hex: 0xFF8098), Color(hex: 0xEF3F5F)]
    static let amber: [Color] = [Color(hex: 0xFFC463), Color(hex: 0xEF8A22)]
    static let neutral: [Color] = [Color(hex: 0xB2B2C0), Color(hex: 0x81818F)]
}

struct SettingsIconTile: View {
    private let symbol: String
    private let tint: [Color]
    private let size: CGFloat

    init(symbol: String, tint: [Color] = SettingsTint.neutral, size: CGFloat = SettingsMetrics.tile) {
        self.symbol = symbol
        self.tint = tint
        self.size = size
    }

    var body: some View {
        let radius = size * 0.3
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: tint,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            // 顶部高光，让色块像一颗压克力按钮而不是一张色纸
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.28), Color.white.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
            Image(systemName: symbol)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(Color.white)
        }
        .frame(width: size, height: size)
        // 一层很浅的本色投影：只是让色块浮起来一点，不能糊成光斑
        .shadow(color: (tint.last ?? Color.clear).opacity(0.16), radius: 5, x: 0, y: 2)
    }
}

struct SettingsCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = scheme == .dark
        let top = dark ? Color(hex: 0x15151B) : Color.white
        let bottom = dark ? Color(hex: 0x0D0D11) : Color(hex: 0xFAFAFD)
        let border = dark ? Color.white.opacity(0.07) : Color(hex: 0xE8E8F0)

        VStack(spacing: 0) { content }
            .background(
                RoundedRectangle(cornerRadius: SettingsMetrics.cardRadius, style: .continuous)
                    .fill(
                        LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: SettingsMetrics.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: SettingsMetrics.cardRadius, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(dark ? 0.45 : 0.05), radius: 16, x: 0, y: 6)
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
            .fill(Palette(dark: scheme == .dark).line.opacity(0.9))
            .frame(height: 1)
            .padding(.leading, inset)
    }
}

struct SettingsRowBody: View {
    private let symbol: String
    private let tint: [Color]
    private let title: String
    private let value: String
    private let chevron: Bool
    private let destructive: Bool

    init(
        symbol: String,
        tint: [Color] = SettingsTint.neutral,
        title: String,
        value: String = "",
        chevron: Bool = false,
        destructive: Bool = false
    ) {
        self.symbol = symbol
        self.tint = tint
        self.title = title
        self.value = value
        self.chevron = chevron
        self.destructive = destructive
    }

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette(dark: scheme == .dark)
        return HStack(spacing: SettingsMetrics.iconGap) {
            SettingsIconTile(symbol: symbol, tint: tint)

            Text(title)
                .font(.system(size: 17))
                .foregroundStyle(destructive ? palette.like : palette.textPrimary)

            Spacer(minLength: 8)

            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 15))
                    .foregroundStyle(palette.textTertiary)
                    .lineLimit(1)
            }

            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
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
    private let tint: [Color]
    private let title: String
    @Binding private var isOn: Bool

    init(
        symbol: String,
        tint: [Color] = SettingsTint.neutral,
        title: String,
        isOn: Binding<Bool>
    ) {
        self.symbol = symbol
        self.tint = tint
        self.title = title
        self._isOn = isOn
    }

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette(dark: scheme == .dark)
        return HStack(spacing: SettingsMetrics.iconGap) {
            SettingsIconTile(symbol: symbol, tint: tint)
            Text(title)
                .font(.system(size: 17))
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
    private let tint: [Color]
    private let title: String
    private let options: [(T, String)]
    @Binding private var selection: T

    init(
        symbol: String,
        tint: [Color] = SettingsTint.neutral,
        title: String,
        options: [(T, String)],
        selection: Binding<T>
    ) {
        self.symbol = symbol
        self.tint = tint
        self.title = title
        self.options = options
        self._selection = selection
    }

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette(dark: scheme == .dark)
        return VStack(spacing: 14) {
            HStack(spacing: SettingsMetrics.iconGap) {
                SettingsIconTile(symbol: symbol, tint: tint)
                Text(title)
                    .font(.system(size: 17))
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
        .padding(.vertical, 18)
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
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Palette(dark: scheme == .dark).textTertiary)
            .tracking(0.6)
            .padding(.leading, 2)
            .padding(.top, 28)
            .padding(.bottom, 10)
    }
}

/// 页面底色：顶部一层极淡的蓝青色晕，往下收成纯色，避免大片死白。
struct SettingsBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let dark = scheme == .dark
        LinearGradient(
            colors: dark
                ? [Color(hex: 0x0C1018), Color(hex: 0x08080A)]
                : [Color(hex: 0xF4F8FF), Color(hex: 0xFFFFFF)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
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

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, 22)
            .padding(.top, 22)
            .padding(.bottom, 44)
        }
        .background(SettingsBackground())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}
