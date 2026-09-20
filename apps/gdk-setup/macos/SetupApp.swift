import AppKit

final class SetupApp: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let preferences = UserDefaults(suiteName: "com.gigacouch.gdk")!
    private var window: NSWindow!
    private let engineStatus = NSTextField(wrappingLabelWithString: "Checking this Mac…")
    private let engineDetail = NSTextField(wrappingLabelWithString: "")
    private let destinationLabel = NSTextField(wrappingLabelWithString: "")
    private let message = NSTextField(wrappingLabelWithString: "")
    private let progress = NSProgressIndicator()
    private let enginePill = StatusPill()
    private let agentPill = StatusPill()
    private let agentStatus = StudioStyle.label("Checking installed agents…", size: 13, weight: .medium)
    private var agentInventory: [AgentDetection] = []
    private var agentSetup: AgentSetup?
    private let kitPill = StatusPill()
    private let readiness = StatusPill()
    private let engineRequired = StudioStyle.label("Supported standard editor", size: 14, weight: .medium)
    private let kitStatus = StudioStyle.label("Checking…", size: 14, weight: .medium)
    private let diskStatus = StudioStyle.label("", size: 11, color: StudioStyle.muted)
    private var downloadButton: NSButton!
    private var kitConflict = false
    private var previousKit: String?
    private var installButton: NSButton!
    private var launchButton: NSButton!
    private var controls: [NSButton] = []
    private var installed: URL?
    private var godot: String?
    private var selectedGodot: String?
    private var downloadURL: URL?
    private var kit: KitManifest!
    private var payload: URL!
    private var parent = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/GigaCouch/GDK")
    private var busy = false
    private var isInstalledApp = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        StudioBrand.applyAppIcon()
        isInstalledApp = Bundle.main.object(forInfoDictionaryKey: "GigaGDKInstalled") as? Bool == true
        payload = isInstalledApp ? Bundle.main.bundleURL.deletingLastPathComponent() : Bundle.main.resourceURL!.appendingPathComponent("payload")
        do { kit = try SetupCore.manifest(at: payload) }
        catch { showFatal(error.localizedDescription); return }
        if let saved = preferences.string(forKey: "installParent") { parent = URL(fileURLWithPath: saved) }
        if isInstalledApp { installed = payload; parent = payload.deletingLastPathComponent() }
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--godot"), i + 1 < args.count { selectedGodot = args[i + 1] }
        else { selectedGodot = preferences.string(forKey: "selectedGodot") }
        buildWindow()
        checkEngine(autoLaunch: isInstalledApp)
    }
    private func label(_ text: String, size: CGFloat = 14, weight: NSFont.Weight = .regular) -> NSTextField {
        StudioStyle.label(text, size: size, weight: weight)
    }
    private func button(_ title: String, action: Selector, primary: Bool = false) -> NSButton {
        let b = StudioButton(title: title, target: self, action: action)
        b.isBordered = false
        b.primary = primary
        b.setAccessibilityLabel(title)
        controls.append(b)
        return b
    }
    private func row(_ views: [NSView]) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 10
        return stack
    }
    private func column(_ views: [NSView], spacing: CGFloat = 6) -> NSStackView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        return stack
    }
    private func spacer() -> NSView {
        let view = NSView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return view
    }
    private func requirement(_ caption: String, value: NSTextField) -> NSStackView {
        let caption = StudioStyle.label(caption, size: 9, weight: .semibold, color: StudioStyle.muted)
        return column([caption, value], spacing: 4)
    }
    private func card(title: String, subtitle: String, symbol: String, pill: StatusPill, required: NSTextField, found: NSTextField, detail: NSTextField, actions: [NSView]) -> NSView {
        let card = StudioStyle.box(StudioStyle.panel, radius: 16)
        card.layer?.borderWidth = 1
        card.layer?.borderColor = StudioStyle.border.cgColor
        let iconBox = StudioStyle.box(StudioStyle.border, radius: 10)
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        icon.contentTintColor = StudioStyle.mint
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBox.addSubview(icon)
        NSLayoutConstraint.activate([
            iconBox.widthAnchor.constraint(equalToConstant: 38), iconBox.heightAnchor.constraint(equalToConstant: 38),
            icon.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor), icon.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 23), icon.heightAnchor.constraint(equalToConstant: 23)
        ])
        let heading = row([iconBox, column([label(title, size: 17, weight: .semibold), StudioStyle.label(subtitle, size: 11, color: StudioStyle.muted)], spacing: 3), spacer(), pill])
        let needed = requirement("YOU NEED", value: required)
        let available = requirement("ON THIS MAC", value: found)
        let comparison = row([needed, available])
        comparison.distribution = .fillEqually
        needed.widthAnchor.constraint(equalTo: available.widthAnchor).isActive = true
        detail.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        detail.textColor = StudioStyle.muted
        detail.maximumNumberOfLines = 1
        detail.lineBreakMode = .byTruncatingMiddle
        detail.isSelectable = true
        let content = column([heading, comparison, detail, row(actions)], spacing: 11)
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
            heading.widthAnchor.constraint(equalTo: content.widthAnchor),
            comparison.widthAnchor.constraint(equalTo: content.widthAnchor),
            detail.widthAnchor.constraint(equalTo: content.widthAnchor)
        ])
        return card
    }
    private func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: min(920, (NSScreen.main?.visibleFrame.height ?? 960) - 40)), styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = isInstalledApp ? "Giga Couch Creator" : "Giga Couch GDK Setup"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = StudioStyle.background
        window.appearance = NSAppearance(named: .darkAqua)
        window.delegate = self
        window.center()
        let canvas = window.contentView!
        let rail = StudioRail()
        rail.translatesAutoresizingMaskIntoConstraints = false
        canvas.addSubview(rail)
        NSLayoutConstraint.activate([
            rail.leadingAnchor.constraint(equalTo: canvas.leadingAnchor), rail.topAnchor.constraint(equalTo: canvas.topAnchor),
            rail.bottomAnchor.constraint(equalTo: canvas.bottomAnchor), rail.widthAnchor.constraint(equalToConstant: 250)
        ])
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        scroll.documentView = document
        canvas.addSubview(scroll)
        let root = column([], spacing: 16)
        root.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(root)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: rail.trailingAnchor, constant: 34),
            scroll.trailingAnchor.constraint(equalTo: canvas.trailingAnchor, constant: -26),
            scroll.topAnchor.constraint(equalTo: canvas.topAnchor, constant: 40),
            scroll.bottomAnchor.constraint(equalTo: canvas.bottomAnchor, constant: -122),
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            root.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -8),
            root.topAnchor.constraint(equalTo: document.topAnchor),
            root.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -8)
        ])
        let header = column([
            StudioStyle.label("CREATOR SETUP", size: 10, weight: .semibold, color: StudioStyle.mint),
            label("Your studio starts here.", size: 32, weight: .bold),
            StudioStyle.label("Let’s check what you have and get the rest ready.", size: 14, color: StudioStyle.muted)
        ], spacing: 7)
        root.addArrangedSubview(header)
        let summary = row([readiness, spacer(), diskStatus])
        root.addArrangedSubview(summary)
        summary.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        engineStatus.font = .systemFont(ofSize: 14, weight: .medium)
        engineStatus.textColor = StudioStyle.text
        engineStatus.maximumNumberOfLines = 1
        engineStatus.lineBreakMode = .byTruncatingTail
        downloadButton = button("Get Godot ↗", action: #selector(downloadGodot))
        let engine = card(title: "Godot editor", subtitle: "Build your worlds. Bring them to life.", symbol: "cube.transparent.fill", pill: enginePill,
                          required: engineRequired, found: engineStatus, detail: engineDetail,
                          actions: [button("Choose editor…", action: #selector(chooseGodot)), downloadButton, button("Check again", action: #selector(autoDetect))])
        root.addArrangedSubview(engine)
        engine.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        let amount = ByteCountFormatter.string(fromByteCount: Int64(kit.totalBytes), countStyle: .file)
        let kitCard = card(title: "Giga Couch GDK", subtitle: "SDK · 3D starter · Creator Hub · guides", symbol: "shippingbox.fill", pill: kitPill,
                           required: label(kit.version, size: 14, weight: .medium), found: kitStatus, detail: destinationLabel,
                           actions: [button("Change location…", action: #selector(chooseDestination)), button("Show files", action: #selector(showFiles)), StudioStyle.label(amount + " to install", size: 11, color: StudioStyle.muted)])
        root.addArrangedSubview(kitCard)
        kitCard.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        let agentCard = StudioStyle.box(StudioStyle.panel, radius: 16)
        agentCard.layer?.borderWidth = 1; agentCard.layer?.borderColor = StudioStyle.border.cgColor
        let agentHeader = row([label("AI coding assistant", size: 17, weight: .semibold), spacer(), agentPill])
        let agentContent = column([agentHeader, agentStatus, row([button("Choose an agent…", action: #selector(chooseAgent)), button("I already have an agent", action: #selector(haveAgent))])], spacing: 12)
        agentContent.translatesAutoresizingMaskIntoConstraints = false
        agentCard.addSubview(agentContent)
        root.addArrangedSubview(agentCard)
        NSLayoutConstraint.activate([
            agentCard.widthAnchor.constraint(equalTo: root.widthAnchor),
            agentContent.leadingAnchor.constraint(equalTo: agentCard.leadingAnchor, constant: 20),
            agentContent.trailingAnchor.constraint(equalTo: agentCard.trailingAnchor, constant: -20),
            agentContent.topAnchor.constraint(equalTo: agentCard.topAnchor, constant: 18),
            agentContent.bottomAnchor.constraint(equalTo: agentCard.bottomAnchor, constant: -18),
            agentHeader.widthAnchor.constraint(equalTo: agentContent.widthAnchor),
            agentStatus.widthAnchor.constraint(equalTo: agentContent.widthAnchor)
        ])
        let note = StudioStyle.label("Already have Godot? We’ll reuse it. Need it? Get Godot opens the official download page, then you can choose the editor here.", size: 11, color: StudioStyle.muted)
        root.addArrangedSubview(note)
        note.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        let footer = StudioStyle.box(StudioStyle.color(0x142b28), radius: 12)
        footer.translatesAutoresizingMaskIntoConstraints = false
        canvas.addSubview(footer)
        NSLayoutConstraint.activate([
            footer.leadingAnchor.constraint(equalTo: rail.trailingAnchor, constant: 34),
            footer.trailingAnchor.constraint(equalTo: canvas.trailingAnchor, constant: -34),
            footer.bottomAnchor.constraint(equalTo: canvas.bottomAnchor, constant: -28)
        ])
        message.font = .systemFont(ofSize: 12, weight: .medium)
        message.textColor = StudioStyle.text
        message.maximumNumberOfLines = 3
        progress.style = .spinning
        progress.controlSize = .small
        progress.isDisplayedWhenStopped = false
        installButton = button("Install GDK →", action: #selector(installKit), primary: true)
        launchButton = button("Open Creator Hub →", action: #selector(openHub), primary: true)
        let footerContent = row([progress, message, spacer(), installButton, launchButton])
        footerContent.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(footerContent)
        NSLayoutConstraint.activate([
            footerContent.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 18),
            footerContent.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -18),
            footerContent.topAnchor.constraint(equalTo: footer.topAnchor, constant: 15),
            footerContent.bottomAnchor.constraint(equalTo: footer.bottomAnchor, constant: -15),
            message.widthAnchor.constraint(lessThanOrEqualToConstant: 320)
        ])
        destinationLabel.stringValue = displayPath(parent.appendingPathComponent(kit.version).path)
        let menu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let item = NSMenuItem(); item.submenu = appMenu; menu.addItem(item)
        NSApp.mainMenu = menu
        window.initialFirstResponder = installButton
        setBusy(false)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    private func displayPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
    }
    private func setBusy(_ value: Bool) {
        busy = value
        controls.forEach { $0.isEnabled = !value }
        installButton.isHidden = installed != nil
        installButton.isEnabled = !value && !kitConflict
        installButton.title = previousKit == nil ? "Install GDK →" : "Install update →"
        installButton.setAccessibilityLabel(installButton.title)
        launchButton.isHidden = installed == nil
        launchButton.isEnabled = !value && installed != nil && godot != nil
        installButton.keyEquivalent = installed == nil ? "\r" : ""
        launchButton.keyEquivalent = installed != nil ? "\r" : ""
        downloadButton.isHidden = godot != nil
        downloadButton.isEnabled = !value && downloadURL != nil
        if value { progress.startAnimation(nil) } else { progress.stopAnimation(nil) }
        if value { readiness.set("CHECKING YOUR SETUP", color: StudioStyle.blue) }
        else {
            let count = (godot == nil ? 0 : 1) + (installed == nil ? 0 : 1)
            readiness.set(count == 2 ? "✓  YOU’RE READY TO CREATE" : "\(count) OF 2 READY", color: count == 2 ? StudioStyle.mint : StudioStyle.blue)
        }
    }
    private func checkEngine(autoLaunch: Bool = false) {
        godot = nil
        setBusy(true)
        engineStatus.stringValue = "Checking…"
        enginePill.set("CHECKING", color: StudioStyle.blue)
        kitPill.set("CHECKING", color: StudioStyle.blue)
        message.stringValue = "Looking for your editor and development kit…"
        let tool = payload.appendingPathComponent("bin/couch")
        let source = payload!, destination = parent
        let override = selectedGodot
        DispatchQueue.global().async {
            let presence = SetupCore.inspectInstallation(payload: source, parent: destination)
            let agents = AgentCore.detectAll()
            let result = Result { try SetupCore.doctor(tool: tool, godot: override) }
            var volume = destination
            while !FileManager.default.fileExists(atPath: volume.path) && volume.path != "/" { volume = volume.deletingLastPathComponent() }
            let free = ((try? FileManager.default.attributesOfFileSystem(forPath: volume.path))?[.systemFreeSize] as? NSNumber)?.int64Value
            DispatchQueue.main.async {
                self.agentInventory = agents
                self.refreshAgentStatus()
                self.installed = presence.installed
                self.previousKit = presence.previousVersion
                self.kitConflict = presence.conflict != nil
                self.destinationLabel.stringValue = self.displayPath(destination.appendingPathComponent(self.kit.version).path)
                self.destinationLabel.toolTip = destination.appendingPathComponent(self.kit.version).path
                if presence.installed != nil {
                    self.kitStatus.stringValue = "Installed & verified"
                    self.kitPill.set("✓  READY", color: StudioStyle.mint)
                } else if presence.conflict != nil {
                    self.kitStatus.stringValue = "Needs attention"
                    self.kitPill.set("CHECK LOCATION", color: StudioStyle.amber)
                } else {
                    self.kitStatus.stringValue = presence.previousVersion ?? "Not installed yet"
                    self.kitPill.set(presence.previousVersion == nil ? "READY TO INSTALL" : "UPDATE AVAILABLE", color: StudioStyle.blue)
                }
                self.diskStatus.stringValue = "Apple silicon" + (free.map { "  ·  " + ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) + " free" } ?? "")
                switch result {
                case .success(let report):
                    let policy = report["policy"] as? [String: Any] ?? [:]
                    let version = policy["godot_version"] as? String ?? "supported"
                    self.engineRequired.stringValue = "Godot \(version) · standard"
                    self.downloadURL = (policy["download_url"] as? String).flatMap(URL.init(string:))
                    if report["supported"] as? Bool == true, let exe = report["executable"] as? String {
                        self.godot = exe
                        self.engineStatus.stringValue = "Godot \(version) · standard"
                        self.engineDetail.stringValue = self.displayPath(exe)
                        self.engineDetail.toolTip = exe
                        self.enginePill.set("✓  READY", color: StudioStyle.mint)
                        self.message.stringValue = self.installed == nil ? "Your editor is ready. Let’s add the kit." : "All set. Your next game starts in Creator Hub."
                    } else {
                        let attempts = report["attempts"] as? [[String: Any]] ?? []
                        let found = attempts.compactMap { $0["version"] as? [String: Any] }.last
                        if let actual = found?["version"] as? String {
                            self.engineStatus.stringValue = "Godot \(actual) · \(found?["edition"] as? String ?? "")"
                            self.engineDetail.stringValue = "This editor does not match the required version. Choose another or get Godot."
                        } else {
                            self.engineStatus.stringValue = "Not found"
                            self.engineDetail.stringValue = "Choose an existing editor, or download the required version."
                        }
                        self.engineDetail.toolTip = attempts.compactMap { $0["reason"] as? String }.joined(separator: "\n")
                        self.enginePill.set("ACTION NEEDED", color: StudioStyle.amber)
                        self.message.stringValue = self.installed == nil ? "Install the kit now; connect your editor when you’re ready." : "Your kit is ready. Add Godot to open Creator Hub."
                    }
                case .failure(let error):
                    self.engineStatus.stringValue = "Could not check"
                    self.engineDetail.stringValue = "Try Check again or choose your editor."
                    self.engineDetail.toolTip = error.localizedDescription
                    self.enginePill.set("ACTION NEEDED", color: StudioStyle.amber)
                    self.message.stringValue = "The editor check couldn’t finish. Try again."
                }
                if let issue = presence.conflict { self.message.stringValue = issue }
                self.setBusy(false)
                if autoLaunch && self.godot != nil && self.installed != nil { self.openHub() }
            }
        }
    }
    private func refreshAgentStatus() {
        let found = agentInventory.filter(\.found)
        let preferred = preferences.string(forKey: "preferredAgent")
        if preferences.bool(forKey: "hasExternalAgent") {
            agentStatus.stringValue = "Using your own agent · confirmed by you"
            agentPill.set("YOUR CHOICE", color: StudioStyle.mint)
        } else if !found.isEmpty {
            agentStatus.stringValue = found.map { $0.provider.name + ($0.provider.id == preferred ? " (selected)" : "") }.joined(separator: " · ") + " detected"
            agentPill.set("✓  DETECTED", color: StudioStyle.mint)
        } else {
            agentStatus.stringValue = "No supported CLI found. Add one or bring your own."
            agentPill.set("OPTIONAL", color: StudioStyle.blue)
        }
        agentStatus.toolTip = "CLI detection only; sign-in is handled by each provider. AI is optional and does not block the GDK."
    }
    @objc private func haveAgent() {
        preferences.set(true, forKey: "hasExternalAgent")
        preferences.removeObject(forKey: "preferredAgent")
        refreshAgentStatus()
    }
    @objc private func chooseAgent() {
        agentSetup = AgentSetup(parent: window, inventory: agentInventory, preferences: preferences, busyChanged: { [weak self] value in self?.setBusy(value) }, completion: { [weak self] in
            self?.agentSetup = nil
            self?.checkEngine()
        })
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
                self.preferences.set(url.path, forKey: "installParent")
                self.checkEngine()
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
                    self.destinationLabel.stringValue = self.displayPath(location.path)
                    self.destinationLabel.toolTip = location.path
                    self.kitStatus.stringValue = "Installed & verified"
                    self.kitPill.set("✓  READY", color: StudioStyle.mint)
                    self.kitConflict = false
                    self.preferences.set(destination.path, forKey: "installParent")
                    self.message.stringValue = self.godot == nil ? "Kit installed. Add Godot to open Creator Hub." : "All set. Your next game starts in Creator Hub."
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
