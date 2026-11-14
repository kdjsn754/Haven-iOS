import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var favorites: FavoritesStore
    @Environment(\.colorScheme) private var scheme

    let onOpenDetail: (String) -> Void

    @StateObject private var results = FeedStore()
    @State private var query = ""
    @State private var searched = false
    @State private var showFilter = false
    @State private var quick: Wallpaper?
    @FocusState private var focused: Bool

    private var palette: Palette { Palette(dark: scheme == .dark) }

    var body: some View {
        VStack(spacing: 0) {
            topRow
            searchField
            Spacer(minLength: 10)
            content
        }
        .background(palette.background)
        .background(SwipeBackEnabler())
        .toolbar {
            // 筛选放进系统导航栏：拿到原生玻璃圆钮、原生点击态与无障碍语义。
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showFilter = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                }
                .accessibilityLabel("筛选")
            }
        }
        .onChange(of: settings.filters) { _, _ in
            if searched { runSearch(keepFocus: false) }
        }
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

    // MARK: 顶部

    private var topRow: some View {
        HStack(spacing: 8) {
            Text("搜索")
                .font(F.pageTitle())
                .foregroundStyle(palette.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
        .padding(.bottom, 10)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 19, weight: .regular))
                .foregroundStyle(palette.textTertiary)
            TextField("", text: $query, prompt: Text("搜索壁纸，试试英文关键词").foregroundColor(palette.textTertiary))
                .font(F.body())
                .foregroundStyle(palette.textPrimary)
                .focused($focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { runSearch() }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(palette.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(palette.surfaceAlt)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 14)
    }

    // MARK: 内容

    @ViewBuilder
    private var content: some View {
        if !searched {
            suggestions
        } else {
            resultsArea
        }
    }

    private var suggestions: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                if !settings.recentSearches.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("最近搜索")
                                .font(F.titleSmall())
                                .foregroundStyle(palette.textSecondary)
                            Spacer()
                            Button {
                                settings.clearRecent()
                            } label: {
                                Text("清空")
                                    .font(F.label())
                                    .foregroundStyle(palette.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        FlowLayout(spacing: 8, lineSpacing: 8) {
                            ForEach(settings.recentSearches, id: \.self) { item in
                                Button {
                                    query = item
                                    runSearch()
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "clock")
                                            .font(.system(size: 14))
                                        Text(item)
                                            .font(F.bodySmall())
                                    }
                                    .foregroundStyle(palette.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(palette.surfaceAlt)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("随便看看")
                        .font(F.titleSmall())
                        .foregroundStyle(palette.textSecondary)
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(Presets.quickTags, id: \.self) { tag in
                            Button {
                                query = tag
                                runSearch()
                            } label: {
                                Text(tag)
                                    .font(F.bodySmall())
                                    .foregroundStyle(palette.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(palette.surfaceAlt)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("小提示")
                        .font(F.label())
                        .foregroundStyle(palette.textSecondary)
                    Text("Wallhaven 的标签以英文为主；用颜色、分辨率和比例筛选，往往比关键词更好找。")
                        .font(F.bodySmall())
                        .foregroundStyle(palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(palette.surfaceAlt)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 40)
        }
    }

    private var resultsArea: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    if results.items.isEmpty {
                        stateArea
                            .frame(minHeight: max(geo.size.height * 0.6, 240))
                    } else {
                        MasonryColumns(
                            items: results.items,
                            columns: settings.columns,
                            width: geo.size.width - M.gridInset * 2,
                            showMeta: settings.showMeta,
                            downloadedIds: settings.downloadedIds,
                            enableLoadMore: true,
                            onOpen: { onOpenDetail($0.id) },
                            onLongPress: { quick = $0 },
                            onReachEnd: { results.loadMore(apiKey: settings.trimmedKey) }
                        )
                        .padding(.horizontal, M.gridInset)

                        if results.loadingMore {
                            ProgressView()
                                .frame(width: 22, height: 22)
                                .tint(palette.textTertiary)
                                .padding(.vertical, 14)
                        } else if results.endReached {
                            Text("到底啦")
                                .font(F.bodySmall())
                                .foregroundStyle(palette.textTertiary)
                                .padding(.vertical, 14)
                        }
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }

    @ViewBuilder
    private var stateArea: some View {
        if results.loading {
            ProgressView()
                .tint(palette.textSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = results.error {
            EmptyStateView(
                systemImage: "wifi.exclamationmark",
                title: "搜索失败",
                subtitle: error,
                retryTitle: "重试",
                onRetry: { runSearch() }
            )
        } else {
            EmptyStateView(
                systemImage: "magnifyingglass",
                title: "没有找到相关壁纸",
                subtitle: "换个英文关键词，或者放宽筛选条件"
            )
        }
    }

    private func runSearch(keepFocus: Bool = false) {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        searched = true
        settings.addRecent(text)
        if !keepFocus { focused = false }
        results.submit(settings.params(query: text), apiKey: settings.trimmedKey)
    }
}
