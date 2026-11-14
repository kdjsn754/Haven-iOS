import Foundation

/// Wallhaven 官方 API 的轻量封装。
final class WallhavenAPI {
    static let shared = WallhavenAPI()

    private let base = "https://wallhaven.cc/api/v1"
    private let session: URLSession
    private let userAgent = "Haven/1.0 (iOS)"

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 45
        cfg.waitsForConnectivity = false
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: cfg)
    }

    func search(params: FeedParams, page: Int, apiKey: String) async throws -> SearchPage {
        var items = [
            URLQueryItem(name: "categories", value: params.categories),
            URLQueryItem(name: "purity", value: params.purity),
            URLQueryItem(name: "sorting", value: params.sorting.rawValue),
            URLQueryItem(name: "order", value: params.order),
            URLQueryItem(name: "page", value: String(page)),
        ]
        if !params.query.trimmingCharacters(in: .whitespaces).isEmpty {
            items.insert(URLQueryItem(name: "q", value: params.query.trimmingCharacters(in: .whitespaces)), at: 0)
        }
        if params.sorting == .toplist {
            items.append(URLQueryItem(name: "topRange", value: params.topRange))
        }
        if params.sorting == .random, let seed = params.seed, !seed.isEmpty {
            items.append(URLQueryItem(name: "seed", value: seed))
        }
        if !params.resolution.isEmpty { items.append(URLQueryItem(name: "resolutions", value: params.resolution)) }
        if !params.ratio.isEmpty { items.append(URLQueryItem(name: "ratios", value: params.ratio)) }
        if !params.color.isEmpty { items.append(URLQueryItem(name: "colors", value: params.color)) }
        if !apiKey.isEmpty { items.append(URLQueryItem(name: "apikey", value: apiKey)) }

        let root = try await getJSON(path: "/search", query: items)
        let meta = root["meta"] as? [String: Any]
        let data = root["data"] as? [[String: Any]] ?? []
        let list = data.compactMap { Wallpaper(json: $0) }
        let lastPage = (meta?["last_page"] as? NSNumber)?.intValue ?? 1
        let seedRaw = meta?["seed"] as? String
        let seed: String? = (seedRaw?.isEmpty == false && seedRaw != "null") ? seedRaw : nil
        return SearchPage(items: list, lastPage: max(lastPage, 1), seed: seed)
    }

    func similar(id: String, apiKey: String, purity: String) async throws -> [Wallpaper] {
        var items = [
            URLQueryItem(name: "similar", value: id),
            URLQueryItem(name: "purity", value: purity),
        ]
        if !apiKey.isEmpty { items.append(URLQueryItem(name: "apikey", value: apiKey)) }
        let root = try await getJSON(path: "/search", query: items)
        let data = root["data"] as? [[String: Any]] ?? []
        return data.compactMap { Wallpaper(json: $0) }.filter { $0.id != id }
    }

    func wallpaper(id: String, apiKey: String) async throws -> Wallpaper {
        var items: [URLQueryItem] = []
        if !apiKey.isEmpty { items.append(URLQueryItem(name: "apikey", value: apiKey)) }
        let root = try await getJSON(path: "/w/\(id)", query: items)
        guard let data = root["data"] as? [String: Any], let item = Wallpaper(json: data) else {
            throw APIError(message: "解析数据失败")
        }
        return item
    }

    /// 返回 nil 表示密钥有效，否则返回错误提示。
    func validateKey(_ key: String) async -> String? {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "请先填写 API 密钥" }
        var comps = URLComponents(string: base + "/settings")
        comps?.queryItems = [URLQueryItem(name: "apikey", value: trimmed)]
        guard let url = comps?.url else { return "网络异常，请检查连接" }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        do {
            let (_, response) = try await session.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            switch code {
            case 200: return nil
            case 401, 403: return "密钥无效，请检查后重试"
            case 429: return "请求过于频繁，请稍后再试"
            default: return "验证失败（HTTP \(code)）"
            }
        } catch {
            return "网络异常，请检查连接"
        }
    }

    // MARK: - 内部

    private func getJSON(path: String, query: [URLQueryItem]) async throws -> [String: Any] {
        var comps = URLComponents(string: base + path)
        comps?.queryItems = query
        guard let url = comps?.url else { throw APIError(message: "请求地址无效") }

        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        var fetched: (Data, URLResponse)?
        do {
            fetched = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw APIError(message: "网络连接失败，请检查网络后重试")
        }
        guard let pair = fetched else {
            throw APIError(message: "网络连接失败，请检查网络后重试")
        }
        let data = pair.0
        let response = pair.1

        let code = (response as? HTTPURLResponse)?.statusCode ?? 500
        guard (200..<300).contains(code) else {
            throw APIError(message: Self.friendlyError(code))
        }
        guard !data.isEmpty else { throw APIError(message: "服务器返回了空内容") }
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw APIError(message: "解析数据失败")
        }
        return root
    }

    private static func friendlyError(_ code: Int) -> String {
        switch code {
        case 401, 403: return "该内容需要 API 密钥，或密钥无效"
        case 404: return "内容不存在或已被删除"
        case 429: return "请求过于频繁，请稍后再试"
        case 500..<600: return "Wallhaven 服务暂时不可用"
        default: return "请求失败（HTTP \(code)）"
        }
    }
}
