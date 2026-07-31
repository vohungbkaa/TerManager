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

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        shellPath: String = "/bin/zsh",
        subProjects: [SubProject] = [],
        customIconPath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.shellPath = shellPath
        self.subProjects = subProjects
        self.customIconPath = customIconPath
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

    init(id: UUID = UUID(), paneId: String = UUID().uuidString, cwd: String) {
        self.id = id
        self.paneId = paneId
        self.cwd = cwd
    }

    /// nil = empty slot
    static func fromOptional(_ slot: PaneSlot?) -> Self? { slot }
}
