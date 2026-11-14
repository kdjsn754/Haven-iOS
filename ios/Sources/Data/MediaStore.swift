import Foundation
import Photos
import UIKit

// MARK: - 图片缓存（内存 + 磁盘）

final class ImageCache {
    static let shared = ImageCache()

    private let memory = NSCache<NSString, UIImage>()
    private let dir: URL

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("HavenImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        memory.countLimit = 240
    }

    private func fileURL(_ key: String) -> URL {
        var hash: UInt64 = 1469598103934665603
        for byte in key.utf8 {
            hash = (hash ^ UInt64(byte)) &* 1099511628211
        }
        return dir.appendingPathComponent(String(hash, radix: 16))
    }

    func cached(_ url: String) -> UIImage? {
        if let image = memory.object(forKey: url as NSString) { return image }
        guard let data = try? Data(contentsOf: fileURL(url)), let image = UIImage(data: data) else { return nil }
        memory.setObject(image, forKey: url as NSString)
        return image
    }

    func load(_ url: String) async -> UIImage? {
        if let cached = cached(url) { return cached }
        guard let link = URL(string: url) else { return nil }
        var request = URLRequest(url: link)
        request.setValue("Haven/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let image = UIImage(data: data) else { return nil }
        memory.setObject(image, forKey: url as NSString)
        try? data.write(to: fileURL(url))
        return image
    }

    func clear() {
        memory.removeAllObjects()
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    /// 缓存占用的粗略大小（MB），只用于设置页展示。
    func diskSizeMB() -> Double {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        let total = files.reduce(0) { partial, item in
            let size = (try? item.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return partial + size
        }
        return Double(total) / 1024.0 / 1024.0
    }
}

// MARK: - 下载 / 相册

enum MediaError: LocalizedError {
    case denied
    case download
    case save
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .denied: return "没有相册写入权限，请到 设置 › Haven 里打开"
        case .download: return "图片下载失败，请检查网络后重试"
        case .save: return "写入相册失败"
        case .invalidURL: return "图片地址无效"
        }
    }
}

final class MediaStore {
    static let shared = MediaStore()
    private let albumTitle = "Haven"

    /// 下载原图 → 写入「照片」的 Haven 相簿。
    func saveToAlbum(_ wallpaper: Wallpaper) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        guard status == .authorized || status == .limited else { throw MediaError.denied }
        guard let link = URL(string: wallpaper.path) else { throw MediaError.invalidURL }

        var request = URLRequest(url: link)
        request.setValue("Haven/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 45
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              !data.isEmpty,
              ((response as? HTTPURLResponse)?.statusCode ?? 200) < 400
        else { throw MediaError.download }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("haven_\(wallpaper.id).\(wallpaper.pathExtension)")
        do {
            try data.write(to: fileURL)
        } catch {
            throw MediaError.save
        }

        let album = try await ensureAlbum()
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let creation = PHAssetCreationRequest.forAsset()
                creation.addResource(with: .photo, fileURL: fileURL, options: nil)
                if let album, let placeholder = creation.placeholderForCreatedAsset {
                    PHAssetCollectionChangeRequest(for: album)?.addAssets([placeholder] as NSArray)
                }
            }
        } catch {
            try? FileManager.default.removeItem(at: fileURL)
            throw MediaError.save
        }
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func ensureAlbum() async throws -> PHAssetCollection? {
        if let existing = fetchAlbum() { return existing }
        var placeholder: PHObjectPlaceholder?
        try await PHPhotoLibrary.shared().performChanges {
            let creation = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: self.albumTitle)
            placeholder = creation.placeholderForCreatedAssetCollection
        }
        guard let localId = placeholder?.localIdentifier else { return nil }
        return PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [localId], options: nil).firstObject
    }

    private func fetchAlbum() -> PHAssetCollection? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", albumTitle)
        return PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: options).firstObject
    }
}
