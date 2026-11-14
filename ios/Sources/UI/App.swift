import SwiftUI

@main
struct HavenApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var favorites = FavoritesStore()
    @StateObject private var home = FeedStore()
    @StateObject private var toasts = ToastCenter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(favorites)
                .environmentObject(home)
                .environmentObject(toasts)
                .preferredColorScheme(settings.theme.colorScheme)
        }
    }
}

enum Tab: Hashable {
    case home
    case settings
}

enum Route: Hashable {
    case search
    case favorites
    case detail(String)
}

struct RootView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var home: FeedStore
    @EnvironmentObject private var toasts: ToastCenter
    @Environment(\.colorScheme) private var scheme

    @State private var tab: Tab = .home
    @State private var homePath: [Route] = []
    @State private var settingsPath: [Route] = []

    private var palette: Palette { Palette(dark: scheme == .dark) }

    var body: some View {
        ZStack(alignment: .bottom) {
            palette.background.ignoresSafeArea()

            // 原生 TabView：iOS 26 起底部栏是系统的液态玻璃胶囊（Liquid Glass），
            // 自带浮动、折射、滚动收起等系统行为，不再自己画胶囊。
            TabView(selection: $tab) {
                NavigationStack(path: $homePath) {
                    HomeView(
                        onOpenSearch: { homePath.append(.search) },
                        onOpenDetail: { homePath.append(.detail($0)) }
                    )
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationBarBackButtonHidden(true)
                    .navigationDestination(for: Route.self) { route in
                        destination(route, path: $homePath)
                    }
                }
                .tabItem { Label("首页", systemImage: "house.fill") }
                .tag(Tab.home)

                NavigationStack(path: $settingsPath) {
                    SettingsView(onOpenFavorites: { settingsPath.append(.favorites) })
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationBarBackButtonHidden(true)
                        .navigationDestination(for: Route.self) { route in
                            destination(route, path: $settingsPath)
                        }
                }
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
                .tag(Tab.settings)
            }
            .tint(palette.textPrimary)

            if let message = toasts.message {
                ToastView(text: message)
                    .animation(.easeInOut(duration: 0.18), value: toasts.message)
            }
        }
        .onOpenURL { url in
            if let id = RootView.wallpaperId(from: url) {
                tab = .home
                homePath.append(.detail(id))
            }
        }
    }

    @ViewBuilder
    private func destination(_ route: Route, path: Binding<[Route]>) -> some View {
        switch route {
        case .search:
            SearchView(
                onBack: { pop(path) },
                onOpenDetail: { path.wrappedValue.append(.detail($0)) }
            )
            // 搜索页有自己的顶部行（返回 + 标题 + 筛选），系统导航栏要让位。
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .tabBar)

        case .favorites:
            FavoritesView(
                onBack: { pop(path) },
                onOpenDetail: { path.wrappedValue.append(.detail($0)) }
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .tabBar)

        case .detail(let id):
            DetailView(
                id: id,
                onBack: { pop(path) },
                onOpenDetail: { path.wrappedValue.append(.detail($0)) }
            )
            // 详情页留系统导航栏：返回按钮就是系统玻璃圆钮，页面上不再叠第二套按钮。
            .toolbar(.visible, for: .navigationBar)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .tabBar)
        }
    }

    private func pop(_ path: Binding<[Route]>) {
        guard !path.wrappedValue.isEmpty else { return }
        path.wrappedValue.removeLast()
    }

    /// haven://w/{id}
    static func wallpaperId(from url: URL) -> String? {
        guard url.scheme?.lowercased() == "haven" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        if parts.count >= 2, parts[0].lowercased() == "w" { return parts[1] }
        return parts.last
    }
}
