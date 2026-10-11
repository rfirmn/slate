import UIKit

final class MediaGalleryController: UICollectionViewController {
    let assets: [MediaAsset]
    init(assets: [MediaAsset]) {
        self.assets = assets
        var config = UICollectionLayoutListConfiguration(appearance: .insetGrouped); config.backgroundColor = SlateStyle.background
        super.init(collectionViewLayout: UICollectionViewCompositionalLayout.list(using: config))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad(); title = "Media gallery"; collectionView.register(GalleryCell.self, forCellWithReuseIdentifier: "media")
    }
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { assets.count }
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "media", for: indexPath) as! GalleryCell
        cell.configure(assets[indexPath.item]); return cell
    }
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true); let asset = assets[indexPath.item]
        let preview = SlateScreen(); preview.loadViewIfNeeded(); preview.title = "Media details"; preview.heading(asset.filename, subtitle: "\(SlateStyle.bytes(asset.sizeBytes)) · \(asset.mimeType)")
        preview.content.addArrangedSubview(MediaRow(asset: asset))
        preview.content.addArrangedSubview(InfoRow(title: SlateStyle.status(asset.status), detail: asset.verifiedAt.map { "Verified \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "Final delivery requires server verification.", symbol: "checkmark.shield"))
        preview.content.addArrangedSubview(SlateStyle.label("SHA-256\n\(asset.contentHash)", style: .caption1, color: .secondaryLabel))
        navigationController?.pushViewController(preview, animated: true)
    }
}

final class GalleryCell: UICollectionViewListCell {
    private var task: Task<Void, Never>?
    override func prepareForReuse() { super.prepareForReuse(); task?.cancel(); task = nil; contentConfiguration = nil }
    func configure(_ asset: MediaAsset) {
        task?.cancel()
        var config = defaultContentConfiguration(); config.text = asset.filename
        config.secondaryText = "\(SlateStyle.bytes(asset.sizeBytes)) · \(SlateStyle.status(asset.status))"
        config.image = UIImage(systemName: asset.mimeType.hasPrefix("video/") ? "film" : "photo")
        config.imageProperties.tintColor = SlateStyle.accent; config.imageProperties.maximumSize = CGSize(width: 72, height: 72)
        config.imageProperties.cornerRadius = 8; contentConfiguration = config; accessories = [.disclosureIndicator()]
        guard let url = asset.previewURL else { return }
        task = Task { @MainActor [weak self] in
            guard let (data, response) = try? await URLSession.shared.data(from: url), (response as? HTTPURLResponse)?.statusCode == 200, data.count < 5 * 1024 * 1024, !Task.isCancelled, let self else { return }
            config.image = UIImage(data: data); self.contentConfiguration = config
        }
    }
}
