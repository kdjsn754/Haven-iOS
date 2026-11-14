import SwiftUI

// MARK: - 筛选面板

struct FilterSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    let onApply: (FilterState) -> Void

    @State private var draft: FilterState

    init(filters: FilterState, onApply: @escaping (FilterState) -> Void) {
        self.onApply = onApply
        _draft = State(initialValue: filters)
    }

    private var palette: Palette { Palette(dark: scheme == .dark) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: M.sectionSpacing) {
                    categorySection
                    sortingSection
                    if draft.sorting == .toplist { topRangeSection }
                    resolutionSection
                    ratioSection
                    colorSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
            applyButton
        }
        .background(palette.background)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private var header: some View {
        HStack {
            Text("筛选")
                .font(F.sheetTitle())
                .foregroundStyle(palette.textPrimary)
            Spacer()
            Button {
                draft = FilterState()
            } label: {
                Text("重置")
                    .font(F.body())
                    .foregroundStyle(palette.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(palette.textSecondary)
            content()
        }
    }

    private var categorySection: some View {
        section("类别") {
            FlowLayout(spacing: M.chipSpacing, lineSpacing: M.chipSpacing) {
                ForEach(FilterState.allCategories, id: \.0) { item in
                    PillChip(title: item.1, selected: draft.categories.contains(item.0)) {
                        toggleCategory(item.0)
                    }
                }
            }
        }
    }

    private var sortingSection: some View {
        section("排序") {
            FlowLayout(spacing: M.chipSpacing, lineSpacing: M.chipSpacing) {
                ForEach(Sorting.allCases) { option in
                    PillChip(title: option.label, selected: draft.sorting == option) {
                        draft.sorting = option
                    }
                }
            }
        }
    }

    private var topRangeSection: some View {
        section("排行范围") {
            FlowLayout(spacing: M.chipSpacing, lineSpacing: M.chipSpacing) {
                ForEach(Presets.topRanges) { option in
                    PillChip(title: option.label, selected: draft.topRange == option.api) {
                        draft.topRange = option.api
                    }
                }
            }
        }
    }

    private var resolutionSection: some View {
        section("分辨率") {
            FlowLayout(spacing: M.chipSpacing, lineSpacing: M.chipSpacing) {
                PillChip(title: "不限", selected: draft.resolution.isEmpty) {
                    draft.resolution = ""
                }
                ForEach(Presets.resolutions, id: \.0) { option in
                    PillChip(title: option.1, selected: draft.resolution == option.0) {
                        draft.resolution = draft.resolution == option.0 ? "" : option.0
                    }
                }
            }
        }
    }

    private var ratioSection: some View {
        section("长宽比") {
            FlowLayout(spacing: M.chipSpacing, lineSpacing: M.chipSpacing) {
                PillChip(title: "不限", selected: draft.ratio.isEmpty) {
                    draft.ratio = ""
                }
                ForEach(Presets.ratios, id: \.0) { option in
                    PillChip(title: option.1, selected: draft.ratio == option.0) {
                        draft.ratio = draft.ratio == option.0 ? "" : option.0
                    }
                }
            }
        }
    }

    private var colorSection: some View {
        section("颜色") {
            FlowLayout(spacing: 10, lineSpacing: 10) {
                Button {
                    draft.color = ""
                } label: {
                    Text("不限")
                        .font(F.label())
                        .foregroundStyle(draft.color.isEmpty ? palette.onInk : palette.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(draft.color.isEmpty ? palette.ink : palette.surfaceAlt)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                ForEach(Presets.colors, id: \.self) { hex in
                    Button {
                        draft.color = draft.color == hex ? "" : hex
                    } label: {
                        Circle()
                            .fill(Color(hexString: hex) ?? palette.surfaceAlt)
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle().stroke(
                                    draft.color == hex ? palette.textPrimary : palette.line,
                                    lineWidth: draft.color == hex ? 2 : 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var applyButton: some View {
        Button {
            onApply(draft)
            dismiss()
        } label: {
            Text("查看结果")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(palette.onInk)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(palette.ink)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(palette.background)
    }

    private func toggleCategory(_ key: String) {
        if draft.categories.contains(key) {
            if draft.categories.count > 1 { draft.categories.remove(key) }
        } else {
            draft.categories.insert(key)
        }
    }
}

// MARK: - 快捷操作面板

struct QuickActionSheet: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var toasts: ToastCenter
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    let wallpaper: Wallpaper
    let onOpenDetail: () -> Void

    @State private var saving = false

    private var palette: Palette { Palette(dark: scheme == .dark) }
    private var isFavorite: Bool { favorites.isFavorite(wallpaper.id) }

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            Rectangle()
                .fill(palette.line)
                .frame(height: 1)
            actionRow(
                icon: isFavorite ? "heart.slash" : "heart",
                title: isFavorite ? "取消收藏" : "加入收藏",
                tint: isFavorite ? palette.like : nil
            ) {
                let added = favorites.toggle(wallpaper)
                toasts.show(added ? "已加入收藏" : "已取消收藏")
                dismiss()
            }
            divider
            actionRow(icon: "arrow.down", title: saving ? "保存中…" : "下载到相册", tint: nil) {
                Task { await download() }
            }
            divider
            ShareLink(item: wallpaper.shareText) {
                HStack(spacing: 14) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 20))
                        .foregroundStyle(palette.textPrimary)
                        .frame(width: 20)
                    Text("分享链接")
                        .font(F.body())
                        .foregroundStyle(palette.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            divider
            actionRow(icon: "info.circle", title: "查看详情", tint: nil) {
                dismiss()
                onOpenDetail()
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
        .background(palette.background)
        .presentationDetents([.height(392)])
        .presentationDragIndicator(.visible)
    }

    private var headerRow: some View {
        HStack(spacing: 12) {
            RemoteImage(url: wallpaper.previewUrl, fill: true)
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(wallpaper.resolutionLabel)
                    .font(F.titleMedium())
                    .foregroundStyle(palette.textPrimary)
                Text("\(wallpaper.formatLabel) · \(wallpaper.fileSizeLabel) · \(wallpaper.categoryLabel)")
                    .font(F.bodySmall())
                    .foregroundStyle(palette.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    private var divider: some View {
        Rectangle()
            .fill(palette.line)
            .frame(height: 1)
            .padding(.horizontal, 10)
    }

    private func actionRow(icon: String, title: String, tint: Color?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(tint ?? palette.textPrimary)
                    .frame(width: 20)
                Text(title)
                    .font(F.body())
                    .foregroundStyle(tint ?? palette.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @MainActor
    private func download() async {
        guard !saving else { return }
        saving = true
        defer { saving = false }
        do {
            try await MediaStore.shared.saveToAlbum(wallpaper)
            settings.markDownloaded(wallpaper.id)
            toasts.show("已保存到相册 · Haven")
            dismiss()
        } catch {
            toasts.show((error as? MediaError)?.errorDescription ?? "保存失败，请稍后再试")
        }
    }
}
