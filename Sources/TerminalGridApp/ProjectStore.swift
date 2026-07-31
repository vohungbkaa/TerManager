import Foundation
import Combine
import SwiftTerm

final class ProjectStore: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedEntityID: String?     // project.id OR subproject.id
    @Published var grid = GridSize()
    /// pane slots keyed by entity id (project or subproject). Flat array row-major.
    @Published var panes: [String: [PaneSlot?]] = [:]

    private let fileURL: URL
    
    // Cache for terminal views to persist state across tabs/views
    private var terminalViewCache: [String: LocalProcessTerminalView] = [:]
    
    func getTerminalView(for paneId: String) -> LocalProcessTerminalView? {
        return terminalViewCache[paneId]
    }

    func cacheTerminalView(_ view: LocalProcessTerminalView, for paneId: String) {
        terminalViewCache[paneId] = view
    }
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
        projects = payload.projects.map { proj in
            var p = proj
            p.subProjects = p.subProjects.map { sub in
                var s = sub
                s.path = p.path
                return s
            }
            return p
        }
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
        // First delete project's panes
        if let slots = panes[id] {
            for slot in slots {
                if let s = slot, let view = terminalViewCache.removeValue(forKey: s.paneId) {
                    view.terminate()
                }
            }
        }
        panes.removeValue(forKey: id)
        
        // Find the project and delete all subprojects' panes too
        if let project = projects.first(where: { $0.id.uuidString == id }) {
            for sub in project.subProjects {
                let subID = sub.id.uuidString
                if let slots = panes[subID] {
                    for slot in slots {
                        if let s = slot, let view = terminalViewCache.removeValue(forKey: s.paneId) {
                            view.terminate()
                        }
                    }
                }
                panes.removeValue(forKey: subID)
            }
        }
        
        projects.removeAll { $0.id.uuidString == id }
        if selectedEntityID == id { selectedEntityID = projects.first?.id.uuidString }
        save()
    }

    func updateGrid(_ rows: Int, _ cols: Int) {
        grid = GridSize(rows: rows, cols: cols)
        save()
    }

    // Hidden slots (beyond current grid size) stay alive in panes[entityID] so
    // switching back to a larger layout restores their terminal state. Only the
    // per-pane close button terminates a process.

    // ── SubProjects ──

    /// Automatically select the first child if available, otherwise fallback to parent project ID.
    func selectDefaultEntity(for projectID: String) {
        guard let p = projects.first(where: { $0.id.uuidString == projectID }) else {
            selectedEntityID = projectID
            return
        }
        if let firstSub = p.subProjects.first {
            selectedEntityID = firstSub.id.uuidString
        } else {
            selectedEntityID = projectID
        }
    }

    func addSubProjects(to projectID: String, names: [String]) {
        guard let idx = projects.firstIndex(where: { $0.id.uuidString == projectID }) else { return }
        let project = projects[idx]
        for name in names {
            let sub = SubProject(name: name, path: project.path)
            projects[idx].subProjects.append(sub)
        }
        if let firstSub = projects[idx].subProjects.first {
            selectedEntityID = firstSub.id.uuidString
        }
        save()
    }

    func setSubProjects(for projectID: String, names: [String]) {
        guard let idx = projects.firstIndex(where: { $0.id.uuidString == projectID }) else { return }
        let project = projects[idx]
        
        var newSubs: [SubProject] = []
        for name in names {
            if let existing = project.subProjects.first(where: { $0.name == name }) {
                var updated = existing
                updated.path = project.path
                newSubs.append(updated)
            } else {
                let sub = SubProject(name: name, path: project.path)
                newSubs.append(sub)
            }
        }
        
        projects[idx].subProjects = newSubs
        if let firstSub = projects[idx].subProjects.first {
            selectedEntityID = firstSub.id.uuidString
        } else {
            selectedEntityID = projectID
        }
        save()
    }

    func deleteSubProject(from projectID: String, subProjectID: String) {
        guard let idx = projects.firstIndex(where: { $0.id.uuidString == projectID }) else { return }
        projects[idx].subProjects.removeAll { $0.id.uuidString == subProjectID }
        
        if let slots = panes[subProjectID] {
            for slot in slots {
                if let s = slot, let view = terminalViewCache.removeValue(forKey: s.paneId) {
                    view.terminate()
                }
            }
        }
        
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
        var current = panes[entityID] ?? []
        // Pad short arrays up to grid size; never truncate longer ones —
        // hidden slots beyond `size` stay alive for layout switches.
        if current.count < size {
            current.append(contentsOf: Array(repeating: nil, count: size - current.count))
        }
        panes[entityID] = current
        guard let idx = current.firstIndex(where: { $0 == nil }) else { return nil }
        if idx >= size { return nil }
        let slot = PaneSlot(cwd: cwd)
        current[idx] = slot
        panes[entityID] = current
        save()
        return idx
    }

    func killPane(entityID: String, index: Int) {
        guard var current = panes[entityID], index < current.count else { return }
        if let slot = current[index] {
            if let view = terminalViewCache.removeValue(forKey: slot.paneId) {
                view.terminate()
            }
        }
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
