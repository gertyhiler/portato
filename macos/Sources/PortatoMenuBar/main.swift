import AppKit
import ServiceManagement
import PortatoCore

func shellQuote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }

func openTerminal(arguments: [String]) {
    let command = arguments.map(shellQuote).joined(separator: " ")
    let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    let script = NSAppleScript(source: "tell application \"Terminal\"\nactivate\ndo script \"\(escaped)\"\nend tell")
    var error: NSDictionary?
    _ = script?.executeAndReturnError(&error)
    if error != nil {
        let alert = NSAlert()
        alert.messageText = "Could not open Terminal"
        alert.informativeText = "Allow Portato to control Terminal in System Settings, or run portato attach in your terminal."
        alert.runModal()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var item: NSStatusItem!
    private var tunnels: [TunnelStatus] = []
    private var problem: String?
    private var busy = Set<String>()
    private var client: DaemonClient?
    private var hasSnapshot = false
    private var daemonInfo: DaemonInfo?
    private var configurations: [[String: Any]] = []
    private var editors: [TunnelEditor] = []
    private var daemonProcess: Process?
    private var attemptedStart = false
    private var starting = false
    private var allowsDaemonStart = false
    private var startupProblem: String?
    private let preferences = UserDefaults.standard
    private var diagnostic: Bool { CommandLine.arguments.contains("--menu-json") }

    private let requestQueue = DispatchQueue(label: "dev.portato.menubar.requests")
    private let streamQueue = DispatchQueue(label: "dev.portato.menubar.events")

    func applicationDidFinishLaunching(_ notification: Notification) {
        preferences.register(defaults: ["startDaemon": true])
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let logoURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/logo.svg")
        let logo = NSImage(contentsOf: logoURL) ?? NSImage(systemSymbolName: "network", accessibilityDescription: "Portato tunnels")
        logo?.size = NSSize(width: 20, height: 20)
        logo?.isTemplate = true
        logo?.accessibilityDescription = "Portato tunnels"
        item.button?.image = logo
        item.button?.toolTip = "Portato — connecting to daemon"
        rebuildMenu()
        observe()
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self, let client = self.client else { return }
            self.refresh(using: client)
        }
    }

    private func observe() {
        streamQueue.async { [weak self] in
            while self != nil {
                do {
                    let next = DaemonClient(location: try DaemonLocation.discover())
                    let info = try next.info()
                    let configs = try next.configuration()
                    let statuses = try next.list()
                    DispatchQueue.main.async { [weak self] in
                        self?.daemonInfo = info
                        self?.configurations = configs
                        self?.startupProblem = nil
                        self?.allowsDaemonStart = false
                        self?.client = next
                        self?.hasSnapshot = true
                        self?.tunnels = statuses
                        self?.problem = nil
                        self?.rebuildMenu()
                    }
                    try next.events { [weak self] in self?.refresh(using: next) }
                } catch {
                    DispatchQueue.main.async { [weak self] in
                        self?.client = nil
                        self?.hasSnapshot = true
                        self?.tunnels = []
                        self?.problem = error.localizedDescription
                        self?.allowsDaemonStart = (error as? IPCError)?.allowsDaemonStart == true
                        self?.rebuildMenu()
                        if let self, self.allowsDaemonStart, !self.attemptedStart, !self.diagnostic, self.preferences.bool(forKey: "startDaemon") {
                            self.startDaemon()
                        }
                    }
                    Thread.sleep(forTimeInterval: 2)
                }
            }
        }
    }

    private func refresh(using source: DaemonClient) {
        requestQueue.async { [weak self] in
            do {
                let statuses = try source.list()
                let configs = try source.configuration()
                DispatchQueue.main.async { [weak self] in
                    guard self?.client?.location.socket == source.location.socket else { return }
                    self?.tunnels = statuses
                    self?.configurations = configs
                    self?.problem = nil
                    self?.rebuildMenu()
                }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.problem = error.localizedDescription
                    self?.rebuildMenu()
                }
            }
        }
    }

    private func menuItem(_ title: String, action: Selector? = nil, object: Any? = nil) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
        entry.target = self
        entry.representedObject = object
        return entry
    }

    private func rebuildMenu() {
        let menu = NSMenu()
        let connected = tunnels.filter { $0.state == "connected" }.count
        let summary: String
        if client != nil { summary = "\(connected) of \(tunnels.count) tunnels connected" }
        else if starting { summary = "Starting Portato…" }
        else if hasSnapshot && !allowsDaemonStart { summary = "Daemon needs attention" }
        else { summary = "Portato is offline" }
        menu.addItem(menuItem(summary))
        item.button?.toolTip = "Portato — \(summary)"
        if let problem = startupProblem ?? problem {
            let error = menuItem(String(problem.prefix(140)))
            error.toolTip = problem
            menu.addItem(error)
        }
        menu.addItem(.separator())
        for tunnel in tunnels {
            let symbol = tunnel.state == "connected" ? "●" : tunnel.state == "off" ? "○" : "◌"
            let stateLabel = tunnel.authenticationHint == nil ? tunnel.state : "authentication required"
            let parent = menuItem("\(symbol)  \(tunnel.name) — \(stateLabel)")
            let submenu = NSMenu()
            submenu.autoenablesItems = false
            let ssh = configurations.first { $0["name"] as? String == tunnel.name }?["ssh"] as? String ?? "SSH server"
            let endpoint: String
            switch tunnel.type {
            case "remote": endpoint = "On \(ssh): \(tunnel.remote) → This Mac: \(tunnel.local)"
            case "dynamic": endpoint = "SOCKS5 on this Mac: \(tunnel.local) via \(ssh)"
            default: endpoint = "This Mac: \(tunnel.local) → \(ssh): \(tunnel.remote)"
            }
            let detail = menuItem(endpoint)
            detail.isEnabled = false
            submenu.addItem(detail)
            if let error = tunnel.error, !error.isEmpty {
                let detail = menuItem(String(error.prefix(120)))
                detail.toolTip = error
                detail.isEnabled = false
                submenu.addItem(detail)
            }
            if let hint = tunnel.authenticationHint {
                submenu.addItem(menuItem(hint, action: #selector(openTUI)))
            }
            submenu.addItem(.separator())
            for action in [TunnelAction.enable, .disable, .restart] {
                let title = action == .enable ? "Connect" : action == .disable ? "Disconnect" : "Restart"
                let entry = menuItem(title, action: #selector(changeTunnel(_:)), object: [tunnel.name, action.rawValue])
                entry.isEnabled = !busy.contains(tunnel.name) && client != nil
                if action == .enable && tunnel.isActive { entry.isEnabled = false }
                if action != .enable && tunnel.state == "off" { entry.isEnabled = false }
                submenu.addItem(entry)
            }
            if let url = tunnel.browserURL {
                submenu.addItem(.separator())
                submenu.addItem(menuItem("Open in Browser (HTTP)", action: #selector(openBrowser(_:)), object: url))
            }
            submenu.addItem(.separator())
            submenu.addItem(menuItem("Edit Tunnel…", action: #selector(editTunnel(_:)), object: tunnel.name))
            submenu.addItem(menuItem("Delete Tunnel…", action: #selector(deleteTunnel(_:)), object: tunnel.name))
            parent.submenu = submenu
            menu.addItem(parent)
        }
        if client != nil && tunnels.isEmpty { menu.addItem(menuItem("Add your first tunnel to get started")) }
        menu.addItem(.separator())
        menu.addItem(menuItem("Open TUI…", action: #selector(openTUI)))
        menu.addItem(menuItem("Add Tunnel…", action: client == nil ? nil : #selector(addTunnel)))
        menu.addItem(menuItem("Open Configuration…", action: daemonInfo == nil || client == nil ? nil : #selector(openConfiguration)))
        menu.addItem(menuItem("Reload Configuration", action: client == nil ? nil : #selector(reloadConfiguration)))
        if client == nil {
            let start = menuItem(starting ? "Starting…" : "Start Daemon", action: starting || !allowsDaemonStart ? nil : #selector(startDaemon))
            start.isEnabled = !starting && allowsDaemonStart
            menu.addItem(start)
        }
        let settings = menuItem("Settings")
        let settingsMenu = NSMenu()
        let autoStart = menuItem("Start daemon when Portato opens", action: #selector(toggleDaemonStartup))
        autoStart.state = preferences.bool(forKey: "startDaemon") ? .on : .off
        settingsMenu.addItem(autoStart)
        let login = menuItem("Open Portato at Login", action: #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        settingsMenu.addItem(login)
        if SMAppService.mainApp.status == .requiresApproval {
            settingsMenu.addItem(menuItem("Allow in Login Items…", action: #selector(loginSettings)))
        }
        settingsMenu.addItem(menuItem("Daemon Login Service…", action: #selector(setup)))
        settings.submenu = settingsMenu
        menu.addItem(settings)
        menu.addItem(menuItem("Refresh", action: #selector(manualRefresh)))
        menu.addItem(.separator())
        let quit = menuItem("Quit Portato Menu Bar", action: #selector(quit))
        quit.keyEquivalent = "q"
        menu.addItem(quit)
        item.menu = menu
        if CommandLine.arguments.contains("--menu-json"), hasSnapshot {
            func describe(_ entry: NSMenuItem) -> [String: Any] {
                var result: [String: Any] = ["title": entry.title, "enabled": entry.isEnabled]
                if let action = entry.action { result["action"] = NSStringFromSelector(action) }
                if let children = entry.submenu { result["children"] = children.items.map(describe) }
                return result
            }
            if let data = try? JSONSerialization.data(withJSONObject: menu.items.map(describe), options: [.sortedKeys]) {
                print(String(decoding: data, as: UTF8.self))
            }
            exit(client == nil ? 1 : 0)
        }
    }

    @objc private func changeTunnel(_ sender: NSMenuItem) {
        guard let pair = sender.representedObject as? [String], pair.count == 2,
              let action = TunnelAction(rawValue: pair[1]), let client else { return }
        let name = pair[0]
        busy.insert(name)
        rebuildMenu()
        requestQueue.async { [weak self] in
            var failure: String?
            do { try client.perform(action, name: name) } catch { failure = error.localizedDescription }
            DispatchQueue.main.async { [weak self] in
                self?.busy.remove(name)
                if let failure { self?.problem = failure }
                self?.rebuildMenu()
            }
            if failure == nil { self?.refresh(using: client) }
        }
    }

    @objc private func openBrowser(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL { NSWorkspace.shared.open(url) }
    }

    private var executable: String {
        let bundled = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/portato").path
        return FileManager.default.isExecutableFile(atPath: bundled) ? bundled : "portato"
    }

    @objc private func openTUI() {
        var arguments = [executable]
        if let client { arguments += ["--socket", client.location.socket, "attach"] }
        openTerminal(arguments: arguments)
    }

    @objc private func startDaemon() {
        guard !starting, client == nil, allowsDaemonStart else { return }
        attemptedStart = true
        starting = true
        startupProblem = nil
        rebuildMenu()
        let binary = executable
        requestQueue.async { [weak self] in
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: binary)
                process.arguments = ["daemon"]
                process.standardInput = FileHandle.nullDevice
                process.standardOutput = FileHandle.nullDevice
                process.standardError = FileHandle.nullDevice
                process.terminationHandler = { process in
                    DispatchQueue.main.async { [weak self] in
                        if process.terminationStatus != 0 {
                            self?.startupProblem = "Daemon could not start. Check the configuration or open the TUI for details."
                        }
                        self?.starting = false
                        self?.rebuildMenu()
                    }
                }
                try process.run()
                DispatchQueue.main.async { [weak self] in self?.daemonProcess = process; self?.starting = false; self?.rebuildMenu() }
            } catch {
                DispatchQueue.main.async { [weak self] in
                    self?.starting = false
                    self?.startupProblem = error.localizedDescription
                    self?.rebuildMenu()
                }
            }
        }
    }

    @objc private func toggleDaemonStartup() {
        preferences.set(!preferences.bool(forKey: "startDaemon"), forKey: "startDaemon")
        if preferences.bool(forKey: "startDaemon"), client == nil { startDaemon() }
        rebuildMenu()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval {
                try SMAppService.mainApp.unregister()
            } else { try SMAppService.mainApp.register() }
        } catch { showError(error.localizedDescription) }
        rebuildMenu()
    }

    @objc private func loginSettings() { SMAppService.openSystemSettingsLoginItems() }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Portato"
        alert.informativeText = message
        alert.runModal()
    }

    @objc private func addTunnel() { showEditor(value: nil) }

    @objc private func editTunnel(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String,
              let value = configurations.first(where: { $0["name"] as? String == name }) else { return }
        showEditor(value: value)
    }

    private func showEditor(value: [String: Any]?) {
        guard let client else { return }
        editors.removeAll { $0.window?.isVisible != true }
        let editor = TunnelEditor(client: client, value: value) { [weak self] in self?.refresh(using: client) }
        editors.append(editor)
        editor.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func deleteTunnel(_ sender: NSMenuItem) {
        guard let client, let name = sender.representedObject as? String else { return }
        let alert = NSAlert()
        alert.messageText = "Delete \(name)?"
        alert.informativeText = "The tunnel will disconnect and be removed from the shared configuration."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Delete Tunnel")
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        requestQueue.async { [weak self] in
            do { try client.deleteTunnel(name: name); self?.refresh(using: client) }
            catch { DispatchQueue.main.async { self?.showError(error.localizedDescription) } }
        }
    }

    @objc private func openConfiguration() {
        guard let daemonInfo else { return }
        let url = URL(fileURLWithPath: daemonInfo.configPath)
        NSWorkspace.shared.open([url], withApplicationAt: URL(fileURLWithPath: "/System/Applications/TextEdit.app"), configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
    }

    @objc private func reloadConfiguration() {
        guard let client else { return }
        requestQueue.async { [weak self] in
            do { try client.reload(); self?.refresh(using: client) }
            catch { DispatchQueue.main.async { self?.showError(error.localizedDescription) } }
        }
    }

    @objc private func setup() {
        let alert = NSAlert()
        alert.messageText = "Daemon at login"
        alert.informativeText = "The daemon keeps tunnels running when this menu closes. Install its login service to run independently of the app. Removing the service stops its daemon."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Install Service…")
        alert.addButton(withTitle: "Remove Service…")
        let response = alert.runModal()
        if response == .alertSecondButtonReturn { openTerminal(arguments: [executable, "install"]) }
        if response == .alertThirdButtonReturn { openTerminal(arguments: [executable, "uninstall"]) }
    }

    @objc private func manualRefresh() { if let client { refresh(using: client) } }
    @objc private func quit() { NSApplication.shared.terminate(nil) }
}

if CommandLine.arguments.contains("--list-json") {
    do {
        let client = DaemonClient(location: try DaemonLocation.discover())
        let statuses = try client.list()
        let output = statuses.map { ["name": $0.name, "state": $0.state, "local": $0.local] }
        let data = try JSONSerialization.data(withJSONObject: output, options: [.sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    } catch {
        fputs("\(error.localizedDescription)\n", stderr)
        exit(1)
    }
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { app.run() }
}
