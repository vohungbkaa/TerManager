import Foundation
import Combine

final class ProjectStore: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedEntityID: String?     // project.id OR subproject.id
    @Published var grid = GridSize()
    /// pane slots keyed by entity id (project or subproject). Flat array row-major.
    @Published var panes: [String: [PaneSlot?]] = [:]

    private let fileURL: URL
    private let fm = FileManager.default

    // default shell from env, fallback /bin/zsh
    static let defaultShell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"

    init() {
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("TerminalGrid", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("terminal-grid.json")
        load()
    }

    // ── Persist ──

    struct PersistPayload: Codable {
        var projects: [Project]
        var grid: GridSize
        var panes: [String: [PaneSlot?]]
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        guard let payload = try? JSONDecoder().decode(PersistPayload.self, from: data) else { return }
        projects = payload.projects
        grid = payload.grid
        panes = payload.panes
        selectedEntityID = projects.first?.id.uuidString
    }

    func save() {
        let payload = PersistPayload(projects: projects, grid: grid, panes: panes)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // ── Projects ──

    func addProject(folderURL: URL) {
        let name = folderURL.lastPathComponent
        let project = Project(name: name, path: folderURL.path, shellPath: Self.defaultShell)
        projects.append(project)
        selectedEntityID = project.id.uuidString
        save()
    }

    func deleteProject(id: String) {
        projects.removeAll { $0.id.uuidString == id }
        if selectedEntityID == id { selectedEntityID = projects.first?.id.uuidString }
        save()
    }

    func updateGrid(_ rows: Int, _ cols: Int) {
        grid = GridSize(rows: rows, cols: cols)
        rescueExcessPanes()
        save()
    }

    /// Shrink removes panes beyond new size — per entity.
    private func rescueExcessPanes() {
        let maxSlots = grid.rows * grid.cols
        for key in panes.keys {
            var slots = panes[key] ?? []
            if slots.count > maxSlots { slots.removeLast(slots.count - maxSlots) }
            panes[key] = slots
        }
    }

    // ── SubProjects ──

    func addSubProjects(to projectID: String, names: [String]) {
        guard let idx = projects.firstIndex(where: { $0.id.uuidString == projectID }) else { return }
        let project = projects[idx]
        for name in names {
            let subPath = project.path + "/" + name
            try? fm.createDirectory(atPath: subPath, withIntermediateDirectories: true, attributes: nil)
            let sub = SubProject(name: name, path: subPath)
            projects[idx].subProjects.append(sub)
        }
        save()
    }

    func deleteSubProject(from projectID: String, subProjectID: String) {
        guard let idx = projects.firstIndex(where: { $0.id.uuidString == projectID }) else { return }
        projects[idx].subProjects.removeAll { $0.id.uuidString == subProjectID }
        panes.removeValue(forKey: subProjectID)
        if selectedEntityID == subProjectID { selectedEntityID = projectID }
        save()
    }

    // ── Panes ──

    func slots(for entityID: String) -> [PaneSlot?] {
        let size = grid.rows * grid.cols
        let existing = panes[entityID] ?? []
        if existing.count == size { return existing }
        var resized = Array<PaneSlot?>(repeating: nil, count: size)
        for (i, slot) in existing.enumerated() where i < size { resized[i] = slot }
        return resized
    }

    func spawnPane(entityID: String, cwd: String) -> Int? {
        let size = grid.rows * grid.cols
        var current = panes[entityID] ?? Array(repeating: nil, count: size)
        if current.count != size {
            var resized = Array<PaneSlot?>(repeating: nil, count: size)
            for (i, s) in current.enumerated() where i < size { resized[i] = s }
            current = resized
        }
        guard let idx = current.firstIndex(where: { $0 == nil }) else { return nil }
        let slot = PaneSlot(cwd: cwd)
        current[idx] = slot
        panes[entityID] = current
        save()
        return idx
    }

    func killPane(entityID: String, index: Int) {
        guard var current = panes[entityID], index < current.count else { return }
        current[index] = nil
        panes[entityID] = current
        save()
    }

    // ── CWD resolver ──

    func cwd(for entityID: String) -> String? {
        for p in projects {
            if p.id.uuidString == entityID { return p.path }
            if let sub = p.subProjects.first(where: { $0.id.uuidString == entityID }) {
                return sub.path
            }
        }
        return nil
    }
}
