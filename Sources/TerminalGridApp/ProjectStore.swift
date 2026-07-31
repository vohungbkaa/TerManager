import Foundation
import Combine
import SwiftTerm

final class ProjectStore: ObservableObject {
    @Published var projects: [Project] = []
    @Published var selectedEntityID: String?     // project.id OR subproject.id
    /// Per-entity automatic grid layout. Missing = 1×1.
    @Published var grids: [String: GridSize] = [:]
    /// pane slots keyed by entity id (project or subproject). Flat array row-major.
    @Published var panes: [String: [PaneSlot?]] = [:]

    func grid(for entityID: String) -> GridSize {
        grids[entityID] ?? GridSize()
    }

    static func automaticGrid(for terminalCount: Int) -> GridSize {
        switch terminalCount {
        case ...1: return GridSize(rows: 1, cols: 1)
        case 2: return GridSize(rows: 1, cols: 2)
        case 3, 4: return GridSize(rows: 2, cols: 2)
        case 5, 6: return GridSize(rows: 2, cols: 3)
        default: return GridSize(rows: 3, cols: 3)
        }
    }

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

    init(persistenceURL: URL? = nil) {
        if let persistenceURL {
            fileURL = persistenceURL
        } else {
            let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = support.appendingPathComponent("TerminalGrid", isDirectory: true)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            fileURL = dir.appendingPathComponent("terminal-grid.json")
        }
        load()
    }

    // ── Persist ──

    struct PersistPayload: Codable {
        var projects: [Project]
        var grids: [String: GridSize]
        var panes: [String: [PaneSlot?]]
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        guard let payload = try? JSONDecoder().decode(PersistPayload.self, from: data) else { return }
        projects = payload.projects.map { proj in
            var p = proj
            p.projectType = ProjectTypeDetector.detect(at: URL(fileURLWithPath: p.path))
            p.subProjects = p.subProjects.map { sub in
                var s = sub
                s.path = p.path
                return s
            }
            return p
        }
        grids = payload.grids
        panes = payload.panes
        normalizePersistedLayouts()
        selectedEntityID = projects.first?.id.uuidString
    }

    func save() {
        let payload = PersistPayload(projects: projects, grids: grids, panes: panes)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // ── Projects ──

    func addProject(folderURL: URL) {
        let name = folderURL.lastPathComponent
        let project = Project(
            name: name,
            path: folderURL.path,
            shellPath: Self.defaultShell,
            projectType: ProjectTypeDetector.detect(at: folderURL)
        )
        projects.append(project)
        grids[project.id.uuidString] = GridSize(rows: 1, cols: 1)
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
        grids.removeValue(forKey: id)

        if let project = projects.first(where: { $0.id.uuidString == id }) {
            if let oldPath = project.customIconPath {
                try? fm.removeItem(atPath: oldPath)
            }
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
                grids.removeValue(forKey: subID)
            }
        }
        
        projects.removeAll { $0.id.uuidString == id }
        if selectedEntityID == id { selectedEntityID = projects.first?.id.uuidString }
        save()
    }

    // ── Project Icon Management ──

    func setIcon(url: URL, for projectID: String) {
        guard let idx = projects.firstIndex(where: { $0.id.uuidString == projectID }) else { return }
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let iconsDir = support.appendingPathComponent("TerminalGrid", isDirectory: true)
                              .appendingPathComponent("icons", isDirectory: true)
        try? fm.createDirectory(at: iconsDir, withIntermediateDirectories: true)

        let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension
        let filename = "\(projectID)-\(UUID().uuidString.prefix(6)).\(ext)"
        let destURL = iconsDir.appendingPathComponent(filename)

        if let oldPath = projects[idx].customIconPath {
            try? fm.removeItem(atPath: oldPath)
        }

        do {
            try fm.copyItem(at: url, to: destURL)
            projects[idx].customIconPath = destURL.path
            save()
        } catch {
            print("Failed to save custom icon: \(error)")
        }
    }

    func removeIcon(for projectID: String) {
        guard let idx = projects.firstIndex(where: { $0.id.uuidString == projectID }) else { return }
        if let oldPath = projects[idx].customIconPath {
            try? fm.removeItem(atPath: oldPath)
        }
        projects[idx].customIconPath = nil
        save()
    }

    func hiddenPanesCount(for entityID: String) -> Int {
        panePartition(for: entityID).hidden.count
    }

    func restoreAllHiddenPanes(for entityID: String) {
        let partition = panePartition(for: entityID)
        let restored = partition.visible + partition.hidden
        guard !partition.hidden.isEmpty, restored.count <= 9 else { return }

        let targetGrid = Self.automaticGrid(for: restored.count)
        let targetSize = targetGrid.rows * targetGrid.cols
        var normalized: [PaneSlot?] = restored.map(Optional.some)
        while normalized.count < targetSize { normalized.append(nil) }

        grids[entityID] = targetGrid
        panes[entityID] = normalized
        save()
    }

    func hidePane(entityID: String, index: Int) {
        let partition = panePartition(for: entityID)
        var visible = partition.visible
        var hidden = partition.hidden
        guard index < visible.count else { return }

        hidden.insert(visible.remove(at: index), at: 0)
        let targetGrid = Self.automaticGrid(for: visible.count)
        let targetSize = targetGrid.rows * targetGrid.cols
        var normalized: [PaneSlot?] = visible.map(Optional.some)
        while normalized.count < targetSize { normalized.append(nil) }
        normalized.append(contentsOf: hidden.map(Optional.some))

        grids[entityID] = targetGrid
        panes[entityID] = normalized
        save()
    }

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
            grids[sub.id.uuidString] = GridSize(rows: 1, cols: 1)
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
                grids[sub.id.uuidString] = GridSize(rows: 1, cols: 1)
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

    func addNextTask(to projectID: String) {
        guard let idx = projects.firstIndex(where: { $0.id.uuidString == projectID }) else { return }
        let project = projects[idx]
        
        var number = 1
        let existingNames = Set(project.subProjects.map { $0.name.lowercased() })
        while existingNames.contains("task \(number)") {
            number += 1
        }
        
        let newName = "Task \(number)"
        let sub = SubProject(name: newName, path: project.path)
        grids[sub.id.uuidString] = GridSize(rows: 1, cols: 1)
        projects[idx].subProjects.append(sub)
        selectedEntityID = sub.id.uuidString
        save()
        
        let _ = spawnPane(entityID: sub.id.uuidString, cwd: project.path)
    }

    func renameSubProject(in projectID: String, subProjectID: String, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let pIdx = projects.firstIndex(where: { $0.id.uuidString == projectID }) else { return }
        guard let sIdx = projects[pIdx].subProjects.firstIndex(where: { $0.id.uuidString == subProjectID }) else { return }
        
        projects[pIdx].subProjects[sIdx].name = trimmed
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
        grids.removeValue(forKey: subProjectID)
        if selectedEntityID == subProjectID { selectedEntityID = projectID }
        save()
    }

    // ── Panes ──

    func slots(for entityID: String) -> [PaneSlot?] {
        let size = grid(for: entityID).rows * grid(for: entityID).cols
        let existing = panes[entityID] ?? []
        if existing.count == size { return existing }
        var resized = Array<PaneSlot?>(repeating: nil, count: size)
        for (i, slot) in existing.enumerated() where i < size { resized[i] = slot }
        return resized
    }

    func spawnPane(entityID: String, cwd: String) -> Int? {
        let partition = panePartition(for: entityID)
        var visiblePanes = partition.visible
        let hiddenPanes = partition.hidden
        guard visiblePanes.count + hiddenPanes.count < 9 else { return nil }

        let targetGrid = Self.automaticGrid(for: visiblePanes.count + 1)
        let targetSize = targetGrid.rows * targetGrid.cols
        let idx = visiblePanes.count
        let slot = PaneSlot(cwd: cwd)
        visiblePanes.append(slot)

        var current: [PaneSlot?] = visiblePanes.map(Optional.some)
        while current.count < targetSize { current.append(nil) }
        current.append(contentsOf: hiddenPanes.map(Optional.some))

        grids[entityID] = targetGrid
        panes[entityID] = current
        save()
        return idx
    }

    func killPane(entityID: String, index: Int) {
        let partition = panePartition(for: entityID)
        var visiblePanes = partition.visible
        let hiddenPanes = partition.hidden
        guard index < visiblePanes.count else { return }

        let slot = visiblePanes.remove(at: index)
        if let view = terminalViewCache.removeValue(forKey: slot.paneId) {
            view.terminate()
        }

        let targetGrid = Self.automaticGrid(for: visiblePanes.count)
        let targetSize = targetGrid.rows * targetGrid.cols
        var normalized: [PaneSlot?] = visiblePanes.map(Optional.some)
        while normalized.count < targetSize { normalized.append(nil) }
        normalized.append(contentsOf: hiddenPanes.map(Optional.some))
        grids[entityID] = targetGrid
        panes[entityID] = normalized
        save()
    }

    private func panePartition(for entityID: String) -> (visible: [PaneSlot], hidden: [PaneSlot]) {
        let allSlots = panes[entityID] ?? []
        let visibleSize = grid(for: entityID).rows * grid(for: entityID).cols
        let visible = allSlots.prefix(visibleSize).compactMap { $0 }
        let hidden = allSlots.dropFirst(min(visibleSize, allSlots.count)).compactMap { $0 }
        return (visible, hidden)
    }

    private func normalizePersistedLayouts() {
        for entityID in Array(panes.keys) {
            let storedSlots = panes[entityID] ?? []
            let oldGrid = grids[entityID] ?? GridSize()
            let oldVisibleSize = oldGrid.rows * oldGrid.cols
            let visible = storedSlots.prefix(oldVisibleSize).compactMap { $0 }
            let hidden = storedSlots.dropFirst(min(oldVisibleSize, storedSlots.count)).compactMap { $0 }
            let targetGrid = Self.automaticGrid(for: visible.count)
            let targetSize = targetGrid.rows * targetGrid.cols

            var normalized: [PaneSlot?] = visible.map(Optional.some)
            while normalized.count < targetSize { normalized.append(nil) }
            normalized.append(contentsOf: hidden.map(Optional.some))

            grids[entityID] = targetGrid
            panes[entityID] = normalized
        }
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

    func project(for entityID: String) -> Project? {
        projects.first { project in
            project.id.uuidString == entityID
                || project.subProjects.contains { $0.id.uuidString == entityID }
        }
    }

    func terminalTargetEntityID(for projectID: String) -> String {
        guard let selectedEntityID,
              let project = projects.first(where: { $0.id.uuidString == projectID }),
              project.subProjects.contains(where: { $0.id.uuidString == selectedEntityID }) else {
            return projectID
        }
        return selectedEntityID
    }
}
