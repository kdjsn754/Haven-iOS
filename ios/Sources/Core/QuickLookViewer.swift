import SwiftUI
import UIKit
import QuickLook

/// 系统原生图片查看器（Quick Look）。
///
/// QLPreviewController 只有在「自身被 present」时才会显示原生的 Done 按钮，
/// 直接嵌进 SwiftUI 的视图层级会丢掉关闭入口，所以这里用一个空容器 VC
/// 在出现后主动 present 它：捏合缩放、双击放大、拖动、右上角原生分享、
/// Done 关闭全部由 iOS 提供，App 不再自绘任何缩放界面。
///
/// 传入的必须是本地文件 URL（带扩展名），远程地址先用 ImageCache 落盘。
struct QuickLookViewer: UIViewControllerRepresentable {
    let url: URL
    let title: String

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> Presenter {
        let presenter = Presenter(url: url, title: title)
        presenter.onFinish = { dismiss() }
        return presenter
    }

    func updateUIViewController(_ controller: Presenter, context: Context) {}

    final class Presenter: UIViewController, QLPreviewControllerDataSource,
                           QLPreviewControllerDelegate, QLPreviewItem {
        private let url: URL
        private let itemTitle: String
        private var hasPresented = false
        var onFinish: (() -> Void)?

        init(url: URL, title: String) {
            self.url = url
            self.itemTitle = title
            super.init(nibName: nil, bundle: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            // 查看器滑上来之前先垫黑，避免露出底下的空白。
            view.backgroundColor = .black
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard !hasPresented else { return }
            hasPresented = true
            let preview = QLPreviewController()
            preview.dataSource = self
            preview.delegate = self
            present(preview, animated: true)
        }

        func previewControllerDidDismiss(_ controller: QLPreviewController) {
            onFinish?()
        }

        var previewItemURL: URL? { url }
        var previewItemTitle: String? { itemTitle }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController,
                               previewItemAt index: Int) -> QLPreviewItem {
            self
        }
    }
}
