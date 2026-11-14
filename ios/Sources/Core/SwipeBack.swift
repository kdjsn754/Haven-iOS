import SwiftUI
import UIKit

// MARK: - 侧滑返回

/// SwiftUI 一旦隐藏导航栏（`.toolbar(.hidden)`）、或用自绘返回按钮，系统就会把
/// `interactivePopGestureRecognizer` 关掉，手势返回随之失效。
///
/// 这里在页面出现后把它重新打开，并把 delegate 指给自己：
/// 只在栈里还有上一页、且当前没有转场在跑时允许，根页面上不会莫名其妙地"侧滑退出"。
///
/// ⚠️ 关键点：**不能只开一次**。系统在 `setNavigationBarHidden` 里会直接把手势置
/// `isEnabled = false`，而 `.toolbar(.hidden)` 的生效时机在 push 转场的过程中，
/// 经常晚于 `viewDidAppear`——一次性打开会被系统随后覆盖回去，表现就是
/// 「有些页面能滑、有些页面滑不动」。所以这里三个时机都补：
///   1. 生命周期（didMove / viewDidAppear / viewDidLayoutSubviews）
///   2. 下一次 runloop（转场结束那一帧）
///   3. 在屏期间的低频巡检（0.4s，只读一下 isEnabled，页面离屏立刻停）
struct SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        Probe()
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}

    final class Probe: UIViewController, UIGestureRecognizerDelegate {
        private var sweep: Timer?

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            enable()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            enable()
            startSweep()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            enable()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            stopSweep()
        }

        deinit {
            sweep?.invalidate()
        }

        // MARK: 巡检

        private func startSweep() {
            DispatchQueue.main.async { [weak self] in self?.enable() }
            guard sweep == nil else { return }
            let timer = Timer(timeInterval: 0.4, repeats: true) { [weak self] timer in
                guard let self else {
                    timer.invalidate()
                    return
                }
                // 页面已经离屏（被 push 盖住 / tab 切走）：停掉，别空转
                guard self.view.window != nil else {
                    timer.invalidate()
                    self.sweep = nil
                    return
                }
                self.enable()
            }
            RunLoop.main.add(timer, forMode: .common)
            sweep = timer
        }

        private func stopSweep() {
            sweep?.invalidate()
            sweep = nil
        }

        // MARK: 打开手势

        private func enable() {
            guard let nav = hostNavigationController,
                  let gesture = nav.interactivePopGestureRecognizer
            else { return }
            if gesture.delegate !== self {
                gesture.delegate = self
            }
            if !gesture.isEnabled {
                gesture.isEnabled = true
            }
        }

        /// 正常情况下 `navigationController` 就能拿到；拿不到时沿 parent 链、
        /// 再从窗口根控制器里找当前那个导航栈，避免被 SwiftUI 的容器层级坑到。
        private var hostNavigationController: UINavigationController? {
            if let nav = navigationController { return nav }
            var node = parent
            while let current = node {
                if let nav = current as? UINavigationController { return nav }
                node = current.parent
            }
            return Probe.findNav(from: view.window?.rootViewController)
        }

        private static func findNav(from controller: UIViewController?) -> UINavigationController? {
            guard let controller else { return nil }
            if let nav = controller as? UINavigationController {
                // 取最上层那个正在显示的子栈（TabView 里每个 tab 一个栈）
                if let visible = nav.visibleViewController,
                   let nested = findNav(from: visible) {
                    return nested
                }
                return nav
            }
            for child in controller.children.reversed() {
                if let found = findNav(from: child) { return found }
            }
            if let presented = controller.presentedViewController {
                return findNav(from: presented)
            }
            return nil
        }

        // MARK: 只在能返回时允许

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let nav = hostNavigationController else { return false }
            // 栈里得有上一页
            guard nav.viewControllers.count > 1 else { return false }
            // 正在转场时别接手势，否则容易把导航栏状态搞乱
            guard nav.transitionCoordinator == nil else { return false }
            guard nav.topViewController?.transitionCoordinator == nil else { return false }
            return true
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
