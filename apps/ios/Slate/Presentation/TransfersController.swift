import UIKit

final class TransfersController: UITableViewController {
    let dependencies: DependencyContainer
    var records: [TransferRecord] = []
    private var observation: Task<Void, Never>?
    init(dependencies: DependencyContainer) { self.dependencies = dependencies; super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad(); title = "Transfers"; tableView.backgroundColor = SlateStyle.background
        refreshControl = UIRefreshControl(); refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)
        let footer = SlateStyle.label("Upload progress is saved on this device. Completion requires server integrity verification. iOS schedules background work; reopen Slate after force quit to recover.", style: .footnote, color: .secondaryLabel)
        footer.frame = CGRect(x: 0, y: 0, width: 300, height: 100); footer.textAlignment = .center; tableView.tableFooterView = footer
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        observation = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }; self.records = await self.dependencies.transfers.transfers(); self.tableView.reloadData()
                self.tableView.backgroundView = self.records.isEmpty ? SlateStyle.label("No files in the queue.\nImport media from a project to begin.", color: .secondaryLabel) : nil
                (self.tableView.backgroundView as? UILabel)?.textAlignment = .center
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
    }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); observation?.cancel(); observation = nil }
    @objc func refresh() {
        Task { @MainActor in
            defer { refreshControl?.endRefreshing() }
            do { try await dependencies.transfers.restore(); records = await dependencies.transfers.transfers(); tableView.reloadData() } catch { showError(error) }
        }
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { records.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let record = records[indexPath.row]; let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        var config = cell.defaultContentConfiguration(); config.text = record.filename
        let state = record.state == .verifying ? "Upload complete · verifying file" : SlateStyle.status(record.state.rawValue)
        config.secondaryText = "\(state)\n\(SlateStyle.bytes(record.uploadedBytes)) of \(SlateStyle.bytes(record.totalBytes)) · \(Int(record.progress * 100))%" + (record.error.map { "\n\($0)" } ?? "")
        config.image = UIImage(systemName: record.state == .completed ? "checkmark.seal" : record.state == .failed ? "exclamationmark.circle" : "arrow.up.circle")
        config.imageProperties.tintColor = record.state == .failed ? .systemRed : SlateStyle.accent; config.secondaryTextProperties.numberOfLines = 0
        cell.contentConfiguration = config; cell.accessoryType = [.completed, .cancelled].contains(record.state) ? .none : .disclosureIndicator
        cell.accessibilityValue = "\(state), \(Int(record.progress * 100)) percent"; return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true); let record = records[indexPath.row]
        guard ![.completed, .cancelled].contains(record.state) else { return }
        let alert = UIAlertController(title: record.filename, message: record.error ?? "Completed parts remain committed when a transfer is paused.", preferredStyle: .actionSheet)
        if [.paused, .failed, .retryWaiting].contains(record.state) {
            alert.addAction(UIAlertAction(title: record.state == .paused ? "Resume" : "Retry", style: .default) { [weak self] _ in self?.operate(record, action: record.state == .paused ? "resume" : "retry") })
        } else if record.state != .verifying { alert.addAction(UIAlertAction(title: "Pause", style: .default) { [weak self] _ in self?.operate(record, action: "pause") }) }
        if record.state != .verifying { alert.addAction(UIAlertAction(title: "Cancel upload", style: .destructive) { [weak self] _ in self?.operate(record, action: "cancel") }) }
        alert.addAction(UIAlertAction(title: "Close", style: .cancel)); alert.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath); present(alert, animated: true)
    }
    func operate(_ record: TransferRecord, action: String) {
        Task { @MainActor in
            do {
                switch action {
                case "pause": try await dependencies.transfers.pause(id: record.id)
                case "resume": try await dependencies.transfers.resume(id: record.id)
                case "retry": try await dependencies.transfers.retry(id: record.id)
                default: try await dependencies.transfers.cancel(id: record.id)
                }
                records = await dependencies.transfers.transfers(); tableView.reloadData()
            } catch { showError(error) }
        }
    }
    func showError(_ error: Error) { let alert = UIAlertController(title: "Transfer needs attention", message: error.localizedDescription, preferredStyle: .alert); alert.addAction(UIAlertAction(title: "OK", style: .default)); present(alert, animated: true) }
}
