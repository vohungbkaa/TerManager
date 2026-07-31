import Foundation

struct SubProject: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var path: String

    init(id: UUID = UUID(), name: String, path: String) {
        self.id = id
        self.name = name
        self.path = path
    }
}

struct Project: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var path: String
    var shellPath: String
    var subProjects: [SubProject]
    var customIconPath: String?
    var projectType: ProjectType

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        shellPath: String = "/bin/zsh",
        subProjects: [SubProject] = [],
        customIconPath: String? = nil,
        projectType: ProjectType = .unknown
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.shellPath = shellPath
        self.subProjects = subProjects
        self.customIconPath = customIconPath
        self.projectType = projectType
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, path, shellPath, subProjects, customIconPath, projectType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        shellPath = try container.decodeIfPresent(String.self, forKey: .shellPath) ?? "/bin/zsh"
        subProjects = try container.decodeIfPresent([SubProject].self, forKey: .subProjects) ?? []
        customIconPath = try container.decodeIfPresent(String.self, forKey: .customIconPath)
        projectType = try container.decodeIfPresent(ProjectType.self, forKey: .projectType) ?? .unknown
    }
}

struct GridSize: Codable, Equatable {
    var rows: Int
    var cols: Int

    init(rows: Int = 1, cols: Int = 1) {
        self.rows = min(3, max(1, rows))
        self.cols = min(3, max(1, cols))
    }
}

struct PaneSlot: Codable, Identifiable, Hashable {
    let id: UUID
    var paneId: String
    var cwd: String
    var customName: String?
    var startupCommand: String?

    init(
        id: UUID = UUID(),
        paneId: String = UUID().uuidString,
        cwd: String,
        customName: String? = nil,
        startupCommand: String? = nil
    ) {
        self.id = id
        self.paneId = paneId
        self.cwd = cwd
        self.customName = customName
        self.startupCommand = startupCommand
    }

    /// nil = empty slot
    static func fromOptional(_ slot: PaneSlot?) -> Self? { slot }
}
