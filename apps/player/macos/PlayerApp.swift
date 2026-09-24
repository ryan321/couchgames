import AppKit

// Local source-library app. Python and source paths are recorded by the build script.
final class PlayerApp: NSObject, NSApplicationDelegate {
    private var host: Process?
    private var quitting = false
    private var starting = false
    private var statusWindow: NSWindow?
    private let stageLabel = StudioStyle.label("Checking your game engine…", size: 14, color: StudioStyle.muted)
    private var startupDirectory: URL?
    private var startupTimer: Timer?
    private var libraryReady = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        StudioBrand.applyAppIcon()
        let menu = NSMenu()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Giga Couch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let item = NSMenuItem(); item.submenu = appMenu; menu.addItem(item); NSApp.mainMenu = menu
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 320), styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "Giga Couch"
        window.backgroundColor = StudioStyle.background
        window.appearance = NSAppearance(named: .darkAqua)
        // Stay visible above the engine's initial blank window until it has drawn the library.
        window.level = .floating
        let brand = StudioBrand.markView(size: 88)
        let title = StudioStyle.label("Getting your games ready", size: 25, weight: .semibold, display: true)
        let spinner = NSProgressIndicator()
        spinner.style = .spinning; spinner.controlSize = .regular; spinner.startAnimation(nil)
        let stack = NSStackView(views: [brand, title, spinner, stageLabel])
        stack.orientation = .vertical; stack.alignment = .centerX; stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: window.contentView!.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: window.contentView!.centerYAnchor),
            stack.widthAnchor.constraint(equalToConstant: 460)
        ])
        window.center(); window.makeKeyAndOrderFront(nil); statusWindow = window
        starting = true
        DispatchQueue.global().async {
            do {
                guard let rootPath = Bundle.main.object(forInfoDictionaryKey: "GigaSourceRoot") as? String else { throw SetupFailure("This app is incomplete. Rebuild it with scripts/build_player.py.") }
                let root = URL(fileURLWithPath: rootPath)
                guard FileManager.default.fileExists(atPath: root.appendingPathComponent("sdk/launcher/library.tscn").path) else {
                    throw SetupFailure("The source checkout has moved. Run scripts/build_player.py from the project to refresh this local app.")
                }
                let tool = Bundle.main.resourceURL!.appendingPathComponent("couch")
                let selected = UserDefaults(suiteName: "com.gigacouch.gdk")?.string(forKey: "selectedGodot")
                let report = try SetupCore.doctor(tool: tool, godot: selected)
                guard report["supported"] as? Bool == true, let engine = report["executable"] as? String else {
                    throw SetupFailure("A supported Godot editor was not found. Open Giga Couch Setup to choose your installed editor, then try again.")
                }
                let startup = FileManager.default.temporaryDirectory.appendingPathComponent("couch-player-startup-" + UUID().uuidString)
                try FileManager.default.createDirectory(at: startup, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
                let logs = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/GigaCouch")
                try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
                let logURL = logs.appendingPathComponent("player.log")
                FileManager.default.createFile(atPath: logURL.path, contents: nil)
                let output = try FileHandle(forWritingTo: logURL)
                let process = Process()
                process.executableURL = tool
                process.arguments = ["host", "--godot", engine, "--root", root.path, "--sdk", root.appendingPathComponent("sdk").path]
                process.currentDirectoryURL = root
                var environment = SetupCore.environment()
                environment["COUCH_CLI"] = tool.path
                environment["COUCH_PLAYER_STARTUP"] = startup.appendingPathComponent("status.json").path
                environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin"
                process.environment = environment
                process.standardInput = FileHandle.nullDevice
                process.standardOutput = output; process.standardError = output
                process.terminationHandler = { child in
                    DispatchQueue.main.async {
                        self.host = nil
                        self.clearStartup()
                        if self.quitting { NSApp.reply(toApplicationShouldTerminate: true) }
                        else if child.terminationStatus != 0 { self.fail("The game library closed unexpectedly. See ~/Library/Logs/GigaCouch/player.log for details.") }
                        else if !self.libraryReady { self.fail("The library closed before it was ready. Please try again.") }
                        else { NSApp.terminate(nil) }
                    }
                }
                // Start on the main queue so quit cannot race with process ownership.
                DispatchQueue.main.async {
                    self.starting = false
                    do {
                        self.host = process
                        self.startupDirectory = startup
                        self.stageLabel.stringValue = "Starting your game library…"
                        try process.run()
                        try? output.close()
                        self.startupTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak owner = self] _ in owner?.readStartup() }
                    } catch { self.host = nil; self.fail(error.localizedDescription) }
                }
            } catch { DispatchQueue.main.async { self.starting = false; self.fail(error.localizedDescription) } }
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !libraryReady {
            statusWindow?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            focusPlayerWindow()
        }
        return false
    }
    private func focusPlayerWindow() {
        guard let directory = startupDirectory,
              let data = try? Data(contentsOf: directory.appendingPathComponent("foreground.json")), data.count < 4096,
              let report = try? JSONSerialization.jsonObject(with: data) as? [String: Int],
              let pid = report["pid"], pid > 0,
              let app = NSRunningApplication(processIdentifier: pid_t(pid)) else { return }
        // Ask the library to restore a minimized window; active games keep their own focus.
        if report["library_pid"] == pid {
            try? Data().write(to: directory.appendingPathComponent("focus-library"), options: .atomic)
        }
        app.unhide()
        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if starting { return .terminateCancel }
        if let host, host.isRunning {
            quitting = true; host.terminate()
            return .terminateLater
        }
        return .terminateNow
    }
    private func readStartup() {
        guard let path = startupDirectory?.appendingPathComponent("status.json"),
              let data = try? Data(contentsOf: path), data.count <= 4096,
              let report = try? JSONSerialization.jsonObject(with: data) as? [String: String] else { return }
        switch report["phase"] {
        case "checking": stageLabel.stringValue = "Checking your game engine…"
        case "importing": stageLabel.stringValue = "Preparing game artwork and resources…"
        case "opening": stageLabel.stringValue = "Opening your game library…"
        case "ready":
            libraryReady = true
            statusWindow?.orderOut(nil)
            startupTimer?.invalidate(); startupTimer = nil
            focusPlayerWindow()
        default: break
        }
    }
    private func clearStartup() {
        startupTimer?.invalidate(); startupTimer = nil
        if let startupDirectory { try? FileManager.default.removeItem(at: startupDirectory) }
        startupDirectory = nil
    }
    private func fail(_ message: String) {
        clearStartup()
        statusWindow?.orderOut(nil)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert(); alert.messageText = "Could not open Giga Couch"; alert.informativeText = message
        alert.runModal(); NSApp.terminate(nil)
    }
}
@main struct PlayerEntry {
    static func main() {
        let app = NSApplication.shared
        let delegate = PlayerApp()
        app.setActivationPolicy(.regular); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
