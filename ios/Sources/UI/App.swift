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

    @State private var path: [Route] = []
    @State private var tab: Tab = .home

    private var palette: Palette { Palette(dark: scheme == .dark) }

    var body: some View {
        ZStack(alignment: .bottom) {
            palette.background.ignoresSafeArea()

            NavigationStack(path: $path) {
                Group {
                    switch tab {
                    case .home:
                        HomeView(
                            onOpenSearch: { path.append(.search) },
                            onOpenDetail: { path.append(.detail($0)) }
                        )
                    case .settings:
                        SettingsView(onOpenFavorites: { path.append(.favorites) })
                    }
                }
                .navigationBarBackButtonHidden(true)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Route.self) { route in
                    destination(route)
                }
            }

            if path.isEmpty {
                BottomBar(current: tab) { target in
                    guard target != tab else { return }
                    withAnimation(.easeInOut(duration: 0.18)) { tab = target }
                }
                .padding(.bottom, 8)
            }

            if let message = toasts.message {
                ToastView(text: message)
                    .animation(.easeInOut(duration: 0.18), value: toasts.message)
            }
        }
        .tint(palette.textPrimary)
        .onOpenURL { url in
            if let id = RootView.wallpaperId(from: url) {
                path.append(.detail(id))
            }
        }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .search:
            SearchView(
                onBack: pop,
                onOpenDetail: { path.append(.detail($0)) }
            )
        case .favorites:
            FavoritesView(
                onBack: pop,
                onOpenDetail: { path.append(.detail($0)) }
            )
        case .detail(let id):
            DetailView(
                id: id,
                onBack: pop,
                onOpenDetail: { path.append(.detail($0)) }
            )
        }
    }

    private func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// haven://w/{id}
    static func wallpaperId(from url: URL) -> String? {
        guard url.scheme?.lowercased() == "haven" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        if parts.count >= 2, parts[0].lowercased() == "w" { return parts[1] }
        return parts.last
    }
}
