import Foundation

/// 列表分页状态机：条件指纹去重 + 随机种子复用。
@MainActor
final class FeedStore: ObservableObject {
    @Published private(set) var items: [Wallpaper] = []
    @Published private(set) var loading = false
    @Published private(set) var loadingMore = false
    @Published private(set) var endReached = false
    @Published var error: String?

    private var params = FeedParams()
    private var page = 1
    private var lastPage = 1
    private var submittedKey: String?
    private var task: Task<Void, Never>?

    private var apiKey = ""

    /// 提交一组条件。与上次完全相同且列表非空时直接返回——
    /// 这是「进详情再返回，列表不跳回顶部」的关键。
    func submit(_ newParams: FeedParams, apiKey: String) {
        let key = newParams.key
        self.apiKey = apiKey
        if key == submittedKey && !items.isEmpty { return }
        submittedKey = key
        var fresh = newParams
        fresh.seed = nil
        params = fresh
        page = 1
        start(reset: true)
    }

    /// 重新加载（随机模式下换一批）。
    func reload(apiKey: String) {
        self.apiKey = apiKey
        if params.sorting == .random { params.seed = nil }
        page = 1
        start(reset: true)
    }

    func loadMore(apiKey: String) {
        self.apiKey = apiKey
        guard !loading, !loadingMore, !endReached else { return }
        start(reset: false)
    }

    func refresh(apiKey: String) async {
        reload(apiKey: apiKey)
        await task?.value
    }

    /// 供下拉刷新用：确保条件变化时也重新拉。
    func submitAndWait(_ newParams: FeedParams, apiKey: String) async {
        submit(newParams, apiKey: apiKey)
        await task?.value
    }

    private func start(reset: Bool) {
        task?.cancel()
        if reset {
            loading = true
            error = nil
            items = []
            endReached = false
        } else {
            loadingMore = true
        }

        let requestPage = reset ? 1 : page
        let requestParams = params
        let key = apiKey

        task = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await WallhavenAPI.shared.search(params: requestParams, page: requestPage, apiKey: key)
                if Task.isCancelled { return }
                if requestParams.sorting == .random, self.params.seed == nil {
                    self.params.seed = result.seed
                }
                if reset {
                    self.items = result.items
                } else {
                    let known = Set(self.items.map { $0.id })
                    self.items.append(contentsOf: result.items.filter { !known.contains($0.id) })
                }
                self.lastPage = result.lastPage
                self.endReached = requestPage >= result.lastPage || result.items.isEmpty
                if !self.endReached { self.page = requestPage + 1 } else { self.page = requestPage }
                self.error = nil
            } catch {
                if !Task.isCancelled {
                    self.error = (error as? APIError)?.message ?? error.localizedDescription
                }
            }
            self.loading = false
            self.loadingMore = false
        }
    }
}
