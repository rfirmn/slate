import UIKit

final class DashboardController: SlateScreen {
    let dependencies: DependencyContainer
    init(dependencies: DependencyContainer) { self.dependencies = dependencies; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() { super.viewDidLoad(); title = "Slate"; navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .refresh, primaryAction: UIAction { [weak self] _ in self?.refresh() }) }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); refresh() }
    func refresh() {
        perform { [self] in
            let projects = try await dependencies.repository.projects()
            let transfers = await dependencies.transfers.transfers()
            clear(); heading("Make room\nfor the work.", subtitle: "Welcome back, \(dependencies.user?.displayName ?? "creator"). Here is where things stand.")
            if await dependencies.repository.servingCachedData { content.addArrangedSubview(InfoRow(title: "Offline · saved snapshots", detail: "Payments and delivery may have changed. Reconnect and refresh to verify their current status.", symbol: "icloud.slash")) }
            content.addArrangedSubview(SlateStyle.button("New project", symbol: "plus") { [weak self] in self?.createProject() })
            section("Your workspace")
            content.addArrangedSubview(InfoRow(title: "\(projects.filter { ![.completed, .cancelled].contains($0.status) }.count) active projects", detail: "From the first brief to the final handoff", symbol: "folder"))
            let pending = projects.compactMap(\.invoice).filter { $0.status == .issued }
            content.addArrangedSubview(InfoRow(title: SlateStyle.money(pending.reduce(Int64(0)) { $0 + $1.totalMinor }), detail: "Awaiting verified payment · \(pending.count) invoices", symbol: "doc.text"))
            content.addArrangedSubview(InfoRow(title: "\(transfers.filter { ![.completed, .cancelled].contains($0.state) }.count) files in the queue", detail: "Your transfer progress is saved on this device", symbol: "arrow.up.circle"))
            section("Recent projects")
            if projects.isEmpty { content.addArrangedSubview(InfoRow(title: "Start with a brief", detail: "Create a project, define the deliverables, then bring your media into Slate.", symbol: "sparkles")) }
            for project in projects.prefix(4) {
                content.addArrangedSubview(SlateStyle.button(project.title, symbol: "arrow.up.right", primary: false) { [weak self] in
                    guard let self else { return }; self.navigationController?.pushViewController(ProjectDetailController(dependencies: self.dependencies, project: project), animated: true)
                })
                content.addArrangedSubview(SlateStyle.label("\(project.client.name) · \(SlateStyle.status(project.status.rawValue))", style: .caption1, color: .secondaryLabel))
            }
            let drafts = try await dependencies.repository.pendingDrafts()
            if !drafts.isEmpty { content.addArrangedSubview(InfoRow(title: "\(drafts.count) local drafts", detail: "Saved securely on this device. Open Projects to synchronize them.", symbol: "icloud.slash")) }
        }
    }
    func createProject() { present(UINavigationController(rootViewController: CreateProjectController(dependencies: dependencies, onSaved: { [weak self] in self?.refresh() })), animated: true) }
}

final class ProjectsController: UITableViewController, UISearchResultsUpdating {
    let dependencies: DependencyContainer
    let model: ProjectsViewModel
    var projects: [Project] { model.projects }
    var drafts: [PendingDraft] { model.drafts }
    let search = UISearchController(searchResultsController: nil)
    let filter = UISegmentedControl(items: ["All", "Active", "Ready"])
    var visible: [Project] {
        model.filtered(query: search.searchBar.text ?? "", scope: filter.selectedSegmentIndex)
    }
    init(dependencies: DependencyContainer) { self.dependencies = dependencies; self.model = ProjectsViewModel(repository: dependencies.repository); super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad(); title = "Projects"; tableView.backgroundColor = SlateStyle.background
        search.searchResultsUpdater = self; search.obscuresBackgroundDuringPresentation = false; navigationItem.searchController = search
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .add, primaryAction: UIAction { [weak self] _ in
            guard let self else { return }; self.present(UINavigationController(rootViewController: CreateProjectController(dependencies: self.dependencies, onSaved: { [weak self] in self?.refresh() })), animated: true)
        }); navigationItem.rightBarButtonItem?.accessibilityIdentifier = "projects.create"
        filter.selectedSegmentIndex = 0; filter.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        let header = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 64)); header.addSubview(filter); filter.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([filter.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20), filter.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20), filter.centerYAnchor.constraint(equalTo: header.centerYAnchor)])
        tableView.tableHeaderView = header; refreshControl = UIRefreshControl(); refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)
    }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); refresh() }
    @objc func filterChanged() { tableView.reloadData() }
    func updateSearchResults(for searchController: UISearchController) { tableView.reloadData() }
    @objc func refresh() {
        Task { @MainActor in
            defer { refreshControl?.endRefreshing() }
            do {
                try await model.refresh(); tableView.reloadData()
                tableView.backgroundView = projects.isEmpty && drafts.isEmpty ? SlateStyle.label("Your next project starts here.\nTap + to create one.", color: .secondaryLabel) : nil
                (tableView.backgroundView as? UILabel)?.textAlignment = .center
            } catch { let alert = UIAlertController(title: "Unable to refresh", message: error.localizedDescription, preferredStyle: .alert); alert.addAction(UIAlertAction(title: "OK", style: .default)); present(alert, animated: true) }
        }
    }
    override func numberOfSections(in tableView: UITableView) -> Int { drafts.isEmpty ? 1 : 2 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? visible.count : drafts.count + 1 }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { section == 0 ? "Project workspace" : "Local drafts · waiting to sync" }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil); var config = cell.defaultContentConfiguration()
        if indexPath.section == 0 {
            let p = visible[indexPath.row]; config.text = p.title; config.secondaryText = "\(p.client.name)\n\(SlateStyle.status(p.status.rawValue)) · \(p.invoice.map { SlateStyle.status($0.status.rawValue) } ?? "No invoice")\nDelivery: \(SlateStyle.status(p.deliveryStatus))"
            config.image = UIImage(systemName: "folder"); cell.accessoryType = .disclosureIndicator; cell.accessibilityIdentifier = "project.\(p.id)"
        } else if indexPath.row == drafts.count { config.text = "Synchronize drafts"; config.image = UIImage(systemName: "arrow.triangle.2.circlepath") }
        else { config.text = drafts[indexPath.row].payload.title; config.secondaryText = drafts[indexPath.row].error ?? "Saved on this device"; config.image = UIImage(systemName: "icloud.slash") }
        config.imageProperties.tintColor = SlateStyle.accent; config.textProperties.font = .preferredFont(forTextStyle: .headline); config.secondaryTextProperties.font = .preferredFont(forTextStyle: .subheadline)
        cell.contentConfiguration = config; return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 { navigationController?.pushViewController(ProjectDetailController(dependencies: dependencies, project: visible[indexPath.row]), animated: true) }
        else if indexPath.row == drafts.count {
            Task { @MainActor in
                do { try await dependencies.repository.flushDrafts(); refresh() }
                catch { let alert = UIAlertController(title: "Drafts kept locally", message: error.localizedDescription, preferredStyle: .alert); alert.addAction(UIAlertAction(title: "OK", style: .default)); present(alert, animated: true) }
            }
        } else { editDraft(drafts[indexPath.row]) }
    }
    func editDraft(_ draft: PendingDraft) {
        guard draft.safeToEdit == true else {
            let alert = UIAlertController(title: "Synchronize before editing", message: "This request may already have reached the server. Slate keeps its original payload and request key until the result is known.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default)); present(alert, animated: true); return
        }
        let alert = UIAlertController(title: "Edit local draft", message: "This draft has not reached the server.", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Title"; $0.text = draft.payload.title }
        alert.addTextField { $0.placeholder = "Description"; $0.text = draft.payload.description }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self else { return }; var payload = draft.payload
            payload.title = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""; payload.description = alert.textFields?[1].text ?? ""
            guard !payload.title.isEmpty else { return }
            Task { @MainActor in
                do { try await self.dependencies.repository.updateDraft(id: draft.id, payload: payload); self.refresh() }
                catch { let errorAlert = UIAlertController(title: "Draft preserved", message: error.localizedDescription, preferredStyle: .alert); errorAlert.addAction(UIAlertAction(title: "OK", style: .default)); self.present(errorAlert, animated: true) }
            }
        })
        alert.addAction(UIAlertAction(title: "Discard draft", style: .destructive) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in do { try await self.dependencies.repository.discardDraft(id: draft.id); self.refresh() } catch { self.refresh() } }
        }); alert.addAction(UIAlertAction(title: "Cancel", style: .cancel)); present(alert, animated: true)
    }
}

final class CreateProjectController: SlateScreen {
    let dependencies: DependencyContainer
    let onSaved: (() -> Void)?
    let titleField = SlateStyle.field("Project title", id: "project.title")
    let descriptionField = SlateStyle.field("Brief / description", id: "project.description")
    let output = SlateStyle.field("Deliverable title (e.g. Campaign photographs)", id: "project.deliverable")
    let quantity = SlateStyle.field("Expected quantity", id: "project.quantity", keyboard: .numberPad)
    let kind = UISegmentedControl(items: ["Photos", "Videos", "Files"])
    let clientButton = SlateStyle.button("Select a client", symbol: "person", primary: false) {}
    var clients: [Client] = []; var selected: Client?
    var addedDeliverables: [DeliverableDraft] = []
    let deliverableSummary = SlateStyle.label("", style: .footnote, color: .secondaryLabel)
    init(dependencies: DependencyContainer, onSaved: (() -> Void)? = nil) { self.dependencies = dependencies; self.onSaved = onSaved; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad(); title = "New project"; closeButton(); heading("Start with a brief.", subtitle: "Define the work. You can add your invoice and media next.")
        section("Project"); content.addArrangedSubview(titleField); content.addArrangedSubview(descriptionField)
        section("Client"); content.addArrangedSubview(clientButton); clientButton.addAction(UIAction { [weak self] _ in self?.selectClient() }, for: .touchUpInside)
        content.addArrangedSubview(SlateStyle.button("Add a client", symbol: "person.badge.plus", primary: false) { [weak self] in self?.newClient() })
        section("Expected deliverables"); content.addArrangedSubview(output); kind.selectedSegmentIndex = 0; content.addArrangedSubview(kind); quantity.text = "1"; content.addArrangedSubview(quantity)
        content.addArrangedSubview(SlateStyle.button("Add another deliverable", symbol: "plus", primary: false) { [weak self] in self?.addDeliverable() })
        content.addArrangedSubview(deliverableSummary)
        content.addArrangedSubview(SlateStyle.label("Final delivery requires this quantity of verified files. Offline projects are saved as local drafts with the selected client.", style: .footnote, color: .secondaryLabel))
        content.addArrangedSubview(SlateStyle.button("Create project", symbol: "arrow.right") { [weak self] in self?.save() }); content.arrangedSubviews.last?.accessibilityIdentifier = "project.save"
        content.addArrangedSubview(message)
        perform { [self] in clients = try await dependencies.repository.clients(); if let client = clients.first { selected = client; clientButton.configuration?.title = client.name } }
    }
    func selectClient() {
        let alert = UIAlertController(title: "Choose client", message: clients.isEmpty ? "Add a client while connected to the server." : nil, preferredStyle: .actionSheet)
        for client in clients { alert.addAction(UIAlertAction(title: client.name, style: .default) { [weak self] _ in self?.selected = client; self?.clientButton.configuration?.title = client.name }) }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel)); alert.popoverPresentationController?.sourceView = clientButton; present(alert, animated: true)
    }
    func newClient() {
        let alert = UIAlertController(title: "New client", message: "Client records require a server connection.", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Client name" }; alert.addTextField { $0.placeholder = "Email"; $0.keyboardType = .emailAddress; $0.autocapitalizationType = .none }
        alert.addAction(UIAlertAction(title: "Create", style: .default) { [weak self] _ in
            guard let self else { return }; let name = alert.textFields?[0].text ?? ""; let email = alert.textFields?[1].text ?? ""
            self.perform { let client = try await self.dependencies.repository.createClient(name: name, email: email); self.clients.append(client); self.selected = client; self.clientButton.configuration?.title = client.name }
        }); alert.addAction(UIAlertAction(title: "Cancel", style: .cancel)); present(alert, animated: true)
    }
    func save() {
        let title = titleField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var deliverables = addedDeliverables
        if let current = currentDeliverable() { deliverables.append(current) }
        guard !title.isEmpty, let selected, !deliverables.isEmpty, deliverables.count <= 50 else { message.text = "Add a title, client, and deliverable with a quantity from 1 to 10,000."; return }
        if !(output.text ?? "").isEmpty && currentDeliverable() == nil { message.text = "Enter a valid quantity for the current deliverable."; return }
        let draft = ProjectDraft(title: title, description: descriptionField.text ?? "", clientId: selected.id, deliverables: deliverables)
        perform { [self] in
            let result = try await dependencies.repository.createProject(draft: draft)
            if result == nil {
                let alert = UIAlertController(title: "Draft saved on this device", message: "Slate will submit it with the same request key when you reconnect. Invoice issuance and delivery require server confirmation.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Done", style: .default) { [weak self] _ in self?.dismiss(animated: true, completion: self?.onSaved) }); present(alert, animated: true)
            } else { dismiss(animated: true, completion: onSaved) }
        }
    }
    func currentDeliverable() -> DeliverableDraft? {
        guard let text = output.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty, let q = Int(quantity.text ?? ""), (1...10000).contains(q) else { return nil }
        return .init(title: text, type: ["PHOTO", "VIDEO", "FILE"][kind.selectedSegmentIndex], expectedQuantity: q)
    }
    func addDeliverable() {
        guard let item = currentDeliverable(), addedDeliverables.count < 49 else { message.text = "Enter a deliverable and valid quantity first."; return }
        addedDeliverables.append(item); output.text = ""; quantity.text = "1"
        deliverableSummary.text = addedDeliverables.map { "\($0.expectedQuantity) × \($0.title)" }.joined(separator: "\n")
    }
}
