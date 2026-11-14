import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var home: FeedStore
    @EnvironmentObject private var favorites: FavoritesStore

    @Environment(\.colorScheme) private var scheme

    let onOpenSearch: () -> Void
    let onOpenDetail: (String) -> Void

    @State private var showFilter = false
    @State private var quick: Wallpaper?

    private var palette: Palette { Palette(dark: scheme == .dark) }
    private var sortOptions: [Sorting] { [.dateAdded, .toplist, .random, .favorites] }
    private var apiKey: String { settings.apiKey.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            content
        }
        .background(palette.background)
        .onAppear { submit() }
        .onChange(of: settings.filters) { _, _ in submit() }
        .onChange(of: settings.apiKey) { _, _ in submit() }
        .onChange(of: settings.showNsfw) { _, _ in submit() }
        .sheet(isPresented: $showFilter) {
            FilterSheet(filters: settings.filters) { updated in
                settings.filters = updated
            }
        }
        .sheet(item: $quick) { item in
            QuickActionSheet(wallpaper: item) {
                onOpenDetail(item.id)
            }
        }
    }

    // MARK: 顶部一行

    private var topBar: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(sortOptions) { option in
                        PillChip(title: option.label, selected: settings.filters.sorting == option) {
                            select(option)
                        }
                    }
                }
                .padding(.leading, 4)
                .padding(.vertical, 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            CircleIconButton(systemImage: "magnifyingglass", action: onOpenSearch)
            CircleIconButton(systemImage: "line.3.horizontal.decrease", action: { showFilter = true })
        }
        .padding(.leading, 6)
        .padding(.trailing, 8)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    // MARK: 瀑布流

    private var content: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    if home.items.isEmpty {
                        stateArea
                            .frame(minHeight: max(geo.size.height * 0.72, 260))
                    } else {
                        MasonryColumns(
                            items: home.items,
                            columns: settings.columns,
                            width: geo.size.width - M.gridInset * 2,
                            showMeta: settings.showMeta,
                            downloadedIds: settings.downloadedIds,
                            enableLoadMore: true,
                            onOpen: { onOpenDetail($0.id) },
                            onLongPress: { quick = $0 },
                            onReachEnd: { home.loadMore(apiKey: apiKey) }
                        )
                        .padding(.horizontal, M.gridInset)

                        footer
                    }
                }
                .padding(.bottom, 14)
            }
            .refreshable {
                await home.refresh(apiKey: apiKey)
            }
        }
    }

    @ViewBuilder
    private var stateArea: some View {
        if home.loading {
            ProgressView()
                .tint(palette.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = home.error {
            EmptyStateView(
                systemImage: "wifi.exclamationmark",
                title: "加载失败",
                subtitle: error,
                retryTitle: "重试",
                onRetry: { home.reload(apiKey: apiKey) }
            )
        } else {
            EmptyStateView(
                systemImage: "sparkles",
                title: "这里还很安静",
                subtitle: "换个筛选条件试试"
            )
        }
    }

    @ViewBuilder
    private var footer: some View {
        if home.loadingMore {
            ProgressView()
                .frame(width: 22, height: 22)
                .tint(palette.textTertiary)
                .padding(.vertical, 14)
        } else if home.endReached {
            Text("到底啦")
                .font(F.bodySmall())
                .foregroundStyle(palette.textTertiary)
                .padding(.vertical, 14)
        } else {
            Color.clear.frame(height: 14)
        }
    }

    private func select(_ option: Sorting) {
        if settings.filters.sorting == option {
            if option == .random { home.reload(apiKey: apiKey) }
            return
        }
        settings.filters.sorting = option
    }

    private func submit() {
        home.submit(settings.params(query: ""), apiKey: apiKey)
    }
}
