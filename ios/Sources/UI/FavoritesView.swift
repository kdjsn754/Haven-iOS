import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var toasts: ToastCenter
    @Environment(\.colorScheme) private var scheme

    let onBack: () -> Void
    let onOpenDetail: (String) -> Void

    @State private var pendingRemoval: Wallpaper?

    private var palette: Palette { Palette(dark: scheme == .dark) }

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(palette.background)
        .confirmationDialog(
            "取消收藏？",
            isPresented: Binding(
                get: { pendingRemoval != nil },
                set: { if !$0 { pendingRemoval = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("取消收藏", role: .destructive) {
                if let item = pendingRemoval {
                    favorites.remove(item.id)
                    toasts.show("已取消收藏")
                }
                pendingRemoval = nil
            }
            Button("再想想", role: .cancel) { pendingRemoval = nil }
        } message: {
            Text("这张壁纸会从收藏列表里移除")
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            CircleIconButton(systemImage: "chevron.left", size: 40, iconSize: 16, action: onBack)
            VStack(alignment: .leading, spacing: 1) {
                Text("收藏")
                    .font(F.pageTitle())
                    .foregroundStyle(palette.textPrimary)
                Text(favorites.count > 0 ? "\(favorites.count) 张壁纸" : "还是一片空白")
                    .font(.system(size: 11))
                    .foregroundStyle(palette.textTertiary)
            }
            Spacer()
        }
        .padding(.leading, 8)
        .padding(.trailing, 14)
        .padding(.top, 2)
        .padding(.bottom, 8)
    }

    private var content: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                if favorites.items.isEmpty {
                    EmptyStateView(
                        systemImage: "heart",
                        title: "还没有收藏",
                        subtitle: "在任意壁纸上长按，或在详情页点右上角的心形"
                    )
                    .frame(minHeight: max(geo.size.height * 0.65, 240))
                    .padding(.bottom, 40)
                } else {
                    MasonryColumns(
                        items: favorites.items,
                        columns: settings.columns,
                        width: geo.size.width - M.gridInset * 2,
                        showMeta: settings.showMeta,
                        downloadedIds: settings.downloadedIds,
                        enableLoadMore: false,
                        onOpen: { onOpenDetail($0.id) },
                        onLongPress: { pendingRemoval = $0 },
                        onReachEnd: {}
                    )
                    .padding(.horizontal, M.gridInset)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}
