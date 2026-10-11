import UIKit

final class SettingsController: SlateScreen {
    let dependencies: DependencyContainer
    let onLogout: () -> Void
    init(dependencies: DependencyContainer, onLogout: @escaping () -> Void) { self.dependencies = dependencies; self.onLogout = onLogout; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad(); title = "Settings"; heading("Your workspace.", subtitle: dependencies.user?.email)
        section("Account"); content.addArrangedSubview(InfoRow(title: dependencies.user?.displayName ?? "Creator", detail: "Session credentials are held in the iOS Keychain.", symbol: "person.crop.circle"))
        section("Transfers")
        let toggle = UISwitch(); toggle.isOn = UserDefaults.standard.bool(forKey: "SlateCellularTransfers"); toggle.addTarget(self, action: #selector(cellularChanged), for: .valueChanged)
        let row = UIStackView(arrangedSubviews: [SlateStyle.label("Allow cellular uploads"), toggle]); row.spacing = 16; content.addArrangedSubview(row)
        content.addArrangedSubview(SlateStyle.label("Applies to new part requests. Existing background tasks keep their current network policy. Transfers use at most two simultaneous part uploads.", style: .footnote, color: .secondaryLabel))
        content.addArrangedSubview(SlateStyle.button("Clear cached project data", symbol: "trash", primary: false) { [weak self] in self?.clearCache() })
        section("Slate 1.0")
        content.addArrangedSubview(InfoRow(title: "Reliable media delivery", detail: "UIKit · Core Data · Background URLSession\nPayments and delivery access are verified by your server.", symbol: "lock.shield"))
        #if DEBUG
        content.addArrangedSubview(SlateStyle.label("Development build · local or sandbox payments only. Server: \(UserDefaults.standard.string(forKey: "slate.apiURL") ?? "http://localhost:3000")", style: .caption1, color: .secondaryLabel))
        #endif
        content.addArrangedSubview(SlateStyle.button("Sign out", symbol: "rectangle.portrait.and.arrow.right", primary: false) { [weak self] in self?.logout() }); content.arrangedSubviews.last?.accessibilityIdentifier = "settings.logout"
    }
    @objc func cellularChanged(_ toggle: UISwitch) { UserDefaults.standard.set(toggle.isOn, forKey: "SlateCellularTransfers"); Task { await dependencies.transfers.setCellularAllowed(toggle.isOn) } }
    func clearCache() {
        perform { [self] in
            let scope = try await dependencies.repository.accountID()
            try await dependencies.store.remove(scope: scope, kind: "project")
            URLCache.shared.removeAllCachedResponses()
            let alert = UIAlertController(title: "Cache cleared", message: "Project snapshots were removed. Transfer files and pending drafts remain saved.", preferredStyle: .alert); alert.addAction(UIAlertAction(title: "OK", style: .default)); present(alert, animated: true)
        }
    }
    func logout() {
        let alert = UIAlertController(title: "Sign out?", message: "Active transfers are paused. Their files remain saved for your next sign-in.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Sign out", style: .destructive) { [weak self] _ in
            guard let self else { return }
            self.perform { try await self.dependencies.transfers.setAccount(ownerID: nil); try await self.dependencies.repository.logout(); self.onLogout() }
        }); alert.addAction(UIAlertAction(title: "Cancel", style: .cancel)); present(alert, animated: true)
    }
}
