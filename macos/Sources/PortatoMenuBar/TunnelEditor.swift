import AppKit
import PortatoCore

final class TunnelEditor: NSWindowController {
    private let original: [String: Any]
    private let originalName: String?
    private let client: DaemonClient
    private let onSaved: () -> Void
    private var fields: [String: NSTextField] = [:]
    private let type = NSPopUpButton()
    private let enabled = NSButton(checkboxWithTitle: "Connect automatically", target: nil, action: nil)
    private let status = NSTextField(wrappingLabelWithString: "Changes are saved to the daemon’s configuration and shared with the CLI and TUI.")
    private let save = NSButton(title: "Save Tunnel", target: nil, action: nil)

    init(client: DaemonClient, value: [String: Any]?, onSaved: @escaping () -> Void) {
        self.client = client
        original = value ?? [:]
        originalName = value?["name"] as? String
        self.onSaved = onSaved
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 450),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = value == nil ? "Add Tunnel" : "Edit Tunnel"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 24)
        ])
        for (key, title, placeholder) in [
            ("name", "Name", "work-web"), ("ssh", "SSH host / alias", "dev-server"),
            ("local", "Address on this Mac", "127.0.0.1:3200"),
            ("remote", "Address on SSH side", "127.0.0.1:3000"),
            ("identity", "Private key (optional)", "Use SSH configuration")
        ] {
            let label = NSTextField(labelWithString: title)
            label.widthAnchor.constraint(equalToConstant: 160).isActive = true
            let field = NSTextField(string: original[key] as? String ?? "")
            field.placeholderString = placeholder
            field.widthAnchor.constraint(equalToConstant: 290).isActive = true
            fields[key] = field
            stack.addArrangedSubview(NSStackView(views: [label, field]))
        }
        fields["name"]?.isEditable = originalName == nil
        type.addItems(withTitles: ["Local → SSH destination", "SSH listener → this Mac", "SOCKS5 proxy on this Mac"])
        type.selectItem(at: ["local", "remote", "dynamic"].firstIndex(of: original["type"] as? String ?? "local") ?? 0)
        stack.addArrangedSubview(type)
        enabled.state = original["enabled"] as? Bool == true ? .on : .off
        stack.addArrangedSubview(enabled)
        status.font = .systemFont(ofSize: 12)
        status.textColor = .secondaryLabelColor
        status.widthAnchor.constraint(equalToConstant: 460).isActive = true
        stack.addArrangedSubview(status)
        save.target = self
        save.action = #selector(submit)
        save.keyEquivalent = "\r"
        stack.addArrangedSubview(save)
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func submit() {
        var value = original
        for (key, field) in fields { value[key] = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) }
        value["type"] = ["local", "remote", "dynamic"][type.indexOfSelectedItem]
        if type.indexOfSelectedItem == 2 { value["remote"] = "" }
        value["enabled"] = enabled.state == .on
        save.isEnabled = false
        status.stringValue = "Saving…"
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            do {
                if let originalName {
                    let latest = try client.configuration().first { $0["name"] as? String == originalName }
                    guard let latest, NSDictionary(dictionary: latest).isEqual(to: original) else {
                        throw IPCError.message("This tunnel changed in another client. Close and reopen the editor before saving.")
                    }
                }
                try client.saveTunnel(value, originalName: originalName)
                DispatchQueue.main.async { [self] in onSaved(); close() }
            } catch {
                DispatchQueue.main.async { [self] in
                    status.stringValue = error.localizedDescription
                    status.textColor = .systemRed
                    save.isEnabled = true
                }
            }
        }
    }
}
