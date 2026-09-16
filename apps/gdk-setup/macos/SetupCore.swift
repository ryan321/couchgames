import Foundation
import CryptoKit

struct SetupFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
    init(_ message: String) { self.message = message }
}
struct KitFile: Codable {
    let path: String
    let size: Int
    let sha256: String
    let executable: Bool
}
struct KitManifest: Codable {
    let format: Int
    let version: String
    let files: [KitFile]
    var totalBytes: Int { files.reduce(0) { $0 + $1.size } }
}
struct CommandResult {
    let status: Int32
    let output: Data
}

private final class OutputCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()
    func append(_ chunk: Data) {
        lock.lock(); defer { lock.unlock() }
        if data.count < 1_048_576 { data.append(chunk.prefix(1_048_576 - data.count)) }
    }
    func snapshot() -> Data { lock.lock(); defer { lock.unlock() }; return data }
}

// No shell commands, downloads, administrator access, or toolchain installation.
final class SetupCore {
    static let fm = FileManager.default
    static func manifest(at root: URL) throws -> KitManifest {
        let data = try Data(contentsOf: root.appendingPathComponent("kit.json"))
        guard data.count <= 1_048_576 else { throw SetupFailure("The kit manifest is too large.") }
        let manifest = try JSONDecoder().decode(KitManifest.self, from: data)
        guard manifest.format == 1, manifest.version.range(of: "^[0-9]+\\.[0-9]+\\.[0-9]+(?:-[a-z0-9.]+)?$", options: .regularExpression) != nil,
              !manifest.files.isEmpty, manifest.files.count <= 4096 else { throw SetupFailure("This kit manifest is not supported.") }
        var seen = Set<String>()
        for file in manifest.files {
            let parts = file.path.split(separator: "/", omittingEmptySubsequences: false)
            guard !file.path.isEmpty, !file.path.contains("\\"), !file.path.contains(":"),
                  !file.path.unicodeScalars.contains(where: { $0.value < 32 }),
                  parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
                  file.path != "kit.json", seen.insert(file.path.lowercased()).inserted,
                  file.size >= 0, file.size <= 536_870_912,
                  file.sha256.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else {
                throw SetupFailure("The kit contains an invalid or duplicate path: \(file.path)")
            }
        }
        guard manifest.totalBytes <= 1_073_741_824 else { throw SetupFailure("The kit exceeds the preview size limit.") }
        return manifest
    }
    static func checkedFile(_ file: KitFile, root: URL) throws -> URL {
        var path = root
        for component in file.path.split(separator: "/") {
            path.appendPathComponent(String(component))
            let attrs = try fm.attributesOfItem(atPath: path.path)
            guard attrs[.type] as? FileAttributeType != .typeSymbolicLink else { throw SetupFailure("The kit contains a symbolic link: \(file.path)") }
        }
        let attrs = try fm.attributesOfItem(atPath: path.path)
        guard attrs[.type] as? FileAttributeType == .typeRegular,
              (attrs[.size] as? NSNumber)?.intValue == file.size else { throw SetupFailure("Missing or incomplete kit file: \(file.path)") }
        let data = try Data(contentsOf: path, options: .mappedIfSafe)
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard hash == file.sha256 else { throw SetupFailure("Kit file failed verification: \(file.path). Download a fresh installer.") }
        return path
    }
    static func verify(_ root: URL) throws -> KitManifest {
        let result = try manifest(at: root)
        for file in result.files { _ = try checkedFile(file, root: root) }
        return result
    }
    static func install(payload: URL, parent: URL) throws -> URL {
        let kit = try verify(payload)
        try fm.createDirectory(at: parent, withIntermediateDirectories: true)
        let parent = parent.resolvingSymlinksInPath()
        let destination = parent.appendingPathComponent(kit.version, isDirectory: true)
        if fm.fileExists(atPath: destination.path) {
            let attrs = try fm.attributesOfItem(atPath: destination.path)
            guard attrs[.type] as? FileAttributeType == .typeDirectory,
                  try Data(contentsOf: destination.appendingPathComponent("kit.json")) == Data(contentsOf: payload.appendingPathComponent("kit.json")) else {
                throw SetupFailure("This version's destination already contains different files. Choose another folder; your files have not been replaced.")
            }
            _ = try verify(destination)
            return destination
        }
        let disk = try fm.attributesOfFileSystem(forPath: parent.path)
        if let free = (disk[.systemFreeSize] as? NSNumber)?.int64Value, free < Int64(kit.totalBytes) + 16_777_216 {
            throw SetupFailure("There is not enough free space in this location. Choose another folder.")
        }
        let staging = parent.appendingPathComponent(".gdk-install-" + UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: staging, withIntermediateDirectories: false)
        defer { try? fm.removeItem(at: staging) }
        for file in kit.files {
            let source = try checkedFile(file, root: payload)
            let target = staging.appendingPathComponent(file.path)
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: source, to: target)
            try fm.setAttributes([.posixPermissions: file.executable ? 0o755 : 0o644], ofItemAtPath: target.path)
        }
        try fm.copyItem(at: payload.appendingPathComponent("kit.json"), to: staging.appendingPathComponent("kit.json"))
        _ = try verify(staging)
        // Same-filesystem rename activates only a fully verified installation. Never overwrite.
        try fm.moveItem(at: staging, to: destination)
        return destination
    }
    static func environment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        for key in ["COUCH_LIBRARY_SESSION", "COUCH_WII_NATIVE_STATE", "COUCH_WII_FLEET_DIR"] { env.removeValue(forKey: key) }
        return env
    }
    static func run(_ executable: URL, _ arguments: [String], timeout: TimeInterval = 120) throws -> CommandResult {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment()
        process.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        try process.run()
        // Drain output while the child runs; never block a child on a full pipe.
        let output = OutputCapture()
        let readDone = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            while true {
                let chunk = pipe.fileHandleForReading.availableData
                if chunk.isEmpty { break }
                output.append(chunk)
            }
            readDone.signal()
        }
        let timedOut = finished.wait(timeout: .now() + timeout) == .timedOut
        if timedOut {
            process.terminate()
            if finished.wait(timeout: .now() + 2) == .timedOut { kill(process.processIdentifier, SIGKILL); process.waitUntilExit() }
        }
        _ = readDone.wait(timeout: .now() + 2)
        if timedOut { throw SetupFailure("The operation timed out. Open Godot once to complete any macOS approval, then try again.") }
        return CommandResult(status: process.terminationStatus, output: output.snapshot())
    }
    static func doctor(tool: URL, godot: String?) throws -> [String: Any] {
        var args = ["--json"]
        if let godot { args += ["--godot", godot] }
        args += ["doctor", "--require-godot"]
        let result = try run(tool, args)
        guard let response = try JSONSerialization.jsonObject(with: result.output) as? [String: Any],
              let data = response["data"] as? [String: Any], let report = data["godot"] as? [String: Any] else {
            throw SetupFailure("The setup check could not finish. \(String(data: result.output, encoding: .utf8) ?? "")")
        }
        return report
    }
}
