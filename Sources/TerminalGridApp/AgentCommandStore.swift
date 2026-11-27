import Foundation
import SwiftUI

struct AgentCommandPreset: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var command: String

    init(id: UUID = UUID(), title: String, command: String) {
        self.id = id
        self.title = title
        self.command = command
    }
}

struct AgentCommandGroup: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var agentName: String
    var shortTag: String
    var icon: String
    var colorHex: UInt32
    var commands: [AgentCommandPreset]

    init(
        id: UUID = UUID(),
        agentName: String,
        shortTag: String,
        icon: String = "terminal",
        colorHex: UInt32 = 0x5E9BFF,
        commands: [AgentCommandPreset] = []
    ) {
        self.id = id
        self.agentName = agentName
        self.shortTag = shortTag
        self.icon = icon
        self.colorHex = colorHex
        self.commands = commands
    }
}

// MARK: - Drag Payload Codec

struct DraggedAgentCommand: Codable {
    let title: String
    let command: String
}

enum AgentCommandDragCodec {
    static let prefix = "TERMANAGER_CMD::"

    static func encode(title: String, command: String) -> String {
        let payload = DraggedAgentCommand(title: title, command: command)
        guard let data = try? JSONEncoder().encode(payload),
              let json = String(data: data, encoding: .utf8) else {
            return prefix + command
        }
        return prefix + json
    }

    static func decode(_ raw: String) -> DraggedAgentCommand? {
        guard raw.hasPrefix(prefix) else { return nil }
        let body = String(raw.dropFirst(prefix.count))
        if let data = body.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(DraggedAgentCommand.self, from: data) {
            return decoded
        }
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return DraggedAgentCommand(title: trimmed, command: trimmed)
    }

    static func itemProvider(title: String, command: String) -> NSItemProvider {
        let encoded = encode(title: title, command: command)
        return NSItemProvider(object: encoded as NSString)
    }
}

// MARK: - Store

final class AgentCommandStore: ObservableObject {
    private static let storageKey = "termanager.agentCommandGroups.v1"

    @Published var groups: [AgentCommandGroup] = []

    init() {
        load()
    }

    static var defaultGroups: [AgentCommandGroup] {
        [
            AgentCommandGroup(
                agentName: "Antigravity",
                shortTag: "agy",
                icon: "bolt.fill",
                colorHex: 0x5E9BFF,
                commands: [
                    AgentCommandPreset(title: "Default", command: "agy"),
                    AgentCommandPreset(title: "Skip permissions", command: "agy --dangerously-skip-permissions")
                ]
            ),
            AgentCommandGroup(
                agentName: "Codex",
                shortTag: "codex",
                icon: "cpu",
                colorHex: 0x38BDF8,
                commands: [
                    AgentCommandPreset(title: "Default", command: "codex"),
                    AgentCommandPreset(title: "Bypass approvals", command: "codex --dangerously-bypass-approvals-and-sandbox")
                ]
            ),
            AgentCommandGroup(
                agentName: "Claude Code",
                shortTag: "claude",
                icon: "sparkles",
                colorHex: 0xE59853,
                commands: [
                    AgentCommandPreset(title: "Default", command: "claude"),
                    AgentCommandPreset(title: "Skip permissions", command: "claude --dangerously-skip-permissions")
                ]
            )
        ]
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([AgentCommandGroup].self, from: data),
           !decoded.isEmpty {
            groups = decoded
        } else {
            groups = Self.defaultGroups
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(groups) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    func addCommand(to groupID: UUID, title: String, command: String) {
        let cleanCmd = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanCmd.isEmpty else { return }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? cleanCmd
            : title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let idx = groups.firstIndex(where: { $0.id == groupID }) else { return }
        groups[idx].commands.append(AgentCommandPreset(title: cleanTitle, command: cleanCmd))
        save()
    }

    @discardableResult
    func addAgentGroup(name: String, shortTag: String? = nil, firstCommandTitle: String? = nil, firstCommand: String? = nil) -> UUID? {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return nil }

        if let existing = groups.first(where: { $0.agentName.lowercased() == cleanName.lowercased() || $0.shortTag.lowercased() == cleanName.lowercased() }) {
            if let cmd = firstCommand?.trimmingCharacters(in: .whitespacesAndNewlines), !cmd.isEmpty {
                addCommand(to: existing.id, title: firstCommandTitle ?? cmd, command: cmd)
            }
            return existing.id
        }

        let tag = (shortTag?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? cleanName.lowercased().replacingOccurrences(of: " ", with: "-")
        var initialCommands: [AgentCommandPreset] = []
        if let cmd = firstCommand?.trimmingCharacters(in: .whitespacesAndNewlines), !cmd.isEmpty {
            let label = (firstCommandTitle?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Default"
            initialCommands.append(AgentCommandPreset(title: label, command: cmd))
        }

        let palette: [UInt32] = [0x34D399, 0xA78BFA, 0xF472B6, 0xFBBF24, 0x38BDF8]
        let colorHex = palette[groups.count % palette.count]
        let newGroup = AgentCommandGroup(
            agentName: cleanName,
            shortTag: tag,
            icon: "terminal.fill",
            colorHex: colorHex,
            commands: initialCommands
        )
        groups.append(newGroup)
        save()
        return newGroup.id
    }

    func deleteCommand(in groupID: UUID, commandID: UUID) {
        guard let idx = groups.firstIndex(where: { $0.id == groupID }) else { return }
        groups[idx].commands.removeAll { $0.id == commandID }
        save()
    }

    func deleteGroup(_ groupID: UUID) {
        groups.removeAll { $0.id == groupID }
        if groups.isEmpty {
            groups = Self.defaultGroups
        }
        save()
    }

    func resetDefaults() {
        groups = Self.defaultGroups
        save()
    }
}
