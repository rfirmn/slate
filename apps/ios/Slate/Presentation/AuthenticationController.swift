import UIKit

final class AuthenticationController: SlateScreen {
    let dependencies: DependencyContainer
    let onAuthenticated: () -> Void
    let model: AuthenticationViewModel
    let email = SlateStyle.field("Email address", id: "auth.email", keyboard: .emailAddress)
    let password = SlateStyle.field("Password", id: "auth.password")
    let name = SlateStyle.field("Your name", id: "auth.name")
    let mode = UISegmentedControl(items: ["Sign in", "Create account"])
    var submit: UIButton!
    init(dependencies: DependencyContainer, onAuthenticated: @escaping () -> Void) { self.dependencies = dependencies; self.onAuthenticated = onAuthenticated; self.model = AuthenticationViewModel(repository: dependencies.repository); super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad(); navigationItem.title = "SLATE"
        heading("From project\nto payment.", subtitle: "A considered workspace for your creative work. Organize, deliver, and get paid with confidence.")
        content.setCustomSpacing(32, after: content.arrangedSubviews.last!)
        mode.selectedSegmentIndex = 0; mode.addTarget(self, action: #selector(changeMode), for: .valueChanged); content.addArrangedSubview(mode)
        name.isHidden = true; name.textContentType = .name; content.addArrangedSubview(name)
        email.autocapitalizationType = .none; email.autocorrectionType = .no; email.textContentType = .username
        password.isSecureTextEntry = true; password.textContentType = .password
        content.addArrangedSubview(email); content.addArrangedSubview(password)
        submit = SlateStyle.button("Sign in", symbol: "arrow.right") { [weak self] in self?.signIn() }; submit.accessibilityIdentifier = "auth.submit"
        content.addArrangedSubview(submit); content.addArrangedSubview(message)
        content.addArrangedSubview(InfoRow(title: "Your work, securely delivered", detail: "Payments are verified by the server. Originals stay private until delivery is released.", symbol: "lock.shield"))
        #if DEBUG
        content.addArrangedSubview(SlateStyle.button("Use local demo account", primary: false) { [weak self] in
            self?.email.text = "demo@slate.local"; self?.password.text = "SlateDemo2026!"
        })
        content.addArrangedSubview(SlateStyle.label("Development server: configure its URL below. Demo account requires the database seed.", style: .caption1, color: .secondaryLabel))
        content.addArrangedSubview(SlateStyle.button("Configure server", symbol: "network", primary: false) { [weak self] in self?.configureServer() })
        #endif
    }
    @objc func changeMode() {
        name.isHidden = mode.selectedSegmentIndex == 0; password.textContentType = mode.selectedSegmentIndex == 0 ? .password : .newPassword
        submit.configuration?.title = mode.selectedSegmentIndex == 0 ? "Sign in" : "Create account"
    }
    func signIn() {
        guard !busy else { return }
        let address = email.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let secret = password.text ?? ""
        let displayName = mode.selectedSegmentIndex == 1 ? name.text?.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        if let validation = AuthenticationViewModel.validation(email: address, password: secret, displayName: displayName) { message.text = validation; return }
        busy = true; submit.isEnabled = false; submit.configuration?.showsActivityIndicator = true; message.text = nil
        Task { @MainActor in
            defer { busy = false; submit.isEnabled = true; submit.configuration?.showsActivityIndicator = false }
            do { dependencies.user = try await model.authenticate(email: address, password: secret, displayName: displayName); try await dependencies.transfers.setAccount(ownerID: dependencies.user?.id); onAuthenticated() }
            catch { message.text = error.localizedDescription }
        }
    }
    func configureServer() {
        let alert = UIAlertController(title: "Development server", message: "Use http://localhost:3000 in Simulator, or your Mac's LAN URL on an iPhone. Restart Slate after changing the URL.", preferredStyle: .alert)
        alert.addTextField { $0.text = UserDefaults.standard.string(forKey: "slate.apiURL") ?? "http://localhost:3000"; $0.keyboardType = .URL; $0.autocapitalizationType = .none }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            guard let text = alert.textFields?.first?.text, let url = URL(string: text), ["http", "https"].contains(url.scheme ?? ""), url.host != nil else { return }
            UserDefaults.standard.set(text, forKey: "slate.apiURL")
        }); alert.addAction(UIAlertAction(title: "Cancel", style: .cancel)); present(alert, animated: true)
    }
}
