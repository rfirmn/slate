import UIKit

enum SlateStyle {
    static let background = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.09, alpha: 1) : UIColor(red: 0.973, green: 0.973, blue: 0.965, alpha: 1) }
    static let accent = UIColor(red: 0.333, green: 0.420, blue: 0.384, alpha: 1)
    static let border = UIColor.separator
    static func label(_ text: String, style: UIFont.TextStyle = .body, color: UIColor = .label) -> UILabel {
        let label = UILabel(); label.text = text; label.font = .preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true; label.textColor = color; label.numberOfLines = 0
        return label
    }
    static func button(_ title: String, symbol: String? = nil, primary: Bool = true, action: @escaping () -> Void) -> UIButton {
        var config = primary ? UIButton.Configuration.filled() : UIButton.Configuration.tinted()
        config.title = title; config.baseBackgroundColor = accent; config.baseForegroundColor = primary ? .white : accent
        config.cornerStyle = .medium; config.contentInsets = .init(top: 14, leading: 18, bottom: 14, trailing: 18)
        if let symbol { config.image = UIImage(systemName: symbol); config.imagePadding = 8 }
        return UIButton(configuration: config, primaryAction: UIAction { _ in action() })
    }
    static func field(_ placeholder: String, id: String? = nil, keyboard: UIKeyboardType = .default) -> UITextField {
        let field = UITextField(); field.placeholder = placeholder; field.borderStyle = .roundedRect
        field.font = .preferredFont(forTextStyle: .body); field.adjustsFontForContentSizeCategory = true
        field.keyboardType = keyboard; field.accessibilityIdentifier = id
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        return field
    }
    static func status(_ value: String) -> String { value.replacingOccurrences(of: "_", with: " ").lowercased().capitalized }
    static func money(_ amount: Int64) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "IDR"; f.locale = Locale(identifier: "id_ID"); f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: amount)) ?? "IDR \(amount)"
    }
    static func bytes(_ count: Int64) -> String { ByteCountFormatter.string(fromByteCount: count, countStyle: .file) }
}

class SlateScreen: UIViewController {
    let content = UIStackView()
    let scroll = UIScrollView()
    let message = SlateStyle.label("", style: .footnote, color: .secondaryLabel)
    var busy = false
    override func viewDidLoad() {
        super.viewDidLoad(); view.backgroundColor = SlateStyle.background
        scroll.keyboardDismissMode = .interactive; scroll.translatesAutoresizingMaskIntoConstraints = false
        content.axis = .vertical; content.spacing = 16; content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll); scroll.addSubview(content)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24), content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24), content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -32),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48)
        ])
    }
    func heading(_ title: String, subtitle: String? = nil) {
        content.addArrangedSubview(SlateStyle.label(title, style: .largeTitle))
        if let subtitle { content.addArrangedSubview(SlateStyle.label(subtitle, style: .body, color: .secondaryLabel)) }
    }
    func section(_ title: String) { content.addArrangedSubview(SlateStyle.label(title.uppercased(), style: .caption1, color: SlateStyle.accent)) }
    func clear() { content.arrangedSubviews.forEach { content.removeArrangedSubview($0); $0.removeFromSuperview() } }
    func showError(_ error: Error) {
        let alert = UIAlertController(title: "Unable to finish", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default)); present(alert, animated: true)
    }
    func perform(_ operation: @escaping () async throws -> Void) {
        guard !busy else { return }; busy = true
        Task { @MainActor in
            defer { self.busy = false }
            do { try await operation() } catch { self.showError(error) }
        }
    }
    func closeButton() { navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) }) }
}

final class InfoRow: UIView {
    init(title: String, detail: String, symbol: String? = nil) {
        super.init(frame: .zero)
        let stack = UIStackView(); stack.axis = .horizontal; stack.alignment = .center; stack.spacing = 14
        if let symbol {
            let image = UIImageView(image: UIImage(systemName: symbol)); image.tintColor = SlateStyle.accent
            image.widthAnchor.constraint(equalToConstant: 24).isActive = true; stack.addArrangedSubview(image)
        }
        let text = UIStackView(arrangedSubviews: [SlateStyle.label(title, style: .headline), SlateStyle.label(detail, style: .subheadline, color: .secondaryLabel)])
        text.axis = .vertical; text.spacing = 6; stack.addArrangedSubview(text)
        stack.translatesAutoresizingMaskIntoConstraints = false; addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor), stack.topAnchor.constraint(equalTo: topAnchor, constant: 12), stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
