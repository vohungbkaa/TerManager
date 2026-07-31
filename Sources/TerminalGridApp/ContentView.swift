import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ProjectStore
    @State private var settingsOpen = false

    var body: some View {
        HSplitView {
            // Sidebar
            ProjectSidebar(onSpawnPane: handleSpawnPane)
                .frame(minWidth: 180, idealWidth: 220, maxWidth: 260)
                .frame(maxHeight: .infinity)

            // Main terminal area
            terminalArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 900, minHeight: 560)
        .background(Color.themeBase)
        .overlay {
            if settingsOpen {
                ZStack(alignment: .trailing) {
                    // Dark backdrop with independent opacity transition
                    Color.black.opacity(0.55)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                                settingsOpen = false
                            }
                        }
                        .transition(.opacity)

                    // Slide-right Settings Drawer Panel
                    SettingsPopover(isOpen: $settingsOpen)
                        .transition(.move(edge: .trailing))
                }
            }
        }
    }

    // ── Terminal grid ──

    @ViewBuilder
    private var terminalArea: some View {
        if store.projects.isEmpty {
            OnboardingHintView {
                if let url = pickFolder() {
                    store.addProject(folderURL: url)
                }
            }
        } else if let selected = store.selectedEntityID, !selected.isEmpty {
            let activeIDs = activeEntityIDs(selected: selected)
            VStack(spacing: 0) {
                toolbar(for: selected)
                    .zIndex(1)

                ZStack(alignment: .topLeading) {
                    ForEach(activeIDs, id: \.self) { eid in
                        paneGrid(entityID: eid)
                            .opacity(eid == selected ? 1 : 0)
                            .allowsHitTesting(eid == selected)
                            .zIndex(eid == selected ? 1 : 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .zIndex(0)
            }
            .background(Color.themeBase)
        } else {
            noSelection
        }
    }

    private func activeEntityIDs(selected: String) -> [String] {
        var validIDs = Set<String>()
        for p in store.projects {
            validIDs.insert(p.id.uuidString)
            for sub in p.subProjects {
                validIDs.insert(sub.id.uuidString)
            }
        }
        
        var ids = Set<String>()
        if validIDs.contains(selected) {
            ids.insert(selected)
        }
        for (id, slots) in store.panes {
            if validIDs.contains(id) && slots.contains(where: { $0 != nil }) {
                ids.insert(id)
            }
        }
        return ids.sorted()
    }

    private var noSelection: some View {
        VStack(spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 48))
                .foregroundColor(.themeTextMuted)
            Text("Chọn một dự án").font(.title2.weight(.medium))
                .foregroundColor(.themeTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.themeBase)
        .contentShape(Rectangle())
        .onTapGesture {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
    }

    // ── Toolbar ──

    private func toolbar(for entityID: String) -> some View {
        HStack(spacing: 6) {
            breadcrumbs(for: entityID)
            Spacer()
            GridSizePicker(grid: binding(for: entityID))
                .onChange(of: store.grid(for: entityID)) { _ in
                    let g = store.grid(for: entityID)
                    store.updateGrid(g.rows, g.cols, for: entityID)
                }
            settingsButton
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(Color.themeSurface)
        .overlay(
            Rectangle()
                .fill(Color.themeBorder)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    @ViewBuilder
    private func breadcrumbs(for entityID: String) -> some View {
        HStack(spacing: 6) {
            if let project = store.projects.first(where: { $0.id.uuidString == entityID }) {
                ProjectIconView(project: project, size: 16)

                Text(project.name)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Text("/")
                    .foregroundColor(.themeTextMuted)
                Text(project.path)
                    .font(.system(size: 11))
                    .foregroundColor(.themeTextMuted)
                    .lineLimit(1)
            } else {
                subBreadcrumbs(for: entityID)
            }
        }
    }

    private func findSubProject(for entityID: String) -> (project: Project, sub: SubProject)? {
        for p in store.projects {
            if let sub = p.subProjects.first(where: { $0.id.uuidString == entityID }) {
                return (p, sub)
            }
        }
        return nil
    }

    @ViewBuilder
    private func subBreadcrumbs(for entityID: String) -> some View {
        if let match = findSubProject(for: entityID) {
            ProjectIconView(project: match.project, size: 16)

            Text(match.project.name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.themeTextSecondary)
            Text("/")
                .foregroundColor(.themeTextMuted)
            Text(match.sub.name)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
            Text("/")
                .foregroundColor(.themeTextMuted)
            Text(match.sub.path)
                .font(.system(size: 11))
                .foregroundColor(.themeTextMuted)
                .lineLimit(1)
        }
    }

    // ── Pane grid ──

    private func binding(for entityID: String) -> Binding<GridSize> {
        Binding(
            get: { store.grid(for: entityID) },
            set: { store.grids[entityID] = $0 }
        )
    }

    private func paneGrid(entityID: String) -> some View {
        let slots = store.slots(for: entityID)
        let grid = store.grid(for: entityID)
        return Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            ForEach(0..<grid.rows, id: \.self) { row in
                GridRow {
                    ForEach(0..<grid.cols, id: \.self) { col in
                        let index = row * grid.cols + col
                        if index < slots.count, let slot = slots[index] {
                            PaneCellView(
                                slot: slot,
                                index: index,
                                entityID: entityID,
                                shellPath: shellFor(entityID: entityID),
                                onKill: {
                                    store.killPane(entityID: entityID, index: index)
                                }
                            )
                            .id(slot.paneId)
                        } else {
                            EmptyCellView(
                                index: index,
                                onOpen: {
                                    if let cwd = store.cwd(for: entityID) {
                                        let _ = store.spawnPane(entityID: entityID, cwd: cwd)
                                    }
                                },
                                onDropOpen: { droppedPath in
                                    let _ = store.spawnPane(entityID: entityID, cwd: droppedPath)
                                }
                            )
                            .id("\(entityID)-\(index)")
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color.themeBase)
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

    private var settingsButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                settingsOpen.toggle()
            }
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 13))
                .foregroundColor(settingsOpen ? .themePrimaryHover : .themeTextSecondary)
                .rotationEffect(.degrees(settingsOpen ? 45 : 0))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(settingsOpen ? Color.themePrimary.opacity(0.15) : Color.white.opacity(0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(settingsOpen ? Color.themePrimary.opacity(0.6) : Color.white.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: settingsOpen ? Color.themePrimary.opacity(0.3) : Color.clear, radius: 6)
        }
        .buttonStyle(.plain)
        .help("Thiết lập hệ thống (ESC)")
    }
}

// ── Onboarding / Empty State Card ──

struct OnboardingHintView: View {
    let onAddFolder: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                // Circular icon wrap
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.themePrimary.opacity(0.08))
                        .frame(width: 72, height: 72)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.themePrimary.opacity(0.15), lineWidth: 1)
                        )
                    
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(.themePrimaryHover)
                        .shadow(color: Color.themePrimary.opacity(0.3), radius: 8)
                }
                
                VStack(spacing: 8) {
                    Text("Chưa có dự án nào")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Thêm thư mục dự án từ máy tính của bạn để bắt đầu mở các terminal con.")
                        .font(.system(size: 13))
                        .foregroundColor(.themeTextSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: 320)
                }
                
                Button(action: onAddFolder) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("Thêm thư mục")
                    }
                }
                .buttonStyle(ThemeButton(isPrimary: true, isHovered: isHovered))
                .onHover { isHovered = $0 }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 36)
            .background(Color.themeSurface)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.themeBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 30, y: 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.themeBase)
    }
}

// ── Pane Cell View with isolated hover state ──

struct PaneCellView: View {
    let slot: PaneSlot
    let index: Int
    let entityID: String
    let shellPath: String
    let onKill: () -> Void

    @EnvironmentObject private var store: ProjectStore
    @State private var isHovered = false
    @State private var isCloseHovered = false
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.themePrimary)
                
                Text(folderName(slot.cwd))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(red: 229/255, green: 231/255, blue: 235/255))
                    .lineLimit(1)
                
                Text(slot.cwd)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.themeTextMuted)
                    .lineLimit(1)
                    .padding(.leading, 6)
                
                Spacer()
                
                Button(action: onKill) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(isCloseHovered ? .themeRed : .themeTextSecondary)
                        .frame(width: 20, height: 20)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isCloseHovered ? Color.themeRed.opacity(0.12) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .onHover { isCloseHovered = $0 }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.01))
            .overlay(
                Rectangle()
                    .fill(Color.themeBorder)
                    .frame(height: 1),
                alignment: .bottom
            )
            
            TerminalPane(paneId: slot.paneId, cwd: slot.cwd, shellPath: shellPath)
                .padding(8)
                .background(Color(red: 13/255, green: 14/255, blue: 17/255)) // #0d0e11
        }
        .background(Color(red: 13/255, green: 14/255, blue: 17/255)) // #0d0e11
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isHovered ? Color.themePrimary.opacity(0.3) : Color.themeBorder, lineWidth: 1)
        )
        .shadow(color: isHovered ? .black.opacity(0.35) : .clear, radius: 20, y: 4)
        .animation(.easeOut(duration: 0.25), value: isHovered)
        .onHover { isHovered = $0 }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleTerminalDrop(providers)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.themePrimary.opacity(0.5), lineWidth: 2)
                .opacity(isDropTargeted ? 1 : 0)
        )
    }

    private func handleTerminalDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                let path = url.path
                DispatchQueue.main.async {
                    if let termView = store.getTerminalView(for: slot.paneId) {
                        termView.send(txt: path)
                    }
                }
            }
            accepted = true
        }
        return accepted
    }

    private func folderName(_ path: String) -> String {
        path.split(separator: "/").last.map(String.init) ?? path
    }
}

// ── Empty Cell / Placeholder with isolated hover state ──

struct EmptyCellView: View {
    let index: Int
    let onOpen: () -> Void
    var onDropOpen: (String) -> Void = { _ in }
    @State private var isHovered = false
    @State private var isDropTargeted = false
    
    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 12) {
                // Circular icon wrapper
                ZStack {
                    Circle()
                        .stroke(isHovered ? Color.themePrimary.opacity(0.35) : Color.white.opacity(0.05), lineWidth: 1)
                        .background(Circle().fill(isHovered ? Color.themePrimary.opacity(0.1) : Color.white.opacity(0.02)))
                        .frame(width: 40, height: 40)
                        .scaleEffect(isHovered ? 1.05 : 1.0)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 16))
                        .foregroundColor(isHovered ? .themePrimaryHover : .themeTextSecondary)
                }
                
                VStack(spacing: 4) {
                    Text("Mở Terminal")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isHovered ? .white : Color(red: 209/255, green: 213/255, blue: 219/255))
                    
                    Text("Click để mở terminal tại đây")
                        .font(.system(size: 11))
                        .foregroundColor(.themeTextMuted)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color.themePrimary.opacity(0.02) : Color.white.opacity(0.005))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    style: StrokeStyle(
                        lineWidth: 1,
                        dash: isHovered ? [] : [4]
                    )
                )
                .foregroundColor(isHovered ? Color.themePrimary.opacity(0.4) : Color.white.opacity(0.1))
        )
        .shadow(color: isHovered ? Color.themePrimary.opacity(0.04) : .clear, radius: 20)
        .animation(.easeOut(duration: 0.25), value: isHovered)
        .onHover { isHovered = $0 }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleEmptyDrop(providers)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.themePrimary.opacity(0.5), lineWidth: 2)
                .opacity(isDropTargeted ? 1 : 0)
        )
    }

    private func handleEmptyDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url else { return }
                let path = url.path
                DispatchQueue.main.async {
                    onDropOpen(path)
                }
            }
            accepted = true
        }
        return accepted
    }
}
// ponytail: TerminalPlaceholder removed, replaced by TerminalPane (SwiftTerm)
