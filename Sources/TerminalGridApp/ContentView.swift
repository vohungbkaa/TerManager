import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ProjectStore
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var settingsOpen = false
    @StateObject private var mobileRunController = MobileRunController()

    var body: some View {
        let theme = themeManager.current
        NavigationSplitView {
            ProjectSidebar(onSpawnPane: handleSpawnPane)
                .navigationSplitViewColumnWidth(min: 200, ideal: 232, max: 360)
        } detail: {
            terminalArea
        }
        .frame(minWidth: 920, minHeight: 580)
        .background(theme.windowBackground)
        .overlay {
            if settingsOpen {
                ZStack(alignment: .trailing) {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                                settingsOpen = false
                            }
                        }
                        .transition(.opacity)

                    SettingsPopover(isOpen: $settingsOpen)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Terminal Area

    @ViewBuilder
    private var terminalArea: some View {
        let theme = themeManager.current
        if let selected = store.selectedEntityID, !selected.isEmpty {
            let activeIDs = activeEntityIDs(selected: selected)
            VStack(spacing: 0) {
                toolbar(for: selected)
                    .zIndex(2)

                let hiddenPanes = store.hiddenPanes(for: selected)
                if !hiddenPanes.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "eye.slash")
                                    .font(.system(size: 9.5, weight: .semibold))
                                Text("Đang ẩn")
                                    .font(.system(size: 10.5, weight: .semibold))
                            }
                            .foregroundColor(theme.textMuted)
                            .padding(.trailing, 2)

                            ForEach(hiddenPanes) { pane in
                                HiddenPaneItemView(pane: pane, entityID: selected)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                    }
                    .background(theme.surface.opacity(0.85))
                    .overlay(HairlineDivider(), alignment: .bottom)
                    .zIndex(1)
                }

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

                if let session = mobileRunController.activeSession {
                    BuildTerminalDrawerHost(session: session)
                }
            }
            .background(theme.windowBackground)
            .onAppear { activateMobileProject(for: selected) }
            .onChange(of: selected) { newValue in
                activateMobileProject(for: newValue)
            }
        } else if store.projects.isEmpty {
            OnboardingHintView {
                if let url = pickFolder() {
                    store.addProject(folderURL: url)
                }
            }
        } else {
            noSelection
        }
    }

    private func activeEntityIDs(selected: String) -> [String] {
        var validIDs = Set<String>()
        validIDs.insert("default-terminal")
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
        let theme = themeManager.current
        return VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    )
                    .frame(width: 56, height: 56)
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(theme.textMuted)
            }
            Text("Chọn một dự án từ thanh bên")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.windowBackground)
        .contentShape(Rectangle())
        .onTapGesture {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
    }

    // MARK: - Unified Toolbar

    private func toolbar(for entityID: String) -> some View {
        let theme = themeManager.current
        let activeCount = store.slots(for: entityID).compactMap { $0 }.count

        return HStack(spacing: 10) {
            breadcrumbs(for: entityID)

            if activeCount > 0 {
                Text("\(activeCount) pane")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.textMuted)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(theme.surfaceHover))
                    .overlay(Capsule().stroke(theme.border, lineWidth: 1))
            }

            Spacer()

            if let project = store.project(for: entityID),
               project.projectType != .unknown,
               mobileRunController.activeProject?.id == project.id,
               let session = mobileRunController.activeSession {
                MobileRunToolbar(controller: mobileRunController, session: session)

                HairlineDivider(vertical: true)
                    .frame(height: 18)
                    .padding(.horizontal, 2)
            }

            Button {
                handleSpawnPane(entityID)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "plus")
                        .font(.system(size: 10.5, weight: .bold))
                    Text("Terminal")
                        .font(.system(size: 11.5, weight: .medium))
                }
            }
            .buttonStyle(ThemeButton(isPrimary: false, isCompact: true))
            .help("Mở thêm một Terminal mới")

            settingsButton
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(theme.toolbarBackground)
        .overlay(HairlineDivider(), alignment: .bottom)
    }

    private func activateMobileProject(for entityID: String) {
        guard let project = store.project(for: entityID), project.projectType != .unknown else {
            mobileRunController.deactivate()
            return
        }
        mobileRunController.activate(project: project)
    }

    @ViewBuilder
    private func breadcrumbs(for entityID: String) -> some View {
        let theme = themeManager.current
        HStack(spacing: 7) {
            if entityID == "default-terminal" {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(theme.success.opacity(0.14))
                    Image(systemName: "terminal.fill")
                        .foregroundColor(theme.success)
                        .font(.system(size: 10, weight: .semibold))
                }
                .frame(width: 20, height: 20)

                Text("Terminal Mặc định")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(theme.textPrimary)

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(theme.textMuted)

                Text("~")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.textSecondary)
            } else if let project = store.projects.first(where: { $0.id.uuidString == entityID }) {
                ProjectIconView(project: project, size: 20)

                Text(project.name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
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
        let theme = themeManager.current
        if let match = findSubProject(for: entityID) {
            ProjectIconView(project: match.project, size: 20)

            Text(match.project.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)

            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(theme.textMuted)

            Text(match.sub.name)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
        }
    }

    // MARK: - Pane Grid

    private func paneGrid(entityID: String) -> some View {
        let theme = themeManager.current
        let slots = store.slots(for: entityID)
        let grid = store.grid(for: entityID)
        return ResizableTerminalGrid(rows: grid.rows, columns: grid.cols, spacing: 10) { index in
            Group {
                if index < slots.count, let slot = slots[index] {
                    PaneCellView(
                        slot: slot,
                        index: index,
                        entityID: entityID,
                        shellPath: shellFor(entityID: entityID),
                        onKill: {
                            store.killPane(entityID: entityID, index: index)
                        },
                        onHide: {
                            store.hidePane(entityID: entityID, index: index)
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
        .id("\(entityID)-\(grid.rows)x\(grid.cols)")
        .padding(10)
        .background(theme.windowBackground)
    }

    // MARK: - Actions

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
            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                settingsOpen.toggle()
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 12.5, weight: .medium))
        }
        .buttonStyle(GlassIconButtonStyle(active: settingsOpen, size: 28))
        .help("Thiết lập & Giao diện (ESC)")
    }
}

// MARK: - Onboarding / Empty State Card

struct OnboardingHintView: View {
    let onAddFolder: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        let theme = themeManager.current
        ZStack {
            RadialGradient(
                colors: [theme.accent.opacity(0.08), Color.clear],
                center: .center,
                startRadius: 20,
                endRadius: 340
            )
            .allowsHitTesting(false)

            VStack(spacing: 22) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.accentSoft)
                        .frame(width: 60, height: 60)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(theme.accent.opacity(0.28), lineWidth: 1)
                        )

                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(theme.accentHover)
                }

                VStack(spacing: 6) {
                    Text("Chào mừng đến Terminal Manager")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.textPrimary)

                    Text("Thêm thư mục dự án từ máy tính của bạn để bắt đầu làm việc với nhiều terminal song song.")
                        .font(.system(size: 12.5))
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 320)
                }

                Button(action: onAddFolder) {
                    HStack(spacing: 7) {
                        Image(systemName: "plus")
                            .font(.system(size: 11.5, weight: .bold))
                        Text("Thêm thư mục dự án")
                    }
                }
                .buttonStyle(ThemeButton(isPrimary: true))
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 34)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(theme.borderStrong, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 28, y: 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.windowBackground)
    }
}

// MARK: - Pane Cell View

struct PaneCellView: View {
    let slot: PaneSlot
    let index: Int
    let entityID: String
    let shellPath: String
    let onKill: () -> Void
    let onHide: () -> Void

    @EnvironmentObject private var store: ProjectStore
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isHovered = false
    @State private var isCloseHovered = false
    @State private var isHideHovered = false
    @State private var isDropTargeted = false
    @State private var isEditingName = false
    @State private var editedName = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        let theme = themeManager.current
        VStack(spacing: 0) {
            // Compact 32pt pane titlebar
            HStack(spacing: 8) {
                Circle()
                    .fill(isHovered ? theme.accent : theme.success.opacity(0.85))
                    .frame(width: 6.5, height: 6.5)

                if isEditingName {
                    TextField("", text: $editedName)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(theme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(theme.accent, lineWidth: 1)
                        )
                        .focused($isTextFieldFocused)
                        .onSubmit { commitPaneRename() }
                        .onChange(of: isTextFieldFocused) { focused in
                            if !focused && isEditingName { commitPaneRename() }
                        }
                        .onAppear { isTextFieldFocused = true }
                } else {
                    Text(slot.customName ?? "Terminal \(index + 1)")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(theme.textPrimary.opacity(0.92))
                        .lineLimit(1)
                        .onTapGesture(count: 2) {
                            editedName = slot.customName ?? "Terminal \(index + 1)"
                            isEditingName = true
                            isTextFieldFocused = true
                        }
                        .help("Nhấn đúp để đổi tên Terminal")
                }

                Text(folderName(slot.cwd))
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundColor(theme.textMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 6)

                HStack(spacing: 3) {
                    let visibleCount = store.slots(for: entityID).compactMap { $0 }.count
                    if visibleCount > 1 {
                        Button(action: onHide) {
                            Image(systemName: "eye.slash")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(isHideHovered ? theme.accentHover : theme.textMuted)
                                .frame(width: 20, height: 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(isHideHovered ? theme.accentSoft : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                        .onHover { isHideHovered = $0 }
                        .help("Ẩn Terminal nhưng giữ tiến trình chạy ngầm")
                    }

                    Button(action: onKill) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(isCloseHovered ? theme.danger : theme.textMuted)
                            .frame(width: 20, height: 20)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(isCloseHovered ? theme.danger.opacity(0.14) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { isCloseHovered = $0 }
                    .help("Đóng Terminal và dừng tiến trình")
                }
                .opacity(isHovered || isCloseHovered || isHideHovered ? 1.0 : 0.45)
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(theme.surface)
            .overlay(HairlineDivider(), alignment: .bottom)
            .zIndex(2)

            TerminalPane(
                paneId: slot.paneId,
                cwd: slot.cwd,
                shellPath: shellPath,
                startupCommand: slot.startupCommand
            )
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(theme.terminalBackground)
            .clipped()
            .zIndex(0)
        }
        .background(theme.terminalBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    isDropTargeted
                        ? theme.accent
                        : (isHovered ? theme.borderStrong : theme.border),
                    lineWidth: isDropTargeted ? 1.5 : 1
                )
                .allowsHitTesting(false)
        )
        .shadow(color: .black.opacity(0.22), radius: 10, y: 3)
        .animation(.easeOut(duration: 0.16), value: isHovered)
        .onHover { isHovered = $0 }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleTerminalDrop(providers)
        }
    }

    private func commitPaneRename() {
        store.renamePane(entityID: entityID, paneId: slot.paneId, newName: editedName)
        isEditingName = false
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
        let abbreviated = abbreviatedHomePath(path)
        if abbreviated == "~" { return "~" }
        return path.split(separator: "/").last.map(String.init) ?? path
    }
}

// MARK: - Empty Cell / Placeholder

struct EmptyCellView: View {
    let index: Int
    let onOpen: () -> Void
    var onDropOpen: (String) -> Void = { _ in }
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isHovered = false
    @State private var isDropTargeted = false

    var body: some View {
        let theme = themeManager.current
        Button(action: onOpen) {
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isHovered || isDropTargeted ? theme.accentSoft : theme.surfaceElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(isHovered || isDropTargeted ? theme.accent.opacity(0.45) : theme.border, lineWidth: 1)
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: isDropTargeted ? "arrow.down.doc" : "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isHovered || isDropTargeted ? theme.accentHover : theme.textSecondary)
                }
                .scaleEffect(isHovered ? 1.04 : 1.0)

                VStack(spacing: 3) {
                    Text(isDropTargeted ? "Thả thư mục để mở Terminal" : "Mở Terminal")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isHovered ? theme.textPrimary : theme.textSecondary)

                    Text("Nhấn để tạo hoặc kéo thả thư mục vào đây")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textMuted)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovered || isDropTargeted ? theme.surface : theme.surface.opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    isDropTargeted
                        ? theme.accent
                        : (isHovered ? theme.borderStrong : theme.border),
                    lineWidth: isDropTargeted ? 1.5 : 1
                )
        )
        .animation(.easeOut(duration: 0.16), value: isHovered)
        .onHover { isHovered = $0 }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleEmptyDrop(providers)
        }
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

// MARK: - Hidden Pane Pill

struct HiddenPaneItemView: View {
    let pane: PaneSlot
    let entityID: String
    @EnvironmentObject private var store: ProjectStore
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isHovered = false
    @State private var isCloseHovered = false

    var body: some View {
        let theme = themeManager.current
        HStack(spacing: 6) {
            Circle()
                .fill(theme.success)
                .frame(width: 5.5, height: 5.5)

            Text(pane.customName ?? "Terminal")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(isHovered ? theme.textPrimary : theme.textSecondary)
                .lineLimit(1)

            Button {
                store.killHiddenPane(entityID: entityID, paneId: pane.paneId)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(isCloseHovered ? theme.danger : theme.textMuted)
                    .frame(width: 16, height: 16)
                    .background(
                        Circle()
                            .fill(isCloseHovered ? theme.danger.opacity(0.16) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .onHover { isCloseHovered = $0 }
            .help("Đóng Terminal ẩn này")
        }
        .padding(.leading, 9)
        .padding(.trailing, 5)
        .padding(.vertical, 4.5)
        .background(
            Capsule()
                .fill(isHovered ? theme.surfaceElevated : theme.surfaceHover)
        )
        .overlay(
            Capsule()
                .stroke(isHovered ? theme.accent.opacity(0.45) : theme.border, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .onTapGesture {
            store.restoreHiddenPane(entityID: entityID, paneId: pane.paneId)
        }
        .help("Nhấn để khôi phục Terminal")
    }
}
