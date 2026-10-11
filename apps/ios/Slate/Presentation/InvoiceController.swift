import UIKit

final class InvoiceController: SlateScreen {
    let dependencies: DependencyContainer
    var invoice: Invoice
    init(dependencies: DependencyContainer, invoice: Invoice) { self.dependencies = dependencies; self.invoice = invoice; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() { super.viewDidLoad(); title = "Invoice"; navigationItem.largeTitleDisplayMode = .never; render() }
    func render() {
        clear(); heading(SlateStyle.money(invoice.totalMinor), subtitle: "\(invoice.invoiceNumber) · \(SlateStyle.status(invoice.status.rawValue))")
        if let due = invoice.dueAt { content.addArrangedSubview(InfoRow(title: "Due \(due.formatted(date: .abbreviated, time: .omitted))", detail: invoice.status == .issued && due < Date() ? "Overdue · awaiting payment confirmation" : "Server-issued invoice", symbol: "calendar")) }
        if let paid = invoice.paidAt { content.addArrangedSubview(InfoRow(title: "Payment verified", detail: paid.formatted(date: .abbreviated, time: .shortened), symbol: "checkmark.seal")) }
        section("Line items")
        for item in invoice.items { content.addArrangedSubview(InfoRow(title: item.description, detail: "\(item.quantity) × \(SlateStyle.money(item.unitPriceMinor)) = \(SlateStyle.money(item.lineTotalMinor))")) }
        if invoice.status == .draft { content.addArrangedSubview(SlateStyle.button("Issue invoice", symbol: "paperplane") { [weak self] in self?.action("issue") }) }
        if invoice.status == .draft || invoice.status == .issued { content.addArrangedSubview(SlateStyle.button("Void invoice", primary: false) { [weak self] in self?.confirmVoid() }) }
        if invoice.status == .issued { content.addArrangedSubview(SlateStyle.button("Verify payment status", symbol: "arrow.triangle.2.circlepath", primary: false) { [weak self] in self?.action("reconcile") }) }
        content.addArrangedSubview(SlateStyle.label("This invoice is a server snapshot. Clients pay through the secure portal. Refresh the project or verify payment status while connected to get the current result.", style: .footnote, color: .secondaryLabel))
        section("Payment history")
        if invoice.payments.isEmpty { content.addArrangedSubview(SlateStyle.label("No payment attempts yet.", style: .footnote, color: .secondaryLabel)) }
        for payment in invoice.payments { content.addArrangedSubview(InfoRow(title: "\(SlateStyle.status(payment.status)) · \(SlateStyle.money(payment.amountMinor))", detail: "\(payment.provider == "development" ? "LOCAL SIMULATOR" : payment.provider) · \(payment.createdAt.formatted(date: .abbreviated, time: .shortened))", symbol: "creditcard")) }
    }
    func action(_ action: String) { perform { [self] in invoice = try await dependencies.repository.invoiceAction(id: invoice.id, action: action); render() } }
    func confirmVoid() {
        let alert = UIAlertController(title: "Void this invoice?", message: "A paid invoice cannot be voided. This change is recorded in project history.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Void", style: .destructive) { [weak self] _ in self?.action("void") }); alert.addAction(UIAlertAction(title: "Cancel", style: .cancel)); present(alert, animated: true)
    }
}

final class CreateInvoiceController: SlateScreen {
    let dependencies: DependencyContainer
    let project: Project
    let onSaved: (() -> Void)?
    let descriptionField = SlateStyle.field("Description", id: "invoice.description")
    let amount = SlateStyle.field("Unit price in rupiah (e.g. 5000000)", id: "invoice.amount", keyboard: .numberPad)
    let quantity = SlateStyle.field("Quantity", id: "invoice.quantity", keyboard: .numberPad)
    let due = UIDatePicker()
    var addedItems: [InvoiceItemDraft] = []
    let itemSummary = SlateStyle.label("", style: .footnote, color: .secondaryLabel)
    init(dependencies: DependencyContainer, project: Project, onSaved: (() -> Void)? = nil) { self.dependencies = dependencies; self.project = project; self.onSaved = onSaved; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidLoad() {
        super.viewDidLoad(); title = "Create invoice"; closeButton(); heading("Put the work\nin writing.", subtitle: project.client.name)
        descriptionField.text = project.title; quantity.text = "1"
        content.addArrangedSubview(descriptionField); content.addArrangedSubview(quantity); content.addArrangedSubview(amount)
        content.addArrangedSubview(SlateStyle.button("Add another line item", symbol: "plus", primary: false) { [weak self] in self?.addItem() }); content.addArrangedSubview(itemSummary)
        section("Due date"); due.datePickerMode = .date; due.date = Date().addingTimeInterval(14 * 86400); content.addArrangedSubview(due)
        content.addArrangedSubview(SlateStyle.label("IDR amounts use whole rupiah. The server calculates the total. Issue the draft when you are ready; issued amounts are immutable.", style: .footnote, color: .secondaryLabel))
        content.addArrangedSubview(SlateStyle.button("Create invoice draft", symbol: "doc.text") { [weak self] in self?.save() }); content.addArrangedSubview(message)
    }
    func save() {
        var items = addedItems
        if let item = currentItem() { items.append(item) }
        guard !items.isEmpty, items.count <= 100, ((descriptionField.text ?? "").isEmpty || currentItem() != nil), items.reduce(Int64(0), { $0 + Int64($1.quantity) * $1.unitPriceMinor }) <= 2_147_483_647 else { message.text = "Enter valid line items. The invoice total must not exceed Rp 2,147,483,647."; return }
        perform { [self] in _ = try await dependencies.repository.createInvoice(projectID: project.id, items: items, dueAt: due.date); dismiss(animated: true, completion: onSaved) }
    }
    func currentItem() -> InvoiceItemDraft? {
        guard let unit = Int64(amount.text ?? ""), unit > 0, unit <= 2_147_483_647, let q = Int(quantity.text ?? ""), (1...10000).contains(q), unit * Int64(q) <= 2_147_483_647, let text = descriptionField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return .init(description: text, quantity: q, unitPriceMinor: unit)
    }
    func addItem() {
        guard let item = currentItem(), addedItems.count < 99 else { message.text = "Enter a description, quantity, and positive whole-rupiah price first."; return }
        addedItems.append(item); descriptionField.text = ""; amount.text = ""; quantity.text = "1"
        itemSummary.text = addedItems.map { "\($0.description) · \(SlateStyle.money(Int64($0.quantity) * $0.unitPriceMinor))" }.joined(separator: "\n")
    }
}
