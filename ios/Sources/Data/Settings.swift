import Foundation
import SwiftUI
import Security

// MARK: - Keychain

enum KeychainStore {
    private static let service = "com.haven.wallpapers"

    static func string(for key: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let text = String(data: data, encoding: .utf8)
        else { return "" }
        return text
    }

    static func set(_ value: String, for key: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        if value.isEmpty {
            SecItemDelete(base as CFDictionary)
            return
        }
        let data = Data(value.utf8)
        let status = SecItemUpdate(base as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = base
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }
}

// MARK: - 主题

enum ThemeMode: String, CaseIterable, Identifiable {
    case system = "SYSTEM"
    case light = "LIGHT"
    case dark = "DARK"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - 设置（键与 Android DataStore 一一对应）

final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var apiKey: String {
        didSet { KeychainStore.set(apiKey, for: "api_key") }
    }
    @Published var columns: Int {
        didSet { defaults.set(columns, forKey: "columns") }
    }
    @Published var theme: ThemeMode {
        didSet { defaults.set(theme.rawValue, forKey: "theme_mode") }
    }
    @Published var wifiOnly: Bool {
        didSet { defaults.set(wifiOnly, forKey: "wifi_only") }
    }
    @Published var showMeta: Bool {
        didSet { defaults.set(showMeta, forKey: "show_resolution") }
    }
    @Published var recentSearches: [String] {
        didSet { defaults.set(recentSearches, forKey: "recent_searches") }
    }
    @Published var filters: FilterState {
        didSet { defaults.set(filters.jsonObject, forKey: "feed_filters") }
    }
    @Published private(set) var downloadedIds: Set<String> {
        didSet { defaults.set(Array(downloadedIds), forKey: "downloaded_ids") }
    }

    init() {
        apiKey = KeychainStore.string(for: "api_key")
        let savedColumns = defaults.integer(forKey: "columns")
        columns = savedColumns == 3 ? 3 : 2
        theme = ThemeMode(rawValue: defaults.string(forKey: "theme_mode") ?? "") ?? .system
        wifiOnly = defaults.bool(forKey: "wifi_only")
        showMeta = defaults.object(forKey: "show_resolution") as? Bool ?? true
        recentSearches = defaults.stringArray(forKey: "recent_searches") ?? []
        filters = FilterState.from(json: defaults.dictionary(forKey: "feed_filters"))
        downloadedIds = Set(defaults.stringArray(forKey: "downloaded_ids") ?? [])
    }

    var hasApiKey: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var trimmedKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 统一出口：不做分级过滤，有密钥就放开全部内容（含限制级）；
    /// 没密钥时接口只认 100，交给 toParams 降级。
    func params(query: String = "") -> FeedParams {
        filters.toParams(query: query, apiKey: hasApiKey ? trimmedKey : "")
    }

    func addRecent(_ keyword: String) {
        let text = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        var list = recentSearches.filter { $0.caseInsensitiveCompare(text) != .orderedSame }
        list.insert(text, at: 0)
        if list.count > 12 { list = Array(list.prefix(12)) }
        recentSearches = list
    }

    func clearRecent() {
        recentSearches = []
    }

    func markDownloaded(_ id: String) {
        downloadedIds.insert(id)
    }

    func clearDownloaded() {
        downloadedIds = []
    }

    func isDownloaded(_ id: String) -> Bool {
        downloadedIds.contains(id)
    }
}

// MARK: - 收藏

final class FavoritesStore: ObservableObject {
    @Published private(set) var items: [Wallpaper] = []
    private let key = "favorites"
    private let defaults = UserDefaults.standard

    init() {
        load()
    }

    var count: Int { items.count }

    func isFavorite(_ id: String) -> Bool {
        items.contains { $0.id == id }
    }

    /// 返回切换后的状态（true = 已收藏）。
    @discardableResult
    func toggle(_ wallpaper: Wallpaper) -> Bool {
        if let index = items.firstIndex(where: { $0.id == wallpaper.id }) {
            items.remove(at: index)
            persist()
            return false
        }
        items.insert(wallpaper, at: 0)
        persist()
        return true
    }

    func remove(_ id: String) {
        items.removeAll { $0.id == id }
        persist()
    }

    func clear() {
        items = []
        persist()
    }

    private func load() {
        guard let raw = defaults.string(forKey: key), let data = raw.data(using: .utf8),
              let array = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]]
        else { return }
        items = array.compactMap { Wallpaper(json: $0) }
    }

    private func persist() {
        let array = items.map { $0.jsonObject }
        guard let data = try? JSONSerialization.data(withJSONObject: array),
              let text = String(data: data, encoding: .utf8)
        else { return }
        defaults.set(text, forKey: key)
    }
}

// MARK: - Toast

final class ToastCenter: ObservableObject {
    @Published var message: String?
    private var token = 0

    func show(_ text: String) {
        message = text
        token += 1
        let current = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self, self.token == current else { return }
            self.message = nil
        }
    }
}

// MARK: - 列表到详情的传参（LRU 80 条）

final class WallpaperCache {
    static let shared = WallpaperCache()

    private var map: [String: Wallpaper] = [:]
    private var order: [String] = []
    private let limit = 80

    func put(_ wallpaper: Wallpaper) {
        if map[wallpaper.id] == nil {
            order.append(wallpaper.id)
        } else if let index = order.firstIndex(of: wallpaper.id) {
            order.remove(at: index)
            order.append(wallpaper.id)
        }
        map[wallpaper.id] = wallpaper
        while order.count > limit {
            let oldest = order.removeFirst()
            map.removeValue(forKey: oldest)
        }
    }

    func get(_ id: String) -> Wallpaper? {
        map[id]
    }
}
