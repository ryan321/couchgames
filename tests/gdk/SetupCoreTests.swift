import Foundation
import CryptoKit

@main struct Tests {
    static var checks = 0
    static func expect(_ value: Bool, _ message: String) throws {
        checks += 1
        if !value { throw SetupFailure("Test failed: " + message) }
    }
    static func rejected(_ message: String, _ operation: () throws -> Void) throws {
        var failed = false
        do { try operation() } catch { failed = true }
        try expect(failed, message)
    }
    static func fixture(_ root: URL, path: String = "nested/content.txt") throws {
        try FileManager.default.createDirectory(at: root.appendingPathComponent("nested"), withIntermediateDirectories: true)
        let data = Data("synthetic non-playable installer fixture".utf8)
        try data.write(to: root.appendingPathComponent("nested/content.txt"))
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let manifest = KitManifest(format: 1, version: "0.1.0-test", files: [KitFile(path: path, size: data.count, sha256: hash, executable: false)])
        try JSONEncoder().encode(manifest).write(to: root.appendingPathComponent("kit.json"))
    }
    static func main() throws {
        let fm = FileManager.default
        let temporary = fm.temporaryDirectory.appendingPathComponent("couch-gdk-test-"+UUID().uuidString)
        try fm.createDirectory(at: temporary, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: temporary) }
        let source = temporary.appendingPathComponent("payload")
        let destination = temporary.appendingPathComponent("installed")
        try fixture(source)
        let absent = SetupCore.inspectInstallation(payload: source, parent: destination)
        try expect(absent.installed == nil && absent.conflict == nil, "fresh location reports kit needed")
        let installed = try SetupCore.install(payload: source, parent: destination)
        try expect(fm.fileExists(atPath: installed.appendingPathComponent("nested/content.txt").path), "verified files install")
        try expect(SetupCore.inspectInstallation(payload: source, parent: destination).installed == installed, "existing verified kit is detected before reinstall")
        let upgrade = temporary.appendingPathComponent("upgrade")
        try fixture(upgrade)
        let upgradeManifest = upgrade.appendingPathComponent("kit.json")
        let originalManifest = try String(contentsOf: upgradeManifest, encoding: .utf8)
        try originalManifest.replacingOccurrences(of: "0.1.0-test", with: "0.1.0-test.2").write(to: upgradeManifest, atomically: true, encoding: .utf8)
        let pending = SetupCore.inspectInstallation(payload: upgrade, parent: destination)
        try expect(pending.installed == nil && pending.previousVersion == "0.1.0-test", "previous version is reported without claiming new kit is installed")
        try Data("user-created project".utf8).write(to: installed.appendingPathComponent("my-project.txt"))
        let again = try SetupCore.install(payload: source, parent: destination)
        try expect(again == installed && fm.fileExists(atPath: installed.appendingPathComponent("my-project.txt").path), "identical reinstall preserves extra user files")
        try Data("damaged".utf8).write(to: installed.appendingPathComponent("nested/content.txt"))
        try expect(SetupCore.inspectInstallation(payload: source, parent: destination).conflict != nil, "damaged installed kit is not reported ready")
        try rejected("changed existing installation is never overwritten") { _ = try SetupCore.install(payload: source, parent: destination) }
        let bad = temporary.appendingPathComponent("bad")
        try fixture(bad, path: "../escape.txt")
        try rejected("parent traversal") { _ = try SetupCore.verify(bad) }
        try fixture(bad, path: "/absolute.txt")
        try rejected("absolute paths") { _ = try SetupCore.verify(bad) }
        try fixture(bad)
        try fm.removeItem(at: bad.appendingPathComponent("nested/content.txt"))
        try fm.createSymbolicLink(at: bad.appendingPathComponent("nested/content.txt"), withDestinationURL: source.appendingPathComponent("nested/content.txt"))
        try rejected("symlink payload") { _ = try SetupCore.verify(bad) }
        try rejected("bad payload cannot activate") { _ = try SetupCore.install(payload: bad, parent: temporary.appendingPathComponent("bad-install")) }
        try expect(!fm.fileExists(atPath: temporary.appendingPathComponent("bad-install/0.1.0-test").path), "failed install leaves no active kit")
        let fake = temporary.appendingPathComponent("Fake Godot ; literal.app/Contents/MacOS/Godot")
        try fm.createDirectory(at: fake.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("#!/bin/sh\nprintf '4.7.2.stable.official.synthetic\\n'\n".utf8).write(to: fake)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.path)
        let tool = URL(fileURLWithPath: CommandLine.arguments[1])
        let ready = try SetupCore.doctor(tool: tool, godot: fake.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path)
        try expect(ready["supported"] as? Bool == true, "shared doctor accepts matching synthetic version and literal special-character path")
        try Data("#!/bin/sh\nprintf '4.6.0.stable.official.synthetic\\n'\n".utf8).write(to: fake)
        let old = try SetupCore.doctor(tool: tool, godot: fake.path)
        try expect(old["status"] as? String == "unsupported", "old engine gets setup state")
        let missing = try SetupCore.doctor(tool: tool, godot: temporary.appendingPathComponent("absent").path)
        try expect(missing["supported"] as? Bool == false && missing["executable"] is NSNull, "missing explicit engine never falls back silently")
        try expect((missing["policy"] as? [String:Any])?["download_url"] as? String != nil, "missing engine has pinned download guidance")
        let slow = temporary.appendingPathComponent("slow")
        try Data("#!/bin/sh\nexec /bin/sleep 20\n".utf8).write(to: slow)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: slow.path)
        try rejected("process timeout returns instead of hanging setup") { _ = try SetupCore.run(slow, [], timeout: 0.1) }
        // Agent detection and install orchestration use synthetic tools, never live downloads.
        let agentBin = temporary.appendingPathComponent("agents with spaces")
        try fm.createDirectory(at: agentBin, withIntermediateDirectories: true)
        let codex = AgentCore.providers.first { $0.id == "codex" }!
        let cursor = AgentCore.providers.first { $0.id == "cursor" }!
        try expect(!AgentCore.detect(codex, directories: [agentBin]).found, "absent agent is not detected")
        let fakeAgent = agentBin.appendingPathComponent("codex")
        try Data("#!/bin/sh\nprintf 'codex-cli 1.2.3 synthetic\\n'\n".utf8).write(to: fakeAgent)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeAgent.path)
        try expect(AgentCore.detect(codex, directories: [agentBin]).found, "version probe detects literal agent path")
        let grokAlias = agentBin.appendingPathComponent("grok-synthetic")
        try fm.copyItem(at: fakeAgent, to: grokAlias)
        try fm.createSymbolicLink(at: agentBin.appendingPathComponent("agent"), withDestinationURL: grokAlias)
        try expect(!AgentCore.detect(cursor, directories: [agentBin]).found, "Grok agent alias is never labeled Cursor")
        try Data("#!/bin/sh\nexit 2\n".utf8).write(to: fakeAgent)
        try expect(!AgentCore.detect(codex, directories: [agentBin]).found, "failed version probe is not reported installed")
        let directories = AgentCore.searchDirectories(home: temporary, path: "/custom/bin:relative::/custom/bin")
        try expect(directories.contains(temporary.appendingPathComponent(".local/bin")) && directories.filter { $0.path == "/custom/bin" }.count == 1 && directories.allSatisfy { $0.path.hasPrefix("/") }, "Finder discovery includes common folders and deduplicates absolute PATH")
        var calls = [String]()
        let downloadFixture: AgentCore.Runner = { executable, arguments, _ in
            calls.append(executable.path)
            if executable.lastPathComponent == "curl" {
                let output = arguments[arguments.firstIndex(of: "--output")! + 1]
                try Data("# synthetic, never executed\n".utf8).write(to: URL(fileURLWithPath: output))
            }
            return CommandResult(status: 0, output: Data())
        }
        try AgentCore.install(codex, runner: downloadFixture)
        try expect(calls == ["/usr/bin/curl", "/bin/sh"], "explicit install downloads before executing vendor shell")
        calls = []
        try rejected("failed download never executes installer") {
            try AgentCore.install(codex, runner: { executable, _, _ in
                calls.append(executable.path); return CommandResult(status: 22, output: Data())
            })
        }
        try expect(calls == ["/usr/bin/curl"], "download failure stops execution")
        let unknown = AgentProvider(id: "untrusted", name: "Other", commands: [], installURL: "https://example.com/install", shell: "/bin/sh", docsURL: "", startCommand: "")
        try rejected("unlisted installer cannot run") { try AgentCore.install(unknown, runner: downloadFixture) }
        if CommandLine.arguments.count > 2 {
            let payload = URL(fileURLWithPath: CommandLine.arguments[2])
            let target = URL(fileURLWithPath: CommandLine.arguments[3])
            _ = try SetupCore.verify(payload)
            let full = try SetupCore.install(payload: payload, parent: target)
            try expect(fm.isExecutableFile(atPath: full.appendingPathComponent("bin/couch").path), "installed CLI keeps executable permissions")
            try expect(fm.isExecutableFile(atPath: full.appendingPathComponent("Giga Couch Creator.app/Contents/MacOS/GDKSetup").path), "installed native launcher keeps executable permissions")
            print("Installed kit for independent playtest: \(full.path)")
        }
        print("GDK installer checks passed: \(checks). Synthetic fixtures are not playable games.")
    }
}
