import UIKit
import PhotosUI
import UniformTypeIdentifiers

final class ProjectDetailController: SlateScreen, PHPickerViewControllerDelegate, UIDocumentPickerDelegate {
    let dependencies: DependencyContainer
    var project: Project
    var cached = false
    init(dependencies: DependencyContainer, project: Project) { self.dependencies = dependencies; self.project = project; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad(); navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .refresh, primaryAction: UIAction { [weak self] _ in self?.refresh() }); render()
    }
    override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); refresh() }
    func refresh() { perform { [self] in project = try await dependencies.repository.project(id: project.id); cached = await dependencies.repository.servingCachedData; render() } }
    func render() {
        clear(); title = project.title
        heading(project.title, subtitle: "\(project.client.name) · \(SlateStyle.status(project.status.rawValue))")
        if cached { content.addArrangedSubview(InfoRow(title: "Offline · saved project", detail: "This is the last server snapshot. Payment and delivery changes require reconnection.", symbol: "icloud.slash")) }
        if !project.description.isEmpty { content.addArrangedSubview(SlateStyle.label(project.description, color: .secondaryLabel)) }
        section("Client"); content.addArrangedSubview(InfoRow(title: project.client.name, detail: project.client.email, symbol: "person.crop.circle"))
        section("Deliverables")
        for item in project.deliverables { content.addArrangedSubview(InfoRow(title: item.title, detail: "\(item.expectedQuantity) \(SlateStyle.status(item.type)) files expected", symbol: item.type == "VIDEO" ? "film" : "photo.on.rectangle")) }
        if project.status == .draft { content.addArrangedSubview(SlateStyle.button("Confirm project", primary: false) { [weak self] in self?.transition(.confirmed) }) }
        if project.status == .confirmed { content.addArrangedSubview(SlateStyle.button("Begin work", primary: false) { [weak self] in self?.transition(.inProgress) }) }
        if project.status == .delivered { content.addArrangedSubview(SlateStyle.button("Complete project", symbol: "checkmark", primary: false) { [weak self] in self?.transition(.completed) }) }
        section("Invoice")
        if let invoice = project.invoice {
            content.addArrangedSubview(InfoRow(title: SlateStyle.money(invoice.totalMinor), detail: "\(invoice.invoiceNumber) · \(SlateStyle.status(invoice.status.rawValue))", symbol: "doc.text"))
            content.addArrangedSubview(SlateStyle.button("View invoice", symbol: "arrow.up.right", primary: false) { [weak self] in
                guard let self else { return }; self.navigationController?.pushViewController(InvoiceController(dependencies: self.dependencies, invoice: invoice), animated: true)
            })
        } else { content.addArrangedSubview(SlateStyle.button("Create invoice", symbol: "doc.badge.plus", primary: false) { [weak self] in self?.createInvoice() }) }
        section("Media · \(project.media.count) files")
        content.addArrangedSubview(SlateStyle.button("Import media", symbol: "plus") { [weak self] in self?.chooseImport() }); content.arrangedSubviews.last?.accessibilityIdentifier = "project.import"
        if project.media.isEmpty { content.addArrangedSubview(SlateStyle.label("Bring in photos, videos, or PDFs. Slate keeps a durable copy and verifies each upload before delivery.", style: .footnote, color: .secondaryLabel)) }
        for asset in project.media.prefix(3) { content.addArrangedSubview(MediaRow(asset: asset)) }
        if !project.media.isEmpty {
            content.addArrangedSubview(SlateStyle.button("View media gallery", symbol: "square.grid.2x2", primary: false) { [weak self] in
                guard let self else { return }; self.navigationController?.pushViewController(MediaGalleryController(assets: self.project.media), animated: true)
            })
        }
        content.addArrangedSubview(SlateStyle.button("Open transfer manager", symbol: "arrow.up.circle", primary: false) { [weak self] in
            guard let self else { return }; self.navigationController?.pushViewController(TransfersController(dependencies: self.dependencies), animated: true)
        })
        section("Delivery")
        content.addArrangedSubview(InfoRow(title: SlateStyle.status(project.deliveryStatus), detail: deliveryExplanation, symbol: "lock.shield"))
        content.addArrangedSubview(SlateStyle.button("Share client portal", symbol: "square.and.arrow.up", primary: false) { [weak self] in self?.share() })
        if project.deliveryStatus == "RELEASED" {
            content.addArrangedSubview(SlateStyle.button("Revoke access", symbol: "lock", primary: false) { [weak self] in self?.delivery(release: false) })
        } else {
            let release = SlateStyle.button("Release final delivery", symbol: "checkmark.shield") { [weak self] in self?.delivery(release: true) }
            release.isEnabled = project.deliveryStatus == "ELIGIBLE"; content.addArrangedSubview(release)
        }
        section("Activity")
        if project.activity.isEmpty { content.addArrangedSubview(SlateStyle.label("Project activity will appear here.", style: .footnote, color: .secondaryLabel)) }
        for event in project.activity.prefix(12) { content.addArrangedSubview(InfoRow(title: SlateStyle.status(event.action), detail: event.createdAt.formatted(date: .abbreviated, time: .shortened), symbol: "clock")) }
    }
    var deliveryExplanation: String {
        switch project.deliveryStatus {
        case "RELEASED": return "Final files are available through the secure client portal. Download links expire shortly after issue."
        case "ELIGIBLE": return "Payment and required media are verified. You can release the final files."
        case "REVOKED": return "Access has been revoked. Existing short-lived links may remain valid until they expire."
        default: return "Final files remain private. An issued invoice must be paid, all required media verified, and the project confirmed before release."
        }
    }
    func transition(_ status: ProjectStatus) { perform { [self] in project = try await dependencies.repository.updateProject(id: project.id, status: status, version: project.version); render() } }
    func delivery(release: Bool) {
        perform { [self] in _ = try await dependencies.repository.delivery(projectID: project.id, release: release); project = try await dependencies.repository.project(id: project.id); render() }
    }
    func share() {
        perform { [self] in
            let link = try await dependencies.repository.share(projectID: project.id)
            let sheet = UIActivityViewController(activityItems: [link.url], applicationActivities: nil); sheet.popoverPresentationController?.sourceView = view
            present(sheet, animated: true)
        }
    }
    func createInvoice() {
        let screen = CreateInvoiceController(dependencies: dependencies, project: project, onSaved: { [weak self] in self?.refresh() })
        present(UINavigationController(rootViewController: screen), animated: true)
    }
    func chooseImport() {
        let alert = UIAlertController(title: "Import media", message: "Selected files are copied into Slate before uploading.", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Photo library", style: .default) { [weak self] _ in
            guard let self else { return }; var config = PHPickerConfiguration(); config.selectionLimit = 20; config.filter = .any(of: [.images, .videos]); config.preferredAssetRepresentationMode = .current
            let picker = PHPickerViewController(configuration: config); picker.delegate = self; self.present(picker, animated: true)
        })
        alert.addAction(UIAlertAction(title: "Files", style: .default) { [weak self] _ in
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.image, .movie, .pdf], asCopy: true); picker.allowsMultipleSelection = true; picker.delegate = self; self?.present(picker, animated: true)
        }); alert.addAction(UIAlertAction(title: "Cancel", style: .cancel)); alert.popoverPresentationController?.sourceView = view; present(alert, animated: true)
    }
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        dismiss(animated: true)
        let importer = dependencies.media
        for result in results {
            let provider = result.itemProvider
            guard let identifier = provider.registeredTypeIdentifiers.first(where: { UTType($0)?.conforms(to: .image) == true || UTType($0)?.conforms(to: .movie) == true }), let type = UTType(identifier) else { continue }
            let mime = type.preferredMIMEType ?? "application/octet-stream"
            let filename = (provider.suggestedName ?? "Media") + "." + (type.preferredFilenameExtension ?? "bin")
            provider.loadFileRepresentation(forTypeIdentifier: identifier) { [weak self] url, error in
                // Picker URLs cease to exist when this callback returns.
                do {
                    guard let url else { throw error ?? MediaImportError(message: "The selected file is unavailable.") }
                    let staged = try importer.copyTemporaryFile(url, filename: filename, mimeType: mime)
                    Task { @MainActor [weak self] in await self?.enqueue(staged, filename: filename, mime: mime) }
                } catch { Task { @MainActor [weak self] in self?.showError(error) } }
            }
        }
    }
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        let importer = dependencies.media
        Task { [weak self] in
            for url in urls {
                let type = UTType(filenameExtension: url.pathExtension); let mime = type?.preferredMIMEType ?? "application/octet-stream"
                do {
                    let filename = url.lastPathComponent
                    let staged = try await Task.detached(priority: .utility) { try importer.copyTemporaryFile(url, filename: filename, mimeType: mime) }.value
                    await self?.enqueue(staged, filename: filename, mime: mime)
                } catch { self?.showError(error) }
            }
        }
    }
    func enqueue(_ staged: URL, filename: String, mime: String) async {
        do {
            let file = try await dependencies.media.inspect(staged, filename: filename, mimeType: mime)
            _ = try await dependencies.transfers.enqueue(projectID: project.id, file: file)
            title = "Media queued"
        } catch { showError(error) }
    }
}

final class MediaRow: UIView {
    private var task: Task<Void, Never>?
    init(asset: MediaAsset) {
        super.init(frame: .zero)
        let image = UIImageView(image: UIImage(systemName: asset.mimeType.hasPrefix("video/") ? "film" : "photo")); image.tintColor = SlateStyle.accent
        image.contentMode = .scaleAspectFill; image.clipsToBounds = true; image.layer.cornerRadius = 8
        image.widthAnchor.constraint(equalToConstant: 64).isActive = true; image.heightAnchor.constraint(equalToConstant: 64).isActive = true
        let labels = UIStackView(arrangedSubviews: [SlateStyle.label(asset.filename, style: .headline), SlateStyle.label("\(SlateStyle.bytes(asset.sizeBytes)) · \(SlateStyle.status(asset.status))", style: .caption1, color: .secondaryLabel)])
        labels.axis = .vertical; labels.spacing = 6
        let stack = UIStackView(arrangedSubviews: [image, labels]); stack.spacing = 14; stack.alignment = .center; stack.translatesAutoresizingMaskIntoConstraints = false; addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor), stack.topAnchor.constraint(equalTo: topAnchor, constant: 8), stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)])
        if let url = asset.previewURL {
            task = Task { @MainActor in
                guard let (data, response) = try? await URLSession.shared.data(from: url), (response as? HTTPURLResponse)?.statusCode == 200, data.count < 5 * 1024 * 1024, !Task.isCancelled else { return }
                image.image = UIImage(data: data)
            }
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { task?.cancel() }
}
