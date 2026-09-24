import AppKit

final class AgentSetup: NSObject {
    let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 640, height: 510), styleMask: [.titled], backing: .buffered, defer: false)
    private let picker = NSPopUpButton()
    private let status = StudioStyle.label("", size: 14, weight: .medium)
    private let detail = StudioStyle.label("", size: 12, color: StudioStyle.muted)
    private let feedback = StudioStyle.label("", size: 12, color: StudioStyle.mint)
    private let progress = NSProgressIndicator()
    private var installButton: NSButton!
    private var buttons: [NSButton] = []
    private var inventory: [AgentDetection]
    private let preferences: UserDefaults
    private let completion: () -> Void
    private let busyChanged: (Bool) -> Void
    private var busy = false
    private var selected: AgentProvider { AgentCore.providers[picker.indexOfSelectedItem] }

    init(parent: NSWindow, inventory: [AgentDetection], preferences: UserDefaults, busyChanged: @escaping (Bool) -> Void, completion: @escaping () -> Void) {
        self.inventory = inventory
        self.preferences = preferences
        self.completion = completion
        self.busyChanged = busyChanged
        super.init()
        panel.title = "Choose your AI coding assistant"
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.backgroundColor = StudioStyle.background
        picker.addItems(withTitles: AgentCore.providers.map(\.name))
        picker.target = self; picker.action = #selector(selectionChanged)
        picker.setAccessibilityLabel("AI coding assistant")
        if let saved = preferences.string(forKey: "preferredAgent"), let index = AgentCore.providers.firstIndex(where: { $0.id == saved }) { picker.selectItem(at: index) }
        let title = StudioStyle.label("Meet your coding partner.", size: 26, weight: .bold, display: true)
        let intro = StudioStyle.label("Choose a CLI to help build your games. You can also use an agent in an editor, desktop app, or elsewhere.", size: 14, color: StudioStyle.muted)
        installButton = button("Install agent…", #selector(installAgent), primary: true)
        let actions = NSStackView(views: [installButton, button("Use this agent", #selector(useAgent)), button("Check again", #selector(recheck))])
        actions.spacing = 10
        let alternate = NSStackView(views: [button("I already have an agent", #selector(useOther)), button("Installation guide ↗", #selector(openGuide))])
        alternate.spacing = 10
        let done = button("Done", #selector(close))
        done.keyEquivalent = "\u{1b}"
        progress.style = .spinning; progress.controlSize = .small; progress.isDisplayedWhenStopped = false
        let bottom = NSStackView(views: [progress, feedback, done]); bottom.spacing = 12
        let root = NSStackView(views: [StudioStyle.label("AI ASSISTANT · OPTIONAL", size: 10, weight: .bold, color: StudioStyle.mint), title, intro, picker, status, detail, actions, alternate, bottom])
        root.orientation = .vertical; root.alignment = .leading; root.spacing = 18
        root.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView!.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor, constant: 28),
            root.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor, constant: -28),
            root.topAnchor.constraint(equalTo: panel.contentView!.topAnchor, constant: 24),
            intro.widthAnchor.constraint(equalTo: root.widthAnchor), detail.widthAnchor.constraint(equalTo: root.widthAnchor),
            picker.widthAnchor.constraint(equalTo: root.widthAnchor), bottom.widthAnchor.constraint(equalTo: root.widthAnchor),
            feedback.widthAnchor.constraint(lessThanOrEqualToConstant: 460)
        ])
        let closeButton = button("×", #selector(close))
        closeButton.setAccessibilityLabel("Close agent picker")
        closeButton.toolTip = "Close (Esc)"
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView!.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: panel.contentView!.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor, constant: -14),
            closeButton.widthAnchor.constraint(equalToConstant: 34),
            closeButton.heightAnchor.constraint(equalToConstant: 34)
        ])
        selectionChanged()
        parent.beginSheet(panel)
    }
    private func button(_ title: String, _ action: Selector, primary: Bool = false) -> NSButton {
        let b = StudioButton(title: title, target: self, action: action)
        b.isBordered = false; b.primary = primary; buttons.append(b)
        return b
    }
    @objc private func selectionChanged() {
        let detection = inventory.first { $0.provider.id == selected.id }
        status.stringValue = detection?.found == true ? "✓  \(detection?.version ?? selected.name) detected" : "\(selected.name) CLI not detected"
        status.textColor = detection?.found == true ? StudioStyle.mint : StudioStyle.amber
        detail.stringValue = detection?.executable?.path ?? "Install from \(URL(string: selected.installURL)!.host!). Then sign in with your own account. Provider access and billing are separate from Giga Couch."
        detail.maximumNumberOfLines = 3
        installButton.isEnabled = detection?.found != true
        buttons.first { $0.title == "Use this agent" }?.isEnabled = detection?.found == true
        feedback.stringValue = "CLI detection does not check account sign-in."
    }
    private func setBusy(_ value: Bool) {
        busy = value; busyChanged(value)
        picker.isEnabled = !value
        buttons.forEach { $0.isEnabled = !value }
        if value { progress.startAnimation(nil) } else { progress.stopAnimation(nil) }
    }
    @objc private func recheck() {
        setBusy(true); feedback.stringValue = "Checking installed CLIs…"
        DispatchQueue.global().async {
            let result = AgentCore.detectAll()
            DispatchQueue.main.async { self.inventory = result; self.setBusy(false); self.selectionChanged() }
        }
    }
    @objc private func openGuide() { NSWorkspace.shared.open(URL(string: selected.docsURL)!) }
    @objc private func useOther() {
        preferences.set(true, forKey: "hasExternalAgent")
        preferences.removeObject(forKey: "preferredAgent")
        close()
    }
    @objc private func useAgent() {
        guard let detection = inventory.first(where: { $0.provider.id == selected.id }), detection.found else { return }
        preferences.set(selected.id, forKey: "preferredAgent")
        preferences.set(false, forKey: "hasExternalAgent")
        feedback.stringValue = "Selected. Run \(detection.executable!.path) in your project’s terminal to sign in and start coding."
    }
    @objc private func installAgent() {
        let provider = selected
        let alert = NSAlert()
        alert.messageText = "Install \(provider.name)?"
        alert.informativeText = "Downloads and runs the official installer from:\n\(provider.installURL)\n\nThe vendor installs its CLI in your user account and may update shell settings. Sign in with the vendor after installation; Giga Couch does not collect your AI credentials."
        alert.addButton(withTitle: "Download & install")
        alert.addButton(withTitle: "Cancel")
        alert.beginSheetModal(for: panel) { result in
            guard result == .alertFirstButtonReturn else { return }
            self.setBusy(true); self.feedback.stringValue = "Installing \(provider.name)… This may take a few minutes."
            DispatchQueue.global().async {
                let result = Result { try AgentCore.install(provider) }
                let inventory = AgentCore.detectAll()
                DispatchQueue.main.async {
                    self.inventory = inventory; self.setBusy(false); self.selectionChanged()
                    switch result {
                    case .success:
                        if inventory.contains(where: { $0.provider.id == provider.id && $0.found }) {
                            self.preferences.set(provider.id, forKey: "preferredAgent")
                            self.preferences.set(false, forKey: "hasExternalAgent")
                            self.feedback.stringValue = "Installed. Run \(provider.startCommand) in your project’s terminal to sign in and start coding."
                        } else { self.feedback.stringValue = "Installer finished, but the CLI wasn’t detected. Open the guide or check again." }
                    case .failure(let error): self.feedback.stringValue = error.localizedDescription
                    }
                }
            }
        }
    }
    @objc private func close() {
        guard !busy else { return }
        panel.sheetParent?.endSheet(panel)
        completion()
    }
}
