import UIKit
import Network

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    static var transfers: TransferCoordinator?
    static var pendingBackgroundCompletion: (@MainActor @Sendable () -> Void)?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let appearance = UINavigationBarAppearance(); appearance.configureWithOpaqueBackground(); appearance.backgroundColor = SlateStyle.background
        UINavigationBar.appearance().standardAppearance = appearance; UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().tintColor = SlateStyle.accent; UITabBar.appearance().tintColor = SlateStyle.accent
        return true
    }
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        guard identifier == BackgroundTransferSession.identifier else { completionHandler(); return }
        let completion: @MainActor @Sendable () -> Void = { completionHandler() }
        if let transfers = Self.transfers { Task { await transfers.handleBackgroundEvents(completion: completion) } }
        else { Self.pendingBackgroundCompletion = completion }
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    var coordinator: AppCoordinator?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene); self.window = window
        window.rootViewController = UIViewController(); window.rootViewController?.view.backgroundColor = SlateStyle.background; window.makeKeyAndVisible()
        Task { @MainActor in
            do {
                let dependencies = try await DependencyContainer()
                let coordinator = AppCoordinator(window: window, dependencies: dependencies); self.coordinator = coordinator
                await coordinator.start()
            } catch {
                let screen = SlateScreen(); screen.loadViewIfNeeded(); screen.heading("Slate", subtitle: "Local storage could not be opened. Your data has been preserved.")
                screen.content.addArrangedSubview(SlateStyle.label(error.localizedDescription, style: .footnote))
                window.rootViewController = screen
            }
        }
    }
    func sceneDidBecomeActive(_ scene: UIScene) { coordinator?.becameActive() }
}

@MainActor
final class DependencyContainer {
    let api: APIClient
    let store: LocalStore
    let repository: ProjectRepository
    let media: MediaImporter
    let transfers: TransferCoordinator
    private let network = NWPathMonitor()
    private var wasConnected = false
    var user: User?
    init() async throws {
        let configured = UserDefaults.standard.string(forKey: "slate.apiURL") ?? "http://localhost:3000"
        api = APIClient(baseURL: URL(string: configured) ?? URL(string: "http://localhost:3000")!)
        store = try await LocalStore(); repository = ProjectRepository(api: api, store: store)
        media = try MediaImporter(); transfers = await TransferCoordinator(api: api, store: store, media: media)
        AppDelegate.transfers = transfers
        if let completion = AppDelegate.pendingBackgroundCompletion {
            AppDelegate.pendingBackgroundCompletion = nil
            await transfers.handleBackgroundEvents(completion: completion)
        }
        network.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor [weak self] in
                guard let self else { return }
                let recovered = connected && !self.wasConnected; self.wasConnected = connected
                guard recovered, self.user != nil else { return }
                do { try await self.repository.flushDrafts(); try await self.transfers.restore() } catch { /* Retry records remain durable. */ }
            }
        }
        network.start(queue: DispatchQueue(label: "com.slate.connectivity"))
    }
    deinit { network.cancel() }
}

@MainActor
final class AppCoordinator {
    let window: UIWindow
    let dependencies: DependencyContainer
    init(window: UIWindow, dependencies: DependencyContainer) { self.window = window; self.dependencies = dependencies }
    func start() async {
        do {
            dependencies.user = try await dependencies.repository.restoreSession()
            if let user = dependencies.user { try await dependencies.transfers.setAccount(ownerID: user.id) }
        } catch { dependencies.user = nil }
        if dependencies.user != nil { authenticated() } else { showAuthentication() }
    }
    func showAuthentication() {
        dependencies.user = nil
        let auth = AuthenticationController(dependencies: dependencies) { [weak self] in self?.authenticated() }
        window.rootViewController = UINavigationController(rootViewController: auth)
    }
    func authenticated() {
        let tabs = UITabBarController()
        let screens: [(UIViewController, String, String)] = [
            (DashboardController(dependencies: dependencies), "Overview", "square.grid.2x2"),
            (ProjectsController(dependencies: dependencies), "Projects", "folder"),
            (TransfersController(dependencies: dependencies), "Transfers", "arrow.up.circle"),
            (SettingsController(dependencies: dependencies, onLogout: { [weak self] in self?.showAuthentication() }), "Settings", "slider.horizontal.3")
        ]
        tabs.viewControllers = screens.map { screen, title, symbol in
            let nav = UINavigationController(rootViewController: screen); nav.navigationBar.prefersLargeTitles = true
            nav.tabBarItem = UITabBarItem(title: title, image: UIImage(systemName: symbol), selectedImage: nil); return nav
        }
        window.rootViewController = tabs
        becameActive()
    }
    func becameActive() {
        guard dependencies.user != nil else { return }
        Task {
            do {
                try await dependencies.transfers.setAccount(ownerID: dependencies.user?.id)
                await dependencies.transfers.setCellularAllowed(UserDefaults.standard.bool(forKey: "SlateCellularTransfers"))
                try await dependencies.transfers.restore(); try await dependencies.repository.flushDrafts()
            } catch { /* Persistent records retain recoverable errors for their screens. */ }
        }
    }
}
