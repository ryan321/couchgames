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
        let installed = try SetupCore.install(payload: source, parent: destination)
        try expect(fm.fileExists(atPath: installed.appendingPathComponent("nested/content.txt").path), "verified files install")
        try Data("user-created project".utf8).write(to: installed.appendingPathComponent("my-project.txt"))
        let again = try SetupCore.install(payload: source, parent: destination)
        try expect(again == installed && fm.fileExists(atPath: installed.appendingPathComponent("my-project.txt").path), "identical reinstall preserves extra user files")
        try Data("damaged".utf8).write(to: installed.appendingPathComponent("nested/content.txt"))
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
        if CommandLine.arguments.count > 2 {
            let payload = URL(fileURLWithPath: CommandLine.arguments[2])
            let target = URL(fileURLWithPath: CommandLine.arguments[3])
            _ = try SetupCore.verify(payload)
            let full = try SetupCore.install(payload: payload, parent: target)
            try expect(fm.isExecutableFile(atPath: full.appendingPathComponent("bin/couch").path), "installed CLI keeps executable permissions")
            try expect(fm.isExecutableFile(atPath: full.appendingPathComponent("Couch Games Creator.app/Contents/MacOS/GDKSetup").path), "installed native launcher keeps executable permissions")
            print("Installed kit for independent playtest: \(full.path)")
        }
        print("GDK installer checks passed: \(checks). Synthetic fixtures are not playable games.")
    }
}
