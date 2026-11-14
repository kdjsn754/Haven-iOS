import SwiftUI
import UIKit

// MARK: - 自动换行布局（标签流 / 筛选胶囊）

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var rowHeight: CGFloat = 0
        var total: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                total += rowHeight + lineSpacing
                widest = max(widest, x - spacing)
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        total += rowHeight
        widest = max(widest, max(0, x - spacing))
        return CGSize(width: min(maxWidth, max(widest, 1)), height: max(total, 1))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - 胶囊按钮

struct PillChip: View {
    let title: String
    let selected: Bool
    var compact: Bool = true
    var action: () -> Void

    @Environment(\.colorScheme) private var scheme
    private var palette: Palette { Palette(dark: scheme == .dark) }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(compact ? F.pillCompact() : F.pill())
                .foregroundStyle(selected ? palette.onInk : palette.textSecondary)
                .padding(.horizontal, compact ? 11 : 14)
                .padding(.vertical, compact ? 6 : 7)
                .background(selected ? palette.ink : palette.surfaceAlt)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// 圆形图标按钮（搜索 / 筛选 / 返回）
struct CircleIconButton: View {
    let systemImage: String
    var size: CGFloat = 36
    var iconSize: CGFloat = 17
    var action: () -> Void

    @Environment(\.colorScheme) private var scheme
    private var palette: Palette { Palette(dark: scheme == .dark) }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(palette.textPrimary)
                .frame(width: size, height: size)
                .background(palette.surfaceAlt)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 普通键盘输入框（API 密钥）

/// 用 UITextField 包一层，专门避开系统「密码键盘」：
/// - 不走 secure entry，不会弹「自动填充密码 / 使用强密码」那一套
/// - textContentType 清空，避免 iOS 把这一格识别成密码栏
/// - ASCII 键盘，关掉联想、纠错、智能标点，粘贴 48 位十六进制密钥不会被打断
struct KeyField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var textColor: UIColor
    var placeholderColor: UIColor

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        field.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        field.keyboardType = .asciiCapable
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.smartInsertDeleteType = .no
        field.returnKeyType = .done
        field.clearButtonMode = .never
        field.isSecureTextEntry = false
        field.textContentType = UITextContentType(rawValue: "")
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        field.textColor = textColor
        field.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [
                .foregroundColor: placeholderColor,
                .font: UIFont.systemFont(ofSize: 14),
            ]
        )
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: KeyField

        init(_ parent: KeyField) { self.parent = parent }

        @objc func editingChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}

// MARK: - 加载占位

struct ShimmerView: View {
    @Environment(\.colorScheme) private var scheme
    @State private var animate = false

    var body: some View {
        let palette = Palette(dark: scheme == .dark)
        GeometryReader { geo in
            ZStack {
                palette.surfaceAlt
                LinearGradient(
                    colors: [Color.clear, palette.line.opacity(0.85), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: max(geo.size.width * 0.6, 1))
                .rotationEffect(.degrees(18))
                .offset(x: animate ? geo.size.width : -geo.size.width)
            }
            .clipped()
        }
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

// MARK: - 网络图片

struct RemoteImage: View {
    let url: String
    var fill: Bool = true

    @State private var image: UIImage?
    @State private var failed = false
    @Environment(\.colorScheme) private var scheme

    private var palette: Palette { Palette(dark: scheme == .dark) }

    var body: some View {
        ZStack {
            palette.surfaceAlt
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: fill ? .fill : .fit)
            } else if failed {
                Image(systemName: "photo")
                    .font(.system(size: 20))
                    .foregroundStyle(palette.textTertiary)
            } else {
                ShimmerView()
            }
        }
        .clipped()
        .task(id: url) {
            failed = false
            if let cached = ImageCache.shared.cached(url) {
                image = cached
                return
            }
            image = nil
            let loaded = await ImageCache.shared.load(url)
            if Task.isCancelled { return }
            image = loaded
            failed = loaded == nil
        }
    }
}

// MARK: - 卡片

struct WallpaperCard: View {
    let item: Wallpaper
    let width: CGFloat
    let showMeta: Bool
    let downloaded: Bool

    @Environment(\.colorScheme) private var scheme

    private var palette: Palette { Palette(dark: scheme == .dark) }
    private var height: CGFloat { max(48, width / item.clampedAspect) }

    var body: some View {
        RemoteImage(url: item.previewUrl, fill: true)
            .frame(width: width, height: height)
            .background(palette.surfaceAlt)
            .clipShape(RoundedRectangle(cornerRadius: M.cardRadius, style: .continuous))
            .overlay(alignment: .topLeading) {
                if showMeta && !item.sizeKbLabel.isEmpty {
                    badge(item.sizeKbLabel)
                        .padding(5)
                }
            }
            .overlay(alignment: .topTrailing) {
                if showMeta {
                    VStack(alignment: .trailing, spacing: 3) {
                        badge(item.viewsLabel, systemImage: "eye")
                        badge(item.favoritesLabel, systemImage: "heart")
                    }
                    .padding(5)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if downloaded {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(palette.downloaded)
                        .padding(6)
                }
            }
            .contentShape(Rectangle())
    }

    private func badge(_ text: String, systemImage: String? = nil) -> some View {
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .font(F.badge())
        }
        .foregroundStyle(palette.badgeText)
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background(palette.badgeBackground)
        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
        .fixedSize()
    }
}

// MARK: - 瀑布流（贪心分配两列，按较短列追加）

struct MasonryColumns: View {
    let items: [Wallpaper]
    let columns: Int
    let width: CGFloat
    let showMeta: Bool
    let downloadedIds: Set<String>
    let enableLoadMore: Bool
    let onOpen: (Wallpaper) -> Void
    let onLongPress: (Wallpaper) -> Void
    let onReachEnd: () -> Void

    private var columnCount: Int { max(columns, 1) }

    private var columnWidth: CGFloat {
        let n = CGFloat(columnCount)
        return max(1, (width - M.gridSpacing * (n - 1)) / n)
    }

    private var sets: [[Wallpaper]] {
        var result = Array(repeating: [Wallpaper](), count: columnCount)
        var heights = Array(repeating: CGFloat(0), count: columnCount)
        for item in items {
            var target = 0
            if heights.count > 1 {
                for index in 1..<heights.count where heights[index] < heights[target] {
                    target = index
                }
            }
            result[target].append(item)
            heights[target] += columnWidth / item.clampedAspect + M.gridSpacing
        }
        return result
    }

    private var triggerIds: Set<String> {
        guard enableLoadMore else { return [] }
        return Set(items.suffix(6).map { $0.id })
    }

    var body: some View {
        HStack(alignment: .top, spacing: M.gridSpacing) {
            ForEach(Array(sets.enumerated()), id: \.offset) { pair in
                LazyVStack(spacing: M.gridSpacing) {
                    ForEach(pair.element) { item in
                        WallpaperCard(
                            item: item,
                            width: columnWidth,
                            showMeta: showMeta,
                            downloaded: downloadedIds.contains(item.id)
                        )
                        .onTapGesture {
                            // 先塞进 LRU：详情页第一帧就能用真实数据渲染，不会白屏。
                            WallpaperCache.shared.put(item)
                            onOpen(item)
                        }
                        .onLongPressGesture(minimumDuration: 0.35) { onLongPress(item) }
                        .onAppear {
                            if triggerIds.contains(item.id) { onReachEnd() }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 空 / 错误态

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let subtitle: String
    var retryTitle: String? = nil
    var onRetry: (() -> Void)? = nil

    @Environment(\.colorScheme) private var scheme
    private var palette: Palette { Palette(dark: scheme == .dark) }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(palette.textTertiary)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.textPrimary)
            Text(subtitle)
                .font(F.bodySmall())
                .foregroundStyle(palette.textTertiary)
                .multilineTextAlignment(.center)
            if let retryTitle, let onRetry {
                Button(action: onRetry) {
                    Text(retryTitle)
                        .font(F.pill())
                        .foregroundStyle(palette.textPrimary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .overlay(Capsule().stroke(palette.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Toast

struct ToastView: View {
    let text: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let palette = Palette(dark: scheme == .dark)
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(palette.onInk)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(palette.ink)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
            .padding(.bottom, 92)
            .transition(.opacity)
    }
}
