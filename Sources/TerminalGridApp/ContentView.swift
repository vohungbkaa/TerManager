import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var showingSubSheet = false

    var body: some View {
        HSplitView {
            // Sidebar
            ProjectSidebar(onSpawnPane: handleSpawnPane)
                .frame(minWidth: 220, idealWidth: 260)
                .frame(maxHeight: .infinity)

            // Main terminal area
            terminalArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 900, minHeight: 560)
    }

    // ── Terminal grid ──

    @ViewBuilder
    private var terminalArea: some View {
        if store.projects.isEmpty {
            emptyState
        } else if let entityID = store.selectedEntityID {
            VStack(spacing: 0) {
                toolbar(for: entityID)
                paneGrid(entityID: entityID)
            }
        } else {
            noSelection
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Chưa có dự án").font(.title2.weight(.medium))
            Text("Thêm thư mục dự án từ thanh bên để bắt đầu mở terminal.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noSelection: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Chọn một dự án").font(.title2.weight(.medium))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // ── Toolbar ──

    private func toolbar(for entityID: String) -> some View {
        HStack(spacing: 6) {
            breadcrumbs(for: entityID)
            Spacer()
            GridSizePicker(grid: $store.grid)
                .onChange(of: store.grid) { _ in
                    store.updateGrid(store.grid.rows, store.grid.cols)
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    @ViewBuilder
    private func breadcrumbs(for entityID: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "folder")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if let project = store.projects.first(where: { $0.id.uuidString == entityID }) {
                Text(project.name)
                    .font(.system(size: 12, weight: .semibold))
                Text("/")
                    .foregroundStyle(.tertiary)
                Text(project.path)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                subBreadcrumbs(for: entityID)
            }
        }
    }

    @ViewBuilder
    private func subBreadcrumbs(for entityID: String) -> some View {
        Group {
            let _ = ()
            ForEach(Array(store.projects.enumerated()), id: \.element.id) { _, p in
                if let sub = p.subProjects.first(where: { $0.id.uuidString == entityID }) {
                    Text(p.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("/")
                        .foregroundStyle(.tertiary)
                    Text(sub.name)
                        .font(.system(size: 12, weight: .semibold))
                    Text("/")
                        .foregroundStyle(.tertiary)
                    Text(sub.path)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }

    // ── Pane grid ──

    private func paneGrid(entityID: String) -> some View {
        let slots = store.slots(for: entityID)
        return Grid(horizontalSpacing: 1, verticalSpacing: 1) {
            ForEach(0..<store.grid.rows, id: \.self) { row in
                GridRow {
                    ForEach(0..<store.grid.cols, id: \.self) { col in
                        let index = row * store.grid.cols + col
                        if index < slots.count, let slot = slots[index] {
                            paneCell(slot: slot, index: index, entityID: entityID)
                        } else {
                            emptyCell(entityID: entityID, index: index)
                        }
                    }
                }
            }
        }
    }

    private func paneCell(slot: PaneSlot, index: Int, entityID: String) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 4) {
                Image(systemName: "terminal")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text(folderName(slot.cwd))
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Button {
                    store.killPane(entityID: entityID, index: index)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.bar)

            TerminalPane(paneId: slot.paneId, cwd: slot.cwd, shellPath: shellFor(entityID: entityID))
        }
        .background(Color(.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func emptyCell(entityID: String, index: Int) -> some View {
        Button {
            if let cwd = store.cwd(for: entityID) {
                let _ = store.spawnPane(entityID: entityID, cwd: cwd)
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 18))
                    .foregroundStyle(.tertiary)
                Text("Mở Terminal")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.03))
            )
        }
        .buttonStyle(.plain)
    }

    // ── Spawn handler ──

    private func handleSpawnPane(_ entityID: String) {
        store.selectedEntityID = entityID
        if let cwd = store.cwd(for: entityID) {
            let _ = store.spawnPane(entityID: entityID, cwd: cwd)
        }
    }

    private func shellFor(entityID: String) -> String {
        store.projects.first { $0.id.uuidString == entityID }?.shellPath ?? ProjectStore.defaultShell
    }

    private func folderName(_ path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }
}
// ponytail: TerminalPlaceholder removed, replaced by TerminalPane (SwiftTerm)
