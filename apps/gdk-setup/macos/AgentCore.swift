import Foundation

struct AgentProvider {
    let id: String
    let name: String
    let commands: [String]
    let installURL: String
    let shell: String
    let docsURL: String
    let startCommand: String
}
struct AgentDetection {
    let provider: AgentProvider
    let executable: URL?
    let version: String?
    var found: Bool { executable != nil }
}

// Vendor commands are fixed catalog entries, never interpolated user input.
enum AgentCore {
    static let providers: [AgentProvider] = [
        AgentProvider(id: "codex", name: "Codex", commands: ["codex"], installURL: "https://chatgpt.com/codex/install.sh", shell: "/bin/sh", docsURL: "https://developers.openai.com/codex/cli/", startCommand: "codex"),
        AgentProvider(id: "claude", name: "Claude Code", commands: ["claude"], installURL: "https://claude.ai/install.sh", shell: "/bin/bash", docsURL: "https://code.claude.com/docs/en/setup", startCommand: "claude"),
        AgentProvider(id: "grok", name: "Grok", commands: ["grok"], installURL: "https://x.ai/cli/install.sh", shell: "/bin/bash", docsURL: "https://docs.x.ai/build/overview", startCommand: "grok"),
        AgentProvider(id: "kiro", name: "Kiro", commands: ["kiro-cli"], installURL: "https://cli.kiro.dev/install", shell: "/bin/bash", docsURL: "https://kiro.dev/docs/getting-started/installation/", startCommand: "kiro-cli"),
        AgentProvider(id: "cursor", name: "Cursor", commands: ["cursor-agent", "agent"], installURL: "https://cursor.com/install", shell: "/bin/bash", docsURL: "https://cursor.com/docs/cli/installation", startCommand: "agent")
    ]
    static func searchDirectories(home: URL = FileManager.default.homeDirectoryForCurrentUser, path: String = ProcessInfo.processInfo.environment["PATH"] ?? "") -> [URL] {
        var paths = [".local/bin", ".grok/bin", ".cursor/bin", ".kiro/bin", ".npm-global/bin", ".bun/bin"].map { home.appendingPathComponent($0) }
        paths += path.split(separator: ":").filter { $0.hasPrefix("/") }.map { URL(fileURLWithPath: String($0)) }
        paths += ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"].map { URL(fileURLWithPath: $0) }
        let nvm = home.appendingPathComponent(".nvm/versions/node")
        paths += ((try? FileManager.default.contentsOfDirectory(at: nvm, includingPropertiesForKeys: nil)) ?? []).sorted { $0.path > $1.path }.map { $0.appendingPathComponent("bin") }
        var seen = Set<String>()
        return paths.filter { seen.insert($0.path).inserted }
    }
    static func detect(_ provider: AgentProvider, directories: [URL]? = nil) -> AgentDetection {
        for directory in directories ?? searchDirectories() {
            for command in provider.commands {
                let url = directory.appendingPathComponent(command)
                guard FileManager.default.isExecutableFile(atPath: url.path) else { continue }
                // Both Grok and Cursor expose `agent`; a filename alone is not identity.
                if provider.id == "cursor" && command == "agent" {
                    let resolved = url.resolvingSymlinksInPath().path.lowercased()
                    if resolved.contains("grok") { continue }
                    if !resolved.contains("cursor") {
                        guard let help = try? SetupCore.run(url, ["--help"], timeout: 5), help.status == 0,
                              String(data: help.output, encoding: .utf8)?.localizedCaseInsensitiveContains("cursor") == true else { continue }
                    }
                }
                guard let result = try? SetupCore.run(url, ["--version"], timeout: 5), result.status == 0,
                      let raw = String(data: result.output, encoding: .utf8),
                      raw.range(of: #"[0-9]+\.[0-9]+"#, options: .regularExpression) != nil else { continue }
                let version = raw.split(separator: "\n").first.map(String.init) ?? "CLI detected"
                return AgentDetection(provider: provider, executable: url, version: String(version.prefix(100)))
            }
        }
        return AgentDetection(provider: provider, executable: nil, version: nil)
    }
    static func detectAll() -> [AgentDetection] {
        let directories = searchDirectories()
        return providers.map { detect($0, directories: directories) }
    }
    typealias Runner = (URL, [String], TimeInterval) throws -> CommandResult
    static func install(_ provider: AgentProvider, runner: Runner = { try SetupCore.run($0, $1, timeout: $2) }) throws {
        guard providers.contains(where: { $0.id == provider.id && $0.installURL == provider.installURL && $0.shell == provider.shell }) else {
            throw SetupFailure("This agent installer is not in the supported catalog.")
        }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("couch-agent-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let script = temporary.appendingPathComponent("install.sh")
        let downloaded = try runner(URL(fileURLWithPath: "/usr/bin/curl"), ["--fail", "--silent", "--show-error", "--location", "--proto", "=https", "--proto-redir", "=https", "--connect-timeout", "15", "--max-time", "60", "--max-filesize", "2097152", "--output", script.path, provider.installURL], 70)
        guard downloaded.status == 0, let attrs = try? FileManager.default.attributesOfItem(atPath: script.path),
              let size = attrs[.size] as? NSNumber, size.intValue > 0, size.intValue <= 2_097_152 else {
            throw SetupFailure("Could not download the official installer. Check your connection or open the installation guide.")
        }
        let result = try runner(URL(fileURLWithPath: provider.shell), [script.path], 300)
        guard result.status == 0 else { throw SetupFailure("The vendor installer did not finish (exit \(result.status)). Open the installation guide to troubleshoot, then check again.") }
    }
}
