import SwiftUI
import UIKit

struct DetailView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var toasts: ToastCenter
    @Environment(\.colorScheme) private var scheme

    let id: String
    let onBack: () -> Void
    let onOpenDetail: (String) -> Void

    @State private var wallpaper: Wallpaper?
    @State private var similar: [Wallpaper] = []
    @State private var errorMessage: String?
    @State private var loading = true
    @State private var saving = false
    @State private var showFullscreen = false

    private var palette: Palette { Palette(dark: scheme == .dark) }
    private var isFavorite: Bool { favorites.isFavorite(id) }
    private var preview: Wallpaper? { WallpaperCache.shared.get(id) }

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        hero(width: geo.size.width, maxHeight: geo.size.height * 0.66)

                        if let item = wallpaper {
                            actionRow(item)
                            infoSection(item) {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    proxy.scrollTo("similar", anchor: .top)
                                }
                            }
                            if !item.tags.isEmpty || !item.colors.isEmpty {
                                tagSection(item)
                            }
                            if !similar.isEmpty {
                                similarSection(item, width: geo.size.width)
                                    .id("similar")
                            }
                        } else if loading {
                            ProgressView()
                                .tint(palette.textSecondary)
                                .padding(.top, 60)
                        } else if let errorMessage {
                            EmptyStateView(
                                systemImage: "exclamationmark.triangle",
                                title: "打不开这张壁纸",
                                subtitle: errorMessage,
                                retryTitle: "重试",
                                onRetry: { Task { await load() } }
                            )
                            .padding(.top, 48)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .background(palette.background)
        // 页面本身已经有系统导航栏的返回（玻璃圆钮）和下方操作行的收藏，
        // 大图上不再叠一套半透明圆形按钮。
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                }
                .accessibilityLabel("返回")
            }
        }
        .task(id: id) { await load() }
        .fullScreenCover(isPresented: $showFullscreen) {
            if let item = wallpaper ?? preview {
                FullscreenViewer(url: item.path)
            }
        }
    }

    // MARK: 大图

    private func hero(width: CGFloat, maxHeight: CGFloat) -> some View {
        let item = wallpaper ?? preview
        let ratio = item?.clampedAspect ?? 16.0 / 9.0
        let height = min(width / ratio, maxHeight)
        return ZStack {
            palette.surfaceAlt
            if let url = item?.path, !url.isEmpty {
                RemoteImage(url: url, fill: false)
                    .frame(width: width, height: height)
            } else {
                ShimmerView()
                    .frame(width: width, height: height)
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture {
            if settingImageReady { showFullscreen = true }
        }
    }

    private var settingImageReady: Bool {
        let item = wallpaper ?? preview
        return item != nil
    }

    // MARK: 操作行

    private func actionRow(_ item: Wallpaper) -> some View {
        HStack(spacing: 0) {
            Button {
                Task { await download(item) }
            } label: {
                actionLabel(
                    icon: saving ? "arrow.down.circle" : "arrow.down",
                    title: saving ? "保存中" : "下载",
                    filled: true,
                    tint: nil
                )
            }
            .buttonStyle(.plain)

            ShareLink(item: item.shareText) {
                actionLabel(icon: "square.and.arrow.up", title: "分享", filled: false, tint: nil)
            }
            .buttonStyle(.plain)

            Button(action: toggleFavorite) {
                actionLabel(
                    icon: isFavorite ? "checkmark" : "heart",
                    title: isFavorite ? "已收藏" : "收藏",
                    filled: false,
                    tint: isFavorite ? palette.like : nil
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
    }

    private func actionLabel(icon: String, title: String, filled: Bool, tint: Color?) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(filled ? palette.onInk : (tint ?? palette.textPrimary))
                .frame(width: 44, height: 44)
                .background(filled ? palette.ink : palette.surfaceAlt)
                .clipShape(Circle())
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(tint ?? palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    // MARK: 信息行

    private func infoSection(_ item: Wallpaper, onJumpSimilar: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            infoRow(icon: "person", label: "上传者", value: item.uploaderLabel, tappable: false, action: nil)
            infoRow(
                icon: "link",
                label: "链接",
                value: "wallhaven.cc/w/\(item.id)",
                tappable: true,
                action: { copyLink(item) }
            )
            infoRow(icon: "eye", label: "浏览量", value: item.viewsWanLabel, tappable: false, action: nil)
            infoRow(icon: "heart", label: "收藏量", value: "\(item.favorites)", tappable: false, action: nil)
            infoRow(icon: "ruler", label: "分辨率", value: item.resolutionLabel, tappable: false, action: nil)
            infoRow(icon: "doc", label: "体积", value: item.fileSizeLabel, tappable: false, action: nil)
            infoRow(icon: "calendar", label: "上传时间", value: item.dateTimeLabel, tappable: false, action: nil)
            infoRow(
                icon: "tag",
                label: "分类",
                value: "\(item.purityLabel), \(item.categoryLabel), \(item.fileType)",
                tappable: false,
                action: nil
            )
            infoRow(
                icon: "square.on.square",
                label: "相似壁纸",
                value: similar.isEmpty ? "暂无相似壁纸" : "点击查看 \(similar.count) 张相似图片",
                tappable: !similar.isEmpty,
                action: onJumpSimilar
            )
        }
        .padding(.top, 2)
    }

    private func infoRow(
        icon: String,
        label: String,
        value: String,
        tappable: Bool,
        action: (() -> Void)?
    ) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(palette.textTertiary)
                    .frame(width: 16)
                Text(label)
                    .font(F.bodySmall())
                    .foregroundStyle(palette.textTertiary)
                    .frame(width: 64, alignment: .leading)
                Text(value)
                    .font(F.body())
                    .foregroundStyle(tappable ? palette.textPrimary : palette.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!tappable)
    }

    // MARK: 标签与色板

    private func tagSection(_ item: Wallpaper) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !item.tags.isEmpty {
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(Array(item.tags.prefix(14)), id: \.self) { tag in
                        Text(tag)
                            .font(F.bodySmall())
                            .foregroundStyle(palette.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(palette.surfaceAlt)
                            .clipShape(Capsule())
                    }
                }
            }
            if !item.colors.isEmpty {
                HStack(spacing: 8) {
                    ForEach(Array(item.colors.prefix(8)), id: \.self) { hex in
                        Circle()
                            .fill(Color(hexString: hex) ?? palette.surfaceAlt)
                            .frame(width: 20, height: 20)
                            .overlay(Circle().stroke(palette.line, lineWidth: 1))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 4)
    }

    // MARK: 相似壁纸

    private func similarSection(_ item: Wallpaper, width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("相似壁纸")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(palette.textSecondary)
                .padding(.horizontal, 16)
            MasonryColumns(
                items: similar,
                columns: 2,
                width: width - M.gridInset * 2,
                showMeta: false,
                downloadedIds: settings.downloadedIds,
                enableLoadMore: false,
                onOpen: { onOpenDetail($0.id) },
                onLongPress: { _ in },
                onReachEnd: {}
            )
            .padding(.horizontal, M.gridInset)
        }
        .padding(.top, 16)
    }

    // MARK: 动作

    private func toggleFavorite() {
        guard let item = wallpaper ?? preview else { return }
        let added = favorites.toggle(item)
        toasts.show(added ? "已加入收藏" : "已取消收藏")
    }

    private func copyLink(_ item: Wallpaper) {
        UIPasteboard.general.string = item.url
        toasts.show("链接已复制")
    }

    @MainActor
    private func download(_ item: Wallpaper) async {
        guard !saving else { return }
        saving = true
        defer { saving = false }
        do {
            try await MediaStore.shared.saveToAlbum(item)
            settings.markDownloaded(item.id)
            toasts.show("已保存到相册 · Haven")
        } catch {
            toasts.show((error as? MediaError)?.errorDescription ?? "保存失败，请稍后再试")
        }
    }

    @MainActor
    private func load() async {
        if wallpaper == nil { wallpaper = WallpaperCache.shared.get(id) }
        if wallpaper != nil { loading = false }

        do {
            let detail = try await WallhavenAPI.shared.wallpaper(id: id, apiKey: settings.trimmedKey)
            wallpaper = detail
            WallpaperCache.shared.put(detail)
            errorMessage = nil
        } catch {
            if wallpaper == nil {
                errorMessage = (error as? APIError)?.message ?? error.localizedDescription
            }
        }
        loading = false

        let purity = settings.params().purity
        if let list = try? await WallhavenAPI.shared.similar(
            id: id,
            apiKey: settings.trimmedKey,
            purity: purity
        ) {
            similar = Array(list.prefix(8))
        }
    }
}

// MARK: - 全屏查看

struct FullscreenViewer: View {
    let url: String

    @Environment(\.dismiss) private var dismiss

    @State private var image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var baseScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var baseOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(dragGesture)
                    .simultaneousGesture(magnifyGesture)
                    .onTapGesture(count: 2) { toggleZoom() }
                    .onTapGesture { if scale <= 1.01 { dismiss() } }
            } else {
                ProgressView()
                    .tint(.white)
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .frame(width: 42, height: 42)
                            .background(Color.white.opacity(0.14))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
        }
        .statusBarHidden(true)
        .task {
            image = await ImageCache.shared.load(url)
        }
    }

    private var magnifyGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(baseScale * value, 1), 6)
            }
            .onEnded { _ in
                baseScale = scale
                if scale <= 1.01 { resetTransform() }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1 else { return }
                offset = CGSize(
                    width: baseOffset.width + value.translation.width,
                    height: baseOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                baseOffset = offset
            }
    }

    private func toggleZoom() {
        withAnimation(.easeOut(duration: 0.22)) {
            if scale > 1.2 {
                scale = 1
                baseScale = 1
                offset = .zero
                baseOffset = .zero
            } else {
                scale = 2.5
                baseScale = 2.5
            }
        }
    }

    private func resetTransform() {
        withAnimation(.easeOut(duration: 0.2)) {
            scale = 1
            baseScale = 1
            offset = .zero
            baseOffset = .zero
        }
    }
}
