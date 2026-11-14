import Foundation
import CoreGraphics

// MARK: - 排序

enum Sorting: String, CaseIterable, Identifiable, Hashable {
    case dateAdded = "date_added"
    case toplist
    case random
    case views
    case favorites
    case relevance

    var id: String { rawValue }

    var label: String {
        switch self {
        case .dateAdded: return "最新"
        case .toplist: return "热门"
        case .random: return "随机"
        case .views: return "浏览"
        case .favorites: return "收藏"
        case .relevance: return "相关"
        }
    }
}

struct TopRangeOption: Identifiable, Hashable {
    let api: String
    let label: String
    var id: String { api }
}

enum Presets {
    static let topRanges: [TopRangeOption] = [
        .init(api: "1d", label: "今天"),
        .init(api: "3d", label: "三天"),
        .init(api: "1w", label: "一周"),
        .init(api: "1M", label: "一月"),
        .init(api: "3M", label: "三月"),
        .init(api: "6M", label: "半年"),
        .init(api: "1y", label: "一年"),
    ]

    /// (api 值, 展示文案)
    static let resolutions: [(String, String)] = [
        ("1920x1080", "1920×1080"),
        ("2560x1440", "2560×1440"),
        ("3840x2160", "3840×2160"),
        ("1080x1920", "1080×1920"),
        ("1440x2560", "1440×2560"),
        ("2160x3840", "2160×3840"),
        ("3440x1440", "3440×1440"),
        ("1280x720", "1280×720"),
    ]

    static let ratios: [(String, String)] = [
        ("16x9", "16:9"),
        ("16x10", "16:10"),
        ("4x3", "4:3"),
        ("5x4", "5:4"),
        ("9x16", "竖屏 9:16"),
        ("32x9", "32:9"),
    ]

    static let colors: [String] = [
        "660000", "990000", "cc0000", "ea4c88", "993399", "663399",
        "333399", "0066cc", "0099cc", "66cccc", "77cc33", "336600",
        "666600", "999900", "cccc33", "ffff00", "ffcc33", "ff9900",
        "ff6600", "cc6633", "996633", "663300", "000000", "999999",
        "cccccc", "ffffff", "424153",
    ]

    static let quickTags: [String] = [
        "minimal", "nature", "landscape", "city", "space", "abstract",
        "anime", "sunset", "dark", "ocean", "mountain", "cyberpunk",
    ]
}

// MARK: - 筛选条件

struct FilterState: Equatable {
    var sorting: Sorting = .dateAdded
    var topRange: String = "1M"
    var categories: Set<String> = ["general", "anime", "people"]
    var resolution: String = ""
    var ratio: String = ""
    var color: String = ""

    static let allCategories: [(String, String)] = [
        ("general", "常规"), ("anime", "动漫"), ("people", "人物"),
    ]

    var categoryParam: String {
        let bits = ["general", "anime", "people"].map { categories.contains($0) ? "1" : "0" }.joined()
        return bits == "000" ? "111" : bits
    }

    var hasFilters: Bool {
        categories != ["general", "anime", "people"]
            || !resolution.isEmpty
            || !ratio.isEmpty
            || !color.isEmpty
    }

    /// 应用不做分级过滤：始终 111（安全 + 粗略 + 限制级全给）。
    /// 实测无密钥时接口也接受 111，只是悄悄把 nsfw 剔掉，不会报错；
    /// 填了密钥之后同一份请求就会带回限制级内容。
    func toParams(query: String = "", apiKey: String = "") -> FeedParams {
        FeedParams(
            query: query,
            sorting: sorting,
            topRange: topRange,
            categories: categoryParam,
            purity: "111",
            resolution: resolution,
            ratio: ratio,
            color: color
        )
    }

    var jsonObject: [String: Any] {
        [
            "sorting": sorting.rawValue,
            "top_range": topRange,
            "categories": Array(categories),
            "resolution": resolution,
            "ratio": ratio,
            "color": color,
        ]
    }

    static func from(json: [String: Any]?) -> FilterState {
        guard let json else { return FilterState() }
        var state = FilterState()
        if let raw = json["sorting"] as? String, let s = Sorting(rawValue: raw) { state.sorting = s }
        if let top = json["top_range"] as? String, !top.isEmpty { state.topRange = top }
        if let cats = json["categories"] as? [String], !cats.isEmpty { state.categories = Set(cats) }
        if let res = json["resolution"] as? String { state.resolution = res }
        if let ratio = json["ratio"] as? String { state.ratio = ratio }
        if let color = json["color"] as? String { state.color = color }
        return state
    }
}

// MARK: - 请求参数

struct FeedParams: Equatable {
    var query: String = ""
    var sorting: Sorting = .dateAdded
    var topRange: String = "1M"
    var categories: String = "111"
    var purity: String = "100"
    var resolution: String = ""
    var ratio: String = ""
    var color: String = ""
    var order: String = "desc"
    var seed: String? = nil

    /// 条件指纹：相同就不重复提交，从详情返回时列表不会跳回顶部。
    var key: String {
        [query, sorting.rawValue, topRange, categories, purity, resolution, ratio, color, order, seed ?? ""]
            .joined(separator: "|")
    }
}

// MARK: - 壁纸

struct Wallpaper: Identifiable, Hashable {
    let id: String
    let url: String
    let shortUrl: String
    let views: Int
    let favorites: Int
    let purity: String
    let category: String
    let dimensionX: Int
    let dimensionY: Int
    let resolution: String
    let ratio: String
    let fileSize: Int64
    let fileType: String
    let createdAt: String
    let path: String
    let thumbLarge: String
    let thumbSmall: String
    let colors: [String]
    let uploader: String?
    let tags: [String]

    var aspect: CGFloat {
        if dimensionX > 0 && dimensionY > 0 {
            return CGFloat(dimensionX) / CGFloat(dimensionY)
        }
        return 16.0 / 9.0
    }

    /// 卡片高度用的比例，夹在 0.42…2.6，避免极端长图把一列拉爆。
    var clampedAspect: CGFloat {
        min(max(aspect, 0.42), 2.6)
    }

    /// 列表用的预览图。
    ///
    /// thumbs.large 是 432×243 的固定比例中心裁切图，竖图直接用会切得面目全非；
    /// thumbs.original 才是等比缩放的（长边 300px），所以非 16:9 附近一律换成 /orig/。
    var previewUrl: String {
        guard thumbLarge.contains("/lg/") else { return thumbLarge }
        if aspect >= 1.70 && aspect <= 1.87 { return thumbLarge }
        return thumbLarge.replacingOccurrences(of: "/lg/", with: "/orig/")
    }

    var resolutionLabel: String {
        resolution.isEmpty ? "" : resolution.replacingOccurrences(of: "x", with: " × ")
    }

    var isPortrait: Bool { dimensionY > dimensionX }
    var isNsfw: Bool { purity == "nsfw" }

    var sizeKbLabel: String {
        fileSize <= 0 ? "" : "\(fileSize / 1024)Kb"
    }

    var fileSizeLabel: String {
        guard fileSize > 0 else { return "" }
        let mb = Double(fileSize) / 1024.0 / 1024.0
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        return String(format: "%.0f KB", Double(fileSize) / 1024.0)
    }

    var viewsLabel: String { Self.compact(views) }
    var favoritesLabel: String { Self.compact(favorites) }

    var formatLabel: String {
        let part = fileType.split(separator: "/").last.map(String.init) ?? ""
        return part.isEmpty ? "IMG" : part.uppercased()
    }

    var categoryLabel: String {
        switch category {
        case "anime": return "动漫"
        case "people": return "人物"
        default: return "常规"
        }
    }

    var purityLabel: String {
        switch purity {
        case "sketchy": return "粗略"
        case "nsfw": return "限制"
        default: return "安全"
        }
    }

    var dateLabel: String { String(createdAt.prefix(10)) }

    /// "2024-05-11 10:22" → "2024-05-11 10:22"，只做 ISO 的轻量整理
    var dateTimeLabel: String {
        guard let t = createdAt.firstIndex(of: "T") else { return dateLabel }
        let rest = createdAt[createdAt.index(after: t)...]
        return dateLabel + " " + String(rest.prefix(5))
    }

    var uploaderLabel: String { uploader ?? "匿名" }

    var pathExtension: String {
        let part = fileType.split(separator: "/").last.map(String.init) ?? "jpg"
        return part == "jpeg" ? "jpg" : part
    }

    var shareText: String { "\(url)\n via Haven" }

    static func compact(_ n: Int) -> String {
        if n >= 1000 {
            let v = Double(n) / 1000.0
            return v >= 10 ? String(format: "%.0fk", v) : String(format: "%.1fk", v)
        }
        return "\(n)"
    }

    /// 详情页的「12.3 万」
    var viewsWanLabel: String {
        if views >= 10000 {
            return String(format: "%.1f 万", Double(views) / 10000.0)
        }
        return "\(views)"
    }

    // MARK: JSON

    init?(json: [String: Any]) {
        guard let id = json["id"] as? String, !id.isEmpty else { return nil }
        self.id = id
        self.url = json["url"] as? String ?? ""
        self.shortUrl = json["short_url"] as? String ?? ""
        self.views = Self.int(json["views"])
        self.favorites = Self.int(json["favorites"])
        self.purity = json["purity"] as? String ?? "sfw"
        self.category = json["category"] as? String ?? "general"
        self.dimensionX = Self.int(json["dimension_x"])
        self.dimensionY = Self.int(json["dimension_y"])
        self.resolution = json["resolution"] as? String ?? ""
        self.ratio = json["ratio"] as? String ?? ""
        self.fileSize = Self.long(json["file_size"])
        self.fileType = json["file_type"] as? String ?? "image/jpeg"
        self.createdAt = json["created_at"] as? String ?? ""
        self.path = json["path"] as? String ?? ""

        let thumbs = json["thumbs"] as? [String: Any]
        let large = thumbs?["large"] as? String ?? json["thumb_large"] as? String ?? ""
        let small = thumbs?["small"] as? String ?? json["thumb_small"] as? String ?? ""
        self.thumbLarge = large.isEmpty ? self.path : large
        self.thumbSmall = small.isEmpty ? self.path : small

        self.colors = (json["colors"] as? [String]) ?? []
        if let up = json["uploader"] as? [String: Any] {
            let name = up["username"] as? String ?? ""
            self.uploader = name.isEmpty ? nil : name
        } else if let up = json["uploader"] as? String, !up.isEmpty {
            self.uploader = up
        } else {
            self.uploader = nil
        }
        if let rawTags = json["tags"] as? [[String: Any]] {
            self.tags = rawTags.compactMap { $0["name"] as? String }
        } else if let rawTags = json["tags"] as? [String] {
            self.tags = rawTags
        } else {
            self.tags = []
        }
    }

    var jsonObject: [String: Any] {
        var dict: [String: Any] = [
            "id": id,
            "url": url,
            "short_url": shortUrl,
            "views": views,
            "favorites": favorites,
            "purity": purity,
            "category": category,
            "dimension_x": dimensionX,
            "dimension_y": dimensionY,
            "resolution": resolution,
            "ratio": ratio,
            "file_size": fileSize,
            "file_type": fileType,
            "created_at": createdAt,
            "path": path,
            "thumb_large": thumbLarge,
            "thumb_small": thumbSmall,
            "colors": colors,
            "tags": tags,
        ]
        if let uploader { dict["uploader"] = uploader }
        return dict
    }

    private static func int(_ any: Any?) -> Int {
        if let v = any as? Int { return v }
        if let v = any as? NSNumber { return v.intValue }
        if let v = any as? String, let i = Int(v) { return i }
        return 0
    }

    private static func long(_ any: Any?) -> Int64 {
        if let v = any as? Int64 { return v }
        if let v = any as? Int { return Int64(v) }
        if let v = any as? NSNumber { return v.int64Value }
        if let v = any as? String, let i = Int64(v) { return i }
        return 0
    }
}

struct SearchPage {
    let items: [Wallpaper]
    let lastPage: Int
    let seed: String?
}

struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
