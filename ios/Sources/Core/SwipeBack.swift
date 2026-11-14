import SwiftUI
import UIKit

// MARK: - 侧滑返回

/// SwiftUI 一旦隐藏导航栏、或用自绘返回按钮，系统就会把 `interactivePopGestureRecognizer` 关掉，
/// 手势返回随之失效。这里在页面出现后把它重新打开，并把 delegate 指给自己：
/// 只在栈里还有上一页时允许，根页面上不会莫名其妙地"侧滑退出"。
struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        Probe()
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}

    final class Probe: UIViewController, UIGestureRecognizerDelegate {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            enable()
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            enable()
        }

        private func enable() {
            guard let nav = navigationController,
                  let gesture = nav.interactivePopGestureRecognizer
            else { return }
            gesture.isEnabled = true
            gesture.delegate = self
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }
}

// MARK: - 再点一次当前底栏项：回到顶部

final class ScrollTopCenter: ObservableObject {
    @Published private(set) var homeTick = 0
    @Published private(set) var settingsTick = 0

    func reselect(_ tab: Tab) {
        switch tab {
        case .home: homeTick += 1
        case .settings: settingsTick += 1
        }
    }
}

/// 兜底监听底部栏点击：SwiftUI 的 TabView 不一定把「再点一次当前项」回传给 selection 绑定，
/// 这里直接在 UITabBar 上挂一个不吞事件的 tap，按点击位置算出是第几项。
struct TabBarTapObserver: UIViewControllerRepresentable {
    let onTap: (Int) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let probe = Probe()
        probe.onTap = onTap
        return probe
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        (controller as? Probe)?.onTap = onTap
    }

    final class Probe: UIViewController {
        var onTap: ((Int) -> Void)?

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let bar = tabBarController?.tabBar else { return }
            let installed = bar.gestureRecognizers?.contains { $0.name == "haven.tab.reselect" } ?? false
            guard !installed else { return }
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.name = "haven.tab.reselect"
            tap.cancelsTouchesInView = false
            bar.addGestureRecognizer(tap)
        }

        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let bar = gesture.view, bar.bounds.width > 0 else { return }
            let count = tabBarController?.viewControllers?.count ?? 2
            guard count > 0 else { return }
            let ratio = gesture.location(in: bar).x / bar.bounds.width
            let index = min(max(Int(ratio * CGFloat(count)), 0), count - 1)
            onTap?(index)
        }
    }
}
