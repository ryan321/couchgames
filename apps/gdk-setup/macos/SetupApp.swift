import AppKit

final class SetupApp: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let preferences = UserDefaults(suiteName: "games.couch.gdk")!
    private var window: NSWindow!
    private let engineStatus = NSTextField(wrappingLabelWithString: "Checking this Mac…")
    private let engineDetail = NSTextField(wrappingLabelWithString: "")
    private let destinationLabel = NSTextField(wrappingLabelWithString: "")
    private let message = NSTextField(wrappingLabelWithString: "")
    private let progress = NSProgressIndicator()
    private var installButton: NSButton!
    private var launchButton: NSButton!
    private var controls: [NSButton] = []
    private var installed: URL?
    private var godot: String?
    private var selectedGodot: String?
    private var downloadURL: URL?
    private var kit: KitManifest!
    private var payload: URL!
    private var parent = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/CouchGames/GDK")
    private var busy = false
    private var isInstalledApp = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        isInstalledApp = Bundle.main.object(forInfoDictionaryKey: "CouchGDKInstalled") as? Bool == true
        payload = isInstalledApp ? Bundle.main.bundleURL.deletingLastPathComponent() : Bundle.main.resourceURL!.appendingPathComponent("payload")
        do { kit = try SetupCore.manifest(at: payload) }
        catch { showFatal(error.localizedDescription); return }
        if isInstalledApp { installed = payload; parent = payload.deletingLastPathComponent() }
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--godot"), i + 1 < args.count { selectedGodot = args[i + 1] }
        else { selectedGodot = preferences.string(forKey: "selectedGodot") }
        buildWindow()
        checkEngine(autoLaunch: isInstalledApp)
    }
    private func label(_ text: String, size: CGFloat = 14, weight: NSFont.Weight = .regular) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        return field
    }
    private func button(_ title: String, action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .rounded
        controls.append(b)
        return b
    }
    private func row(_ views: [NSView]) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.spacing = 10
        return stack
    }
    private func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 610), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = isInstalledApp ? "Couch Games Creator" : "Couch Games GDK Setup"
        window.delegate = self
        window.center()
        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 15
        root.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 34),
            root.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -34),
            root.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 30)
        ])
        let badge = label("COUCH GAMES  /  CREATOR PREVIEW", size: 11, weight: .semibold)
        badge.textColor = .secondaryLabelColor
        root.addArrangedSubview(badge)
        root.addArrangedSubview(label("Make something worth playing.", size: 29, weight: .bold))
        root.addArrangedSubview(label("Install the development kit, connect your editor, and start a game of your own."))
        let separator = NSBox(); separator.boxType = .separator
        root.addArrangedSubview(separator)
        separator.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        root.addArrangedSubview(label("01   Your Godot editor", size: 16, weight: .semibold))
        engineStatus.font = .systemFont(ofSize: 14, weight: .medium)
        engineDetail.font = .systemFont(ofSize: 12)
        engineDetail.textColor = .secondaryLabelColor
        engineDetail.maximumNumberOfLines = 4
        root.addArrangedSubview(engineStatus)
        root.addArrangedSubview(engineDetail)
        root.addArrangedSubview(row([
            button("Choose Godot…", action: #selector(chooseGodot)),
            button("Download Godot…", action: #selector(downloadGodot)),
            button("Detect automatically", action: #selector(autoDetect))
        ]))
        root.addArrangedSubview(label("02   Your development kit", size: 16, weight: .semibold))
        let amount = ByteCountFormatter.string(fromByteCount: Int64(kit.totalBytes), countStyle: .file)
        root.addArrangedSubview(label("Version \(kit.version) · \(amount) · SDK, 3D starter, Creator Hub, tools and guides", size: 13))
        destinationLabel.font = .systemFont(ofSize: 12)
        destinationLabel.textColor = .secondaryLabelColor
        destinationLabel.maximumNumberOfLines = 2
        destinationLabel.stringValue = parent.appendingPathComponent(kit.version).path
        root.addArrangedSubview(destinationLabel)
        root.addArrangedSubview(row([
            button("Choose install folder…", action: #selector(chooseDestination)),
            button("Show files", action: #selector(showFiles))
        ]))
        let note = label("Godot is separate. Download opens the official version page; extract the standard editor, then choose it here. Existing editor installations and projects are preserved.", size: 12)
        note.textColor = .secondaryLabelColor
        root.addArrangedSubview(note)
        message.font = .systemFont(ofSize: 13)
        message.maximumNumberOfLines = 3
        root.addArrangedSubview(message)
        progress.style = .spinning
        progress.controlSize = .small
        progress.isDisplayedWhenStopped = false
        installButton = button(isInstalledApp ? "Verify installation" : "Install GDK", action: #selector(installKit))
        launchButton = button("Open Creator Hub", action: #selector(openHub))
        launchButton.keyEquivalent = "\r"
        root.addArrangedSubview(row([installButton, launchButton, progress]))
        for view in [engineStatus, engineDetail, destinationLabel, message, note] {
            view.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        }
        let menu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let item = NSMenuItem(); item.submenu = appMenu; menu.addItem(item)
        NSApp.mainMenu = menu
        setBusy(false)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    private func setBusy(_ value: Bool) {
        busy = value
        controls.forEach { $0.isEnabled = !value }
        launchButton.isEnabled = !value && installed != nil && godot != nil
        if value { progress.startAnimation(nil) } else { progress.stopAnimation(nil) }
    }
    private func checkEngine(autoLaunch: Bool = false) {
        setBusy(true)
        godot = nil
        engineStatus.stringValue = "Checking your Godot installation…"
        let tool = payload.appendingPathComponent("bin/couch")
        let override = selectedGodot
        DispatchQueue.global().async {
            do {
                let report = try SetupCore.doctor(tool: tool, godot: override)
                DispatchQueue.main.async {
                    let policy = report["policy"] as? [String: Any] ?? [:]
                    let version = policy["godot_version"] as? String ?? "supported"
                    self.downloadURL = (policy["download_url"] as? String).flatMap(URL.init(string:))
                    if report["supported"] as? Bool == true, let exe = report["executable"] as? String {
                        self.godot = exe
                        self.engineStatus.stringValue = "Ready · Godot \(version) standard"
                        self.engineDetail.stringValue = exe
                        self.message.stringValue = self.installed == nil ? "Your editor is ready. Install the kit to get started." : "Your kit and editor are ready."
                    } else {
                        self.engineStatus.stringValue = "Godot \(version) standard is needed"
                        let status = report["status"] as? String ?? "missing"
                        let reasons = (report["attempts"] as? [[String: Any]] ?? []).compactMap { $0["reason"] as? String }
                        self.engineDetail.stringValue = status == "missing" ? "No supported editor found. Download Godot or choose an existing installation." : reasons.last ?? "Choose a supported editor or download the required version."
                        self.message.stringValue = "You can install the kit now and connect Godot afterward."
                    }
                    self.setBusy(false)
                    if autoLaunch && self.godot != nil { self.openHub() }
                }
            } catch { DispatchQueue.main.async { self.engineStatus.stringValue = "Setup check needs attention"; self.message.stringValue = error.localizedDescription; self.setBusy(false) } }
        }
    }
    @objc private func chooseGodot() {
        let panel = NSOpenPanel()
        panel.title = "Choose Godot.app or the Godot executable"
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { result in
            if result == .OK, let url = panel.url {
                self.selectedGodot = url.path
                self.preferences.set(url.path, forKey: "selectedGodot")
                self.checkEngine()
            }
        }
    }
    @objc private func autoDetect() {
        selectedGodot = nil
        preferences.removeObject(forKey: "selectedGodot")
        checkEngine()
    }
    @objc private func downloadGodot() {
        if let url = downloadURL { NSWorkspace.shared.open(url) }
    }
    @objc private func chooseDestination() {
        let panel = NSOpenPanel()
        panel.title = "Choose a parent folder for the versioned GDK"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.beginSheetModal(for: window) { result in
            if result == .OK, let url = panel.url {
                self.parent = url
                self.installed = nil
                self.destinationLabel.stringValue = url.appendingPathComponent(self.kit.version).path
                self.message.stringValue = "The kit will be installed in its own versioned folder."
                self.setBusy(false)
            }
        }
    }
    @objc private func showFiles() { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: (installed ?? parent).path) }
    @objc private func installKit() {
        setBusy(true)
        message.stringValue = "Verifying and installing the development kit…"
        let source = payload!, destination = parent
        DispatchQueue.global().async {
            do {
                let location = try SetupCore.install(payload: source, parent: destination)
                DispatchQueue.main.async {
                    self.installed = location
                    self.destinationLabel.stringValue = location.path
                    self.message.stringValue = "Installed. Open Creator Hub to create your first project."
                    self.installButton.title = "Verify installation"
                    self.setBusy(false)
                }
            } catch { DispatchQueue.main.async { self.message.stringValue = error.localizedDescription; self.setBusy(false) } }
        }
    }
    @objc private func openHub() {
        guard let installed, let godot else { return }
        setBusy(true)
        message.stringValue = "Preparing Creator Hub…"
        DispatchQueue.global().async {
            do {
                _ = try SetupCore.verify(installed)
                // Recheck at launch in case the selected executable was replaced since detection.
                let report = try SetupCore.doctor(tool: installed.appendingPathComponent("bin/couch"), godot: godot)
                guard report["supported"] as? Bool == true else { throw SetupFailure("Godot has changed. Check or choose your editor again.") }
                let hub = installed.appendingPathComponent("creator-hub")
                let imported = try SetupCore.run(URL(fileURLWithPath: godot), ["--headless", "--editor", "--path", hub.path, "--quit"])
                let output = String(data: imported.output, encoding: .utf8) ?? ""
                guard imported.status == 0, !output.contains("ERROR:") else { throw SetupFailure("Creator Hub could not load. \(output.suffix(1000))") }
                let child = Process()
                child.executableURL = URL(fileURLWithPath: godot)
                child.arguments = ["--path", hub.path]
                child.environment = SetupCore.environment()
                let logs = installed.appendingPathComponent("logs")
                try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
                let log = logs.appendingPathComponent("creator-hub.log")
                FileManager.default.createFile(atPath: log.path, contents: nil)
                let handle = try FileHandle(forWritingTo: log)
                child.standardOutput = handle
                child.standardError = handle
                try child.run()
                try? handle.close()
                DispatchQueue.main.async { self.setBusy(false); NSApp.terminate(nil) }
            } catch { DispatchQueue.main.async { self.message.stringValue = error.localizedDescription; self.setBusy(false) } }
        }
    }
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if busy { NSSound.beep(); return false }; return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { !busy }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if busy { NSSound.beep(); return .terminateCancel }
        return .terminateNow
    }
    private func showFatal(_ text: String) {
        let alert = NSAlert(); alert.messageText = "This installer is incomplete"; alert.informativeText = text
        alert.runModal(); NSApp.terminate(nil)
    }
}

@main
struct Entry {
    static func main() {
        let app = NSApplication.shared
        let delegate = SetupApp()
        app.setActivationPolicy(.regular)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
