import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject private var store: ProjectStore
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var agentCommandStore: AgentCommandStore
    @StateObject private var mobileRunController = MobileRunController()

    @AppStorage("sidebarPinned") private var sidebarPinned = false
    @State private var sidebarHoverVisible = false
    @State private var isHoveringSidebarTrigger = false
    @State private var isHoveringSidebarDrawer = false
    @State private var sidebarHideWorkItem: DispatchWorkItem?
    @State private var sidebarWidth: CGFloat = 224
    @State private var dragStartSidebarWidth: CGFloat?
    @State private var isSidebarDividerHovered = false

    @State private var agentPanelVisible = false
    @State private var agentPanelPinned = false
    @State private var agentPanelPopoverOpen = false
    @State private var isHoveringAgentTrigger = false
    @State private var isHoveringAgentDrawer = false
    @State private var agentHideWorkItem: DispatchWorkItem?
    @State private var settingsOpen = false
    @State private var zoomedPaneIDs: [String: String] = [:] // entityID -> paneId
    @State private var copiedPathFeedback = false

    var body: some View {
        let theme = themeManager.current
        HStack(spacing: 0) {
            if sidebarPinned {
                ProjectSidebar(
                    isPinned: $sidebarPinned,
                    isFloating: false,
                    onSpawnPane: { handleSpawnPane($0) },
                    onToggleSettings: { toggleSettings() }
                )
                .frame(width: sidebarWidth)
                .transition(.move(edge: .leading).combined(with: .opacity))

                // Crisp resizable hairline split divider
                sidebarResizeDivider
            }

            workspaceStage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.windowBackground)
                .overlay(alignment: .leading) {
                    if !sidebarPinned {
                        hoverLeftSidebarOverlay
                    }
                }
                .overlay(alignment: .trailing) {
                    hoverAgentDrawerOverlay
                }
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 900, minHeight: 580)
        .background(theme.windowBackground)
        .overlay {
            if settingsOpen {
                ZStack(alignment: .trailing) {
                    Color.black.opacity(0.42)
                        .ignoresSafeArea()
                        .contentShape(Rectangle())
                        .onTapGesture { toggleSettings(open: false) }
                        .transition(.opacity)

                    SettingsPopover(isOpen: $settingsOpen)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebarShortcut)) { _ in
            toggleSidebar()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSettingsShortcut)) { _ in
            toggleSettings()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newTerminalShortcut)) { _ in
            if let selected = store.selectedEntityID, !selected.isEmpty {
                handleSpawnPane(selected)
            }
        }
    }

    // MARK: - Left-Edge Hover-Reveal Workspaces Drawer

    private var hoverLeftSidebarOverlay: some View {
        let theme = themeManager.current

        return ZStack(alignment: .leading) {
            if !sidebarHoverVisible {
                ZStack(alignment: .leading) {
                    Color.clear
                        .frame(width: 14)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())

                    VStack(spacing: 4) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(isHoveringSidebarTrigger ? theme.accentHover : theme.textMuted)
                    }
                    .frame(width: 18, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(theme.surfaceElevated.opacity(0.92))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isHoveringSidebarTrigger ? theme.accent.opacity(0.5) : theme.borderStrong, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.28), radius: 6, x: 2, y: 2)
                    .offset(x: -4)
                }
                .padding(.top, 44)
                .padding(.bottom, 30)
                .onHover { hovering in
                    isHoveringSidebarTrigger = hovering
                    if hovering {
                        openHoverSidebar()
                    }
                }
                .help("Di chuột vào đây để mở danh sách Workspaces")
            }

            if sidebarHoverVisible {
                ProjectSidebar(
                    isPinned: $sidebarPinned,
                    isFloating: true,
                    onSpawnPane: { handleSpawnPane($0) },
                    onToggleSettings: { toggleSettings() }
                )
                .frame(width: max(228, sidebarWidth))
                .padding(.top, 46)
                .padding(.bottom, 32)
                .padding(.leading, 8)
                .onHover { hovering in
                    isHoveringSidebarDrawer = hovering
                    if hovering {
                        sidebarHideWorkItem?.cancel()
                    } else {
                        scheduleHideHoverSidebar()
                    }
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .onChange(of: sidebarPinned) { pinned in
            if pinned {
                sidebarHideWorkItem?.cancel()
                sidebarHoverVisible = false
            }
        }
    }

    private func openHoverSidebar() {
        sidebarHideWorkItem?.cancel()
        guard !sidebarHoverVisible else { return }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
            sidebarHoverVisible = true
        }
    }

    private func scheduleHideHoverSidebar() {
        sidebarHideWorkItem?.cancel()
        guard !sidebarPinned else { return }
        let item = DispatchWorkItem {
            guard !isHoveringSidebarDrawer && !isHoveringSidebarTrigger && !sidebarPinned else { return }
            withAnimation(.spring(response: 0.26, dampingFraction: 0.90)) {
                sidebarHoverVisible = false
            }
        }
        sidebarHideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: item)
    }

    // MARK: - Right-Edge Hover-Reveal Agent Commands Drawer

    private var hoverAgentDrawerOverlay: some View {
        let theme = themeManager.current
        let isShown = agentPanelVisible || agentPanelPinned || agentPanelPopoverOpen

        return ZStack(alignment: .trailing) {
            // Invisible 12pt right-edge hot zone + subtle vertical pill handle
            if !isShown {
                ZStack(alignment: .trailing) {
                    Color.clear
                        .frame(width: 14)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())

                    VStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(isHoveringAgentTrigger ? theme.accentHover : theme.textMuted)
                    }
                    .frame(width: 18, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(theme.surfaceElevated.opacity(0.92))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isHoveringAgentTrigger ? theme.accent.opacity(0.5) : theme.borderStrong, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.28), radius: 6, x: -2, y: 2)
                    .offset(x: 4)
                }
                .padding(.top, 44)
                .padding(.bottom, 30)
                .onHover { hovering in
                    isHoveringAgentTrigger = hovering
                    if hovering {
                        openAgentDrawer()
                    }
                }
                .help("Di chuột vào đây để mở bảng lệnh Agent")
            }

            if isShown {
                AgentCommandsPanel(
                    isPinned: $agentPanelPinned,
                    isPopoverOpen: $agentPanelPopoverOpen,
                    onLaunchCommand: { title, command in
                        let targetID = store.selectedEntityID ?? "default-terminal"
                        if let cwd = store.cwd(for: targetID) {
                            zoomedPaneIDs[targetID] = nil
                            _ = store.spawnPane(entityID: targetID, cwd: cwd, customName: title, startupCommand: command)
                        }
                    }
                )
                .frame(width: 244)
                .padding(.top, 46)
                .padding(.bottom, 32)
                .padding(.trailing, 8)
                .onHover { hovering in
                    isHoveringAgentDrawer = hovering
                    if hovering {
                        agentHideWorkItem?.cancel()
                    } else {
                        scheduleHideAgentDrawer()
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .onChange(of: agentPanelPopoverOpen) { open in
            if !open && !isHoveringAgentDrawer && !agentPanelPinned {
                scheduleHideAgentDrawer()
            }
        }
        .onChange(of: agentPanelPinned) { pinned in
            if !pinned && !isHoveringAgentDrawer && !agentPanelPopoverOpen {
                scheduleHideAgentDrawer()
            }
        }
    }

    private func openAgentDrawer() {
        agentHideWorkItem?.cancel()
        guard !agentPanelVisible else { return }
        withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
            agentPanelVisible = true
        }
    }

    private func scheduleHideAgentDrawer() {
        agentHideWorkItem?.cancel()
        guard !agentPanelPinned && !agentPanelPopoverOpen else { return }
        let item = DispatchWorkItem {
            guard !isHoveringAgentDrawer && !isHoveringAgentTrigger && !agentPanelPinned && !agentPanelPopoverOpen else {
                return
            }
            withAnimation(.spring(response: 0.26, dampingFraction: 0.90)) {
                agentPanelVisible = false
            }
        }
        agentHideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: item)
    }

    // MARK: - Sidebar Resize Divider

    private var sidebarResizeDivider: some View {
        let theme = themeManager.current
        return ZStack {
            theme.border
                .frame(width: 1)
            if isSidebarDividerHovered || dragStartSidebarWidth != nil {
                theme.accent.opacity(0.75)
                    .frame(width: 2)
            }
        }
        .frame(width: 5)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    let start = dragStartSidebarWidth ?? sidebarWidth
                    if dragStartSidebarWidth == nil { dragStartSidebarWidth = start }
                    sidebarWidth = min(320, max(185, start + value.translation.width))
                }
                .onEnded { _ in
                    dragStartSidebarWidth = nil
                }
        )
        .onHover { hovering in
            isSidebarDividerHovered = hovering
            if hovering {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    // MARK: - Workspace Stage

    @ViewBuilder
    private var workspaceStage: some View {
        let theme = themeManager.current
        if let selected = store.selectedEntityID, !selected.isEmpty {
            let activeIDs = activeEntityIDs(selected: selected)
            let visibleCount = store.slots(for: selected).compactMap { $0 }.count
            let hiddenPanes = store.hiddenPanes(for: selected)

            VStack(spacing: 0) {
                workspaceTopBar(for: selected, visibleCount: visibleCount)
                    .zIndex(2)

                // Main Terminal Canvas (or Developer Launchpad when 0 panes are open)
                ZStack(alignment: .topLeading) {
                    ForEach(activeIDs, id: \.self) { eid in
                        let eidVisible = store.slots(for: eid).compactMap { $0 }
                        Group {
                            if eidVisible.isEmpty {
                                WorkspaceLaunchpadView(
                                    entityID: eid,
                                    cwd: store.cwd(for: eid) ?? FileManager.default.homeDirectoryForCurrentUser.path,
                                    title: workspaceTitle(for: eid),
                                    project: store.project(for: eid),
                                    onLaunchSingle: { handleSpawnPane(eid) },
                                    onLaunchSplit: {
                                        handleSpawnPane(eid)
                                        handleSpawnPane(eid)
                                    },
                                    onLaunchAgent: { name, cmd in
                                        if let cwd = store.cwd(for: eid) {
                                            _ = store.spawnPane(entityID: eid, cwd: cwd, customName: name, startupCommand: cmd)
                                        }
                                    },
                                    onDropFolder: { droppedPath in
                                        _ = store.spawnPane(entityID: eid, cwd: droppedPath)
                                    }
                                )
                            } else {
                                paneCanvas(entityID: eid)
                            }
                        }
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

                // Pro Bottom Status Bar (cwd, shell, hidden panes dock, grid badge)
                workspaceStatusBar(for: selected, visibleCount: visibleCount, hiddenPanes: hiddenPanes)
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

    // MARK: - Focused Top Bar (40pt, aligned with macOS Traffic Lights)

    private func workspaceTopBar(for entityID: String, visibleCount: Int) -> some View {
        let theme = themeManager.current
        let isZoomed = zoomedPaneIDs[entityID] != nil

        return HStack(spacing: 8) {
            if !sidebarPinned {
                // Leave room for macOS traffic lights when sidebar is not docked
                Spacer().frame(width: 68)

                Button(action: toggleSidebar) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(GlassIconButtonStyle(size: 26))
                .help("Ghim cố định Sidebar (⌘\\)")
            }

            breadcrumbs(for: entityID)

            Spacer()

            if isZoomed {
                Button {
                    withAnimation(.easeOut(duration: 0.16)) {
                        zoomedPaneIDs[entityID] = nil
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.system(size: 9.5, weight: .bold))
                        Text("Thoát phóng to")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(theme.accentHover)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(theme.accentSoft))
                    .overlay(Capsule().stroke(theme.accent.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .help("Quay lại chế độ lưới")
            }

            if let project = store.project(for: entityID),
               project.projectType != .unknown,
               mobileRunController.activeProject?.id == project.id,
               let session = mobileRunController.activeSession {
                MobileRunToolbar(controller: mobileRunController, session: session)
            }

            if visibleCount > 0 {
                Button {
                    zoomedPaneIDs[entityID] = nil
                    handleSpawnPane(entityID)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 10.5, weight: .bold))
                        Text("Split")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                }
                .buttonStyle(ThemeButton(isPrimary: false, isCompact: true))
                .help("Mở thêm Terminal mới (⌘T)")
            }

            if !sidebarPinned {
                Button(action: { toggleSettings() }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(GlassIconButtonStyle(active: settingsOpen, size: 26))
                .help("Thiết lập & Giao diện (⌘,)")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(theme.toolbarBackground)
        .overlay(HairlineDivider(), alignment: .bottom)
    }

    // MARK: - Pro Bottom Status Bar (26pt)

    private func workspaceStatusBar(for entityID: String, visibleCount: Int, hiddenPanes: [PaneSlot]) -> some View {
        let theme = themeManager.current
        let cwd = store.cwd(for: entityID) ?? "~"
        let grid = store.grid(for: entityID)
        let shellName = URL(fileURLWithPath: shellFor(entityID: entityID)).lastPathComponent

        return HStack(spacing: 10) {
            // Clickable path -> open in Finder
            Button {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: cwd)
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "folder")
                        .font(.system(size: 9.5, weight: .medium))
                    Text(abbreviatedHomePath(cwd))
                        .font(.system(size: 10.5, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .foregroundColor(theme.textMuted)
            }
            .buttonStyle(.plain)
            .help("Nhấn để mở thư mục trong Finder")

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(cwd, forType: .string)
                copiedPathFeedback = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    copiedPathFeedback = false
                }
            } label: {
                Image(systemName: copiedPathFeedback ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(copiedPathFeedback ? theme.success : theme.textMuted)
            }
            .buttonStyle(.plain)
            .help("Sao chép đường dẫn")

            // Hidden Panes Dock lives calmly in the status bar (zero grid jump!)
            if !hiddenPanes.isEmpty {
                HairlineDivider(vertical: true)
                    .frame(height: 12)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(hiddenPanes) { pane in
                            HiddenPaneItemView(pane: pane, entityID: entityID)
                        }
                    }
                }
                .frame(maxWidth: 360)
            }

            Spacer()

            if visibleCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 9.5))
                    Text("\(grid.rows)×\(grid.cols)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .foregroundColor(theme.textMuted)
            }

            Text(shellName)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(theme.textMuted)
                .padding(.horizontal, 6)
                .padding(.vertical, 1.5)
                .background(Capsule().fill(theme.surfaceHover))
        }
        .padding(.horizontal, 12)
        .frame(height: 26)
        .background(theme.surface)
        .overlay(HairlineDivider(), alignment: .top)
    }

    // MARK: - Breadcrumbs

    @ViewBuilder
    private func breadcrumbs(for entityID: String) -> some View {
        let theme = themeManager.current
        HStack(spacing: 6) {
            if entityID == "default-terminal" {
                Image(systemName: "terminal.fill")
                    .foregroundColor(theme.success)
                    .font(.system(size: 11, weight: .semibold))
                Text("Home")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Text("~")
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundColor(theme.textMuted)
            } else if let project = store.projects.first(where: { $0.id.uuidString == entityID }) {
                ProjectIconView(project: project, size: 17)
                Text(project.name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)

                if project.projectType != .unknown {
                    let badgeColor = projectTypeBadgeColor(project.projectType, theme: theme)
                    Text(project.projectType.displayName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(badgeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeColor.opacity(0.13))
                        .clipShape(Capsule())
                }
            } else if let match = findSubProject(for: entityID) {
                ProjectIconView(project: match.project, size: 17)
                Text(match.project.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8.5, weight: .semibold))
                    .foregroundColor(theme.textMuted)
                Text(match.sub.name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Pane Canvas (Grid + Zoom / Focus Mode)

    @ViewBuilder
    private func paneCanvas(entityID: String) -> some View {
        let theme = themeManager.current
        let slots = store.slots(for: entityID)
        let grid = store.grid(for: entityID)
        let visibleCount = slots.compactMap { $0 }.count
        let zoomedID = zoomedPaneIDs[entityID]

        ZStack {
            // Keep grid alive underneath so terminal processes never flicker or reset on zoom
            ResizableTerminalGrid(rows: grid.rows, columns: grid.cols, spacing: 6) { index in
                Group {
                    if index < slots.count, let slot = slots[index] {
                        let isThisZoomed = zoomedID == slot.paneId
                        PaneCellView(
                            slot: slot,
                            index: index,
                            entityID: entityID,
                            shellPath: shellFor(entityID: entityID),
                            isZoomed: isThisZoomed,
                            canZoom: visibleCount > 1,
                            onToggleZoom: {
                                withAnimation(.easeOut(duration: 0.16)) {
                                    zoomedPaneIDs[entityID] = isThisZoomed ? nil : slot.paneId
                                }
                            },
                            onKill: {
                                if zoomedPaneIDs[entityID] == slot.paneId {
                                    zoomedPaneIDs[entityID] = nil
                                }
                                store.killPane(entityID: entityID, index: index)
                            },
                            onHide: {
                                if zoomedPaneIDs[entityID] == slot.paneId {
                                    zoomedPaneIDs[entityID] = nil
                                }
                                store.hidePane(entityID: entityID, index: index)
                            }
                        )
                        .id(slot.paneId)
                    } else {
                        SecondaryEmptyCellView(
                            onOpen: {
                                if let cwd = store.cwd(for: entityID) {
                                    _ = store.spawnPane(entityID: entityID, cwd: cwd)
                                }
                            },
                            onDropOpen: { droppedPath in
                                _ = store.spawnPane(entityID: entityID, cwd: droppedPath)
                            },
                            onDropCommand: { title, command in
                                if let cwd = store.cwd(for: entityID) {
                                    _ = store.spawnPane(entityID: entityID, cwd: cwd, customName: title, startupCommand: command)
                                }
                            }
                        )
                        .id("\(entityID)-\(index)")
                    }
                }
            }
            .id("\(entityID)-\(grid.rows)x\(grid.cols)")
            .opacity(zoomedID == nil ? 1 : 0)
            .allowsHitTesting(zoomedID == nil)

            if let zoomedID,
               let matchIndex = slots.firstIndex(where: { $0?.paneId == zoomedID }),
               let slot = slots[matchIndex] {
                PaneCellView(
                    slot: slot,
                    index: matchIndex,
                    entityID: entityID,
                    shellPath: shellFor(entityID: entityID),
                    isZoomed: true,
                    canZoom: true,
                    onToggleZoom: {
                        withAnimation(.easeOut(duration: 0.16)) {
                            zoomedPaneIDs[entityID] = nil
                        }
                    },
                    onKill: {
                        zoomedPaneIDs[entityID] = nil
                        store.killPane(entityID: entityID, index: matchIndex)
                    },
                    onHide: {
                        zoomedPaneIDs[entityID] = nil
                        store.hidePane(entityID: entityID, index: matchIndex)
                    }
                )
                .id("zoomed-\(slot.paneId)")
                .transition(.opacity)
            }
        }
        .padding(8)
        .background(theme.windowBackground)
    }

    // MARK: - Helpers

    private func toggleSidebar() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
            sidebarPinned.toggle()
            if sidebarPinned {
                sidebarHoverVisible = false
            }
        }
    }

    private func toggleSettings(open: Bool? = nil) {
        withAnimation(.spring(response: 0.30, dampingFraction: 0.88)) {
            settingsOpen = open ?? !settingsOpen
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

    private func findSubProject(for entityID: String) -> (project: Project, sub: SubProject)? {
        for p in store.projects {
            if let sub = p.subProjects.first(where: { $0.id.uuidString == entityID }) {
                return (p, sub)
            }
        }
        return nil
    }

    private func workspaceTitle(for entityID: String) -> String {
        if entityID == "default-terminal" { return "Home Terminal" }
        if let p = store.projects.first(where: { $0.id.uuidString == entityID }) { return p.name }
        if let m = findSubProject(for: entityID) { return "\(m.project.name) / \(m.sub.name)" }
        return "Workspace"
    }

    private func activateMobileProject(for entityID: String) {
        guard let project = store.project(for: entityID), project.projectType != .unknown else {
            mobileRunController.deactivate()
            return
        }
        mobileRunController.activate(project: project)
    }

    private func handleSpawnPane(_ entityID: String) {
        store.selectedEntityID = entityID
        if let cwd = store.cwd(for: entityID) {
            _ = store.spawnPane(entityID: entityID, cwd: cwd)
        }
    }

    private func shellFor(entityID: String) -> String {
        store.projects.first { $0.id.uuidString == entityID }?.shellPath ?? ProjectStore.defaultShell
    }

    private var noSelection: some View {
        let theme = themeManager.current
        return VStack(spacing: 10) {
            Image(systemName: "terminal")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(theme.textMuted)
            Text("Chọn một workspace ở thanh bên")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundColor(theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.windowBackground)
    }
}

// MARK: - Developer Launchpad (Empty Workspace Experience)

struct WorkspaceLaunchpadView: View {
    let entityID: String
    let cwd: String
    let title: String
    let project: Project?
    let onLaunchSingle: () -> Void
    let onLaunchSplit: () -> Void
    let onLaunchAgent: (String, String) -> Void
    let onDropFolder: (String) -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var agentCommandStore: AgentCommandStore
    @State private var isDropTargeted = false

    var body: some View {
        let theme = themeManager.current
        ZStack {
            RadialGradient(
                colors: [theme.accent.opacity(0.06), Color.clear],
                center: .center,
                startRadius: 10,
                endRadius: 320
            )
            .allowsHitTesting(false)

            VStack(spacing: 24) {
                // Workspace Identity
                VStack(spacing: 10) {
                    if let project {
                        ProjectIconView(project: project, size: 46)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(theme.success.opacity(0.14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                                        .stroke(theme.success.opacity(0.28), lineWidth: 1)
                                )
                            Image(systemName: "terminal.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(theme.success)
                        }
                        .frame(width: 46, height: 46)
                    }

                    VStack(spacing: 4) {
                        Text(title)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(theme.textPrimary)

                        Text(abbreviatedHomePath(cwd))
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundColor(theme.textMuted)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                // Primary Launch Cards
                HStack(spacing: 10) {
                    LaunchpadActionCard(
                        icon: "terminal",
                        title: "Mở Terminal",
                        subtitle: "1 cửa sổ • ⌘T",
                        accent: theme.accent,
                        isPrimary: true,
                        action: onLaunchSingle
                    )

                    LaunchpadActionCard(
                        icon: "rectangle.split.2x1",
                        title: "Chia đôi màn hình",
                        subtitle: "2 terminal song song",
                        accent: theme.info,
                        isPrimary: false,
                        action: onLaunchSplit
                    )
                }
                .frame(maxWidth: 400)

                // Quick AI CLI Pills (synced from AgentCommandStore)
                VStack(spacing: 8) {
                    Text("KHỞI CHẠY NHANH AI AGENT")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(0.9)
                        .foregroundColor(theme.textMuted)

                    HStack(spacing: 8) {
                        ForEach(agentCommandStore.groups.prefix(4)) { group in
                            if let preferred = group.commands.last ?? group.commands.first {
                                AgentQuickPill(
                                    name: group.agentName,
                                    icon: group.icon,
                                    tint: Color(hex: group.colorHex)
                                ) {
                                    onLaunchAgent("\(group.shortTag) • \(preferred.title)", preferred.command)
                                }
                                .help(preferred.command)
                            }
                        }
                    }
                }

                Text(isDropTargeted ? "Thả vào đây để mở Terminal ngay" : "Mẹo: Kéo lệnh Agent từ thanh bên hoặc thư mục vào đây để mở nhanh")
                    .font(.system(size: 11))
                    .foregroundColor(isDropTargeted ? theme.accentHover : theme.textMuted.opacity(0.8))
            }
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.windowBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.accent.opacity(0.65), lineWidth: 2)
                .padding(10)
                .opacity(isDropTargeted ? 1 : 0)
                .allowsHitTesting(false)
        )
        .onDrop(of: [.fileURL, .plainText], isTargeted: $isDropTargeted) { providers in
            var accepted = false
            for provider in providers {
                if provider.canLoadObject(ofClass: URL.self) {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        guard let url else { return }
                        DispatchQueue.main.async { onDropFolder(url.path) }
                    }
                    accepted = true
                } else if provider.canLoadObject(ofClass: NSString.self) {
                    _ = provider.loadObject(ofClass: NSString.self) { obj, _ in
                        guard let raw = obj as? String,
                              let decoded = AgentCommandDragCodec.decode(raw) else { return }
                        DispatchQueue.main.async {
                            onLaunchAgent(decoded.title, decoded.command)
                        }
                    }
                    accepted = true
                }
            }
            return accepted
        }
    }
}

private struct LaunchpadActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let accent: Color
    let isPrimary: Bool
    let action: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isHovered = false

    var body: some View {
        let theme = themeManager.current
        Button(action: action) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isPrimary ? accent.opacity(0.18) : theme.surfaceElevated)
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isPrimary ? accent : theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundColor(theme.textMuted)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isHovered ? theme.surfaceElevated : theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isHovered ? accent.opacity(0.5) : theme.border, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct AgentQuickPill: View {
    let name: String
    let icon: String
    let tint: Color
    let action: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isHovered = false

    var body: some View {
        let theme = themeManager.current
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(tint)
                Text(name)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(isHovered ? theme.textPrimary : theme.textSecondary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isHovered ? theme.surfaceElevated : theme.surface)
            )
            .overlay(
                Capsule()
                    .stroke(isHovered ? tint.opacity(0.45) : theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Onboarding / First-Run Card

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

            VStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(theme.accentSoft)
                        .frame(width: 56, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(theme.accent.opacity(0.28), lineWidth: 1)
                        )
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(theme.accentHover)
                }

                VStack(spacing: 6) {
                    Text("Bắt đầu với Terminal Manager")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(theme.textPrimary)

                    Text("Thêm thư mục dự án đầu tiên để tổ chức terminal, AI agents và mobile build gọn trong một không gian duy nhất.")
                        .font(.system(size: 12.5))
                        .foregroundColor(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 330)
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
            .padding(.horizontal, 34)
            .padding(.vertical, 32)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(theme.surface))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(theme.borderStrong, lineWidth: 1))
            .shadow(color: .black.opacity(0.32), radius: 24, y: 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.windowBackground)
    }
}

// MARK: - Sleek 28pt Terminal Pane Cell (with Focus / Zoom)

struct PaneCellView: View {
    let slot: PaneSlot
    let index: Int
    let entityID: String
    let shellPath: String
    let isZoomed: Bool
    let canZoom: Bool
    let onToggleZoom: () -> Void
    let onKill: () -> Void
    let onHide: () -> Void

    @EnvironmentObject private var store: ProjectStore
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isHovered = false
    @State private var isZoomHovered = false
    @State private var isCloseHovered = false
    @State private var isHideHovered = false
    @State private var isDropTargeted = false
    @State private var isEditingName = false
    @State private var editedName = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        let theme = themeManager.current
        VStack(spacing: 0) {
            // Whisper-thin 28pt pane header
            HStack(spacing: 7) {
                Circle()
                    .fill(isHovered ? theme.accent : theme.success.opacity(0.8))
                    .frame(width: 6, height: 6)

                if isEditingName {
                    TextField("", text: $editedName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
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
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.textPrimary.opacity(0.9))
                        .lineLimit(1)
                        .onTapGesture(count: 2) {
                            editedName = slot.customName ?? "Terminal \(index + 1)"
                            isEditingName = true
                            isTextFieldFocused = true
                        }
                        .help("Nhấn đúp để đổi tên Terminal")
                }

                Spacer(minLength: 6)

                HStack(spacing: 2) {
                    if canZoom {
                        Button(action: onToggleZoom) {
                            Image(systemName: isZoomed ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(isZoomHovered || isZoomed ? theme.accentHover : theme.textMuted)
                                .frame(width: 20, height: 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                                        .fill(isZoomHovered || isZoomed ? theme.accentSoft : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                        .onHover { isZoomHovered = $0 }
                        .help(isZoomed ? "Thu về lưới" : "Phóng to Terminal này")
                    }

                    let visibleCount = store.slots(for: entityID).compactMap { $0 }.count
                    if visibleCount > 1 {
                        Button(action: onHide) {
                            Image(systemName: "eye.slash")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(isHideHovered ? theme.accentHover : theme.textMuted)
                                .frame(width: 20, height: 20)
                                .background(
                                    RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                                        .fill(isHideHovered ? theme.accentSoft : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                        .onHover { isHideHovered = $0 }
                        .help("Ẩn xuống thanh trạng thái (vẫn chạy ngầm)")
                    }

                    Button(action: onKill) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(isCloseHovered ? theme.danger : theme.textMuted)
                            .frame(width: 20, height: 20)
                            .background(
                                RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                                    .fill(isCloseHovered ? theme.danger.opacity(0.15) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { isCloseHovered = $0 }
                    .help("Đóng Terminal")
                }
                .opacity(isHovered || isZoomed || isCloseHovered || isHideHovered || isZoomHovered ? 1.0 : 0.35)
            }
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(theme.surface)
            .overlay(HairlineDivider(), alignment: .bottom)
            .zIndex(2)

            TerminalPane(
                paneId: slot.paneId,
                cwd: slot.cwd,
                shellPath: shellPath,
                startupCommand: slot.startupCommand,
                onDropHighlightChanged: { highlighted in
                    DispatchQueue.main.async {
                        isDropTargeted = highlighted
                    }
                }
            )
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(theme.terminalBackground)
            .clipped()
            .zIndex(0)
        }
        .background(theme.terminalBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isDropTargeted
                        ? theme.accent
                        : (isHovered ? theme.borderStrong : theme.border),
                    lineWidth: isDropTargeted ? 1.5 : 1
                )
                .allowsHitTesting(false)
        )
        .animation(.easeOut(duration: 0.14), value: isHovered)
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
                guard let url else { return }
                DispatchQueue.main.async {
                    if let termView = store.getTerminalView(for: slot.paneId) {
                        termView.send(txt: url.path)
                    }
                }
            }
            accepted = true
        }
        return accepted
    }
}

// MARK: - Quiet Secondary Empty Cell (for partially filled 2x2 / 2x3 grids)

struct SecondaryEmptyCellView: View {
    let onOpen: () -> Void
    var onDropOpen: (String) -> Void = { _ in }
    var onDropCommand: (String, String) -> Void = { _, _ in }
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isHovered = false
    @State private var isDropTargeted = false

    var body: some View {
        let theme = themeManager.current
        Button(action: onOpen) {
            VStack(spacing: 6) {
                Image(systemName: isDropTargeted ? "bolt.circle" : "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isHovered || isDropTargeted ? theme.accentHover : theme.textMuted)
                if isHovered || isDropTargeted {
                    Text(isDropTargeted ? "Thả để mở Terminal" : "Mở Terminal")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.textSecondary)
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isHovered || isDropTargeted ? theme.surface : theme.surface.opacity(0.32))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isDropTargeted ? theme.accent : (isHovered ? theme.borderStrong : theme.border.opacity(0.7)),
                    lineWidth: isDropTargeted ? 1.5 : 1
                )
        )
        .animation(.easeOut(duration: 0.14), value: isHovered)
        .onHover { isHovered = $0 }
        .onDrop(of: [.fileURL, .plainText], isTargeted: $isDropTargeted) { providers in
            var accepted = false
            for provider in providers {
                if provider.canLoadObject(ofClass: URL.self) {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        guard let url else { return }
                        DispatchQueue.main.async { onDropOpen(url.path) }
                    }
                    accepted = true
                } else if provider.canLoadObject(ofClass: NSString.self) {
                    _ = provider.loadObject(ofClass: NSString.self) { obj, _ in
                        guard let raw = obj as? String,
                              let decoded = AgentCommandDragCodec.decode(raw) else { return }
                        DispatchQueue.main.async { onDropCommand(decoded.title, decoded.command) }
                    }
                    accepted = true
                }
            }
            return accepted
        }
    }
}

// MARK: - Compact Status-Bar Hidden Pane Pill

struct HiddenPaneItemView: View {
    let pane: PaneSlot
    let entityID: String
    @EnvironmentObject private var store: ProjectStore
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isHovered = false
    @State private var isCloseHovered = false

    var body: some View {
        let theme = themeManager.current
        HStack(spacing: 5) {
            Circle()
                .fill(theme.success)
                .frame(width: 5, height: 5)

            Text(pane.customName ?? "Terminal")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(isHovered ? theme.textPrimary : theme.textSecondary)
                .lineLimit(1)

            Button {
                store.killHiddenPane(entityID: entityID, paneId: pane.paneId)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(isCloseHovered ? theme.danger : theme.textMuted)
                    .frame(width: 13, height: 13)
            }
            .buttonStyle(.plain)
            .onHover { isCloseHovered = $0 }
            .help("Đóng Terminal ẩn này")
        }
        .padding(.leading, 7)
        .padding(.trailing, 4)
        .padding(.vertical, 2.5)
        .background(
            Capsule()
                .fill(isHovered ? theme.surfaceElevated : theme.surfaceHover)
        )
        .overlay(
            Capsule()
                .stroke(isHovered ? theme.accent.opacity(0.45) : theme.border, lineWidth: 0.75)
        )
        .onHover { isHovered = $0 }
        .onTapGesture {
            store.restoreHiddenPane(entityID: entityID, paneId: pane.paneId)
        }
        .help("Nhấn để khôi phục Terminal đang chạy ngầm")
    }
}
