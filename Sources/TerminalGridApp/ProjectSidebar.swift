import SwiftUI
import AppKit
import UniformTypeIdentifiers

// ── Native folder picker helper ──
func pickFolder() -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.prompt = "Chọn thư mục"
    panel.message = "Chọn thư mục dự án"
    return panel.runModal() == .OK ? panel.url : nil
}

func pickAndSetIcon(for project: Project, store: ProjectStore) {
    let panel = NSOpenPanel()
    panel.title = "Chọn ảnh Icon cho dự án \(project.name)"
    panel.prompt = "Chọn ảnh"
    panel.allowsMultipleSelection = false
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    panel.allowedContentTypes = [.image, .png, .jpeg, .gif, .tiff, .svg, .icns]
    panel.begin { response in
        if response == .OK, let url = panel.url {
            DispatchQueue.main.async {
                store.setIcon(url: url, for: project.id.uuidString)
            }
        }
    }
}

private func projectPathItemProvider(_ path: String) -> NSItemProvider {
    let url = URL(fileURLWithPath: path).standardizedFileURL
    return NSItemProvider(object: url as NSURL)
}

func abbreviatedHomePath(_ path: String) -> String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    if path == home { return "~" }
    if path.hasPrefix(home + "/") {
        return "~" + path.dropFirst(home.count)
    }
    return path
}

func projectTypeBadgeColor(_ type: ProjectType, theme: AppTheme) -> Color {
    switch type {
    case .flutter: return theme.info
    case .androidNative: return theme.success
    case .iosNative: return theme.accent
    case .unknown: return theme.textMuted
    }
}

struct ProjectIconView: View {
    let project: Project
    var size: CGFloat = 24
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        let theme = themeManager.current
        let radius = max(5, size * 0.26)

        if let path = project.customIconPath,
           let nsImage = NSImage(contentsOfFile: path) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 0.75)
                )
                .shadow(color: Color.black.opacity(0.28), radius: 2, y: 1)
        } else {
            let tint = project.projectType == .unknown ? theme.accent : projectTypeBadgeColor(project.projectType, theme: theme)
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(tint.opacity(0.26), lineWidth: 0.75)
                    )
                Image(systemName: iconSymbol)
                    .foregroundColor(tint)
                    .font(.system(size: size * 0.50, weight: .semibold))
            }
            .frame(width: size, height: size)
        }
    }

    private var iconSymbol: String {
        switch project.projectType {
        case .flutter: return "swift"
        case .androidNative: return "cpu"
        case .iosNative: return "iphone"
        case .unknown: return "folder.fill"
        }
    }
}

// MARK: - Project Sidebar

struct ProjectSidebar: View {
    @EnvironmentObject private var store: ProjectStore
    @EnvironmentObject private var themeManager: ThemeManager
    let onSpawnPane: (String) -> Void
    @State private var isDropTargeted = false

    var body: some View {
        let theme = themeManager.current
        VStack(spacing: 0) {
            // Top Brand Header
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(theme.accentSoft)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(theme.accent.opacity(0.32), lineWidth: 0.75)
                        )
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(theme.accentHover)
                }
                .frame(width: 22, height: 22)

                Text("Terminal Manager")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                    .lineLimit(1)

                Spacer()

                Button {
                    if let url = pickFolder() {
                        store.addProject(folderURL: url)
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .buttonStyle(GlassIconButtonStyle(size: 26))
                .help("Thêm thư mục dự án")
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            HairlineDivider()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // System Terminal Section
                    VStack(alignment: .leading, spacing: 4) {
                        sidebarSectionLabel("HỆ THỐNG")
                        SidebarDefaultTerminalRow(onSpawnPane: onSpawnPane)
                    }

                    // Projects Section
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            sidebarSectionLabel("DỰ ÁN")
                            Spacer()
                            if !store.projects.isEmpty {
                                Text("\(store.projects.count)")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundColor(theme.textMuted)
                                    .padding(.trailing, 8)
                            }
                        }

                        if store.projects.isEmpty {
                            emptyHint
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(store.projects) { project in
                                    projectSection(project)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
        .background(
            ZStack {
                VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                theme.sidebarTint
            }
            .ignoresSafeArea()
        )
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(theme.accent.opacity(0.6), lineWidth: 2)
                .opacity(isDropTargeted ? 1 : 0)
                .allowsHitTesting(false)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleFolderDrop(providers)
        }
    }

    private func sidebarSectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.8)
            .foregroundColor(themeManager.current.textMuted)
            .padding(.horizontal, 8)
            .padding(.bottom, 2)
    }

    private func handleFolderDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url = url, url.hasDirectoryPath else { return }
                DispatchQueue.main.async {
                    store.addProject(folderURL: url)
                }
            }
            accepted = true
        }
        return accepted
    }

    private var emptyHint: some View {
        let theme = themeManager.current
        return VStack(spacing: 8) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(theme.textMuted)
            Text("Chưa có dự án")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.textSecondary)
            Text("Kéo thả thư mục vào đây\nhoặc nhấn nút + phía trên")
                .font(.system(size: 10.5))
                .foregroundColor(theme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.surfaceHover)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )
        )
        .padding(.top, 4)
    }

    private func projectSection(_ project: Project) -> some View {
        SidebarProjectSection(
            project: project,
            onSpawnPane: onSpawnPane
        )
    }
}

// MARK: - Action Button Style

struct ActionButtonStyle: ButtonStyle {
    var color: Color
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isHovered ? color : themeManager.current.textSecondary)
            .font(.system(size: 11, weight: .semibold))
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? color.opacity(0.15) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .onHover { isHovered = $0 }
    }
}

// MARK: - Sidebar Project Section & Rows

struct SidebarProjectSection: View {
    let project: Project
    let onSpawnPane: (String) -> Void
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isExpanded = true

    var body: some View {
        let theme = themeManager.current
        VStack(alignment: .leading, spacing: 2) {
            SidebarProjectRow(
                project: project,
                isExpanded: $isExpanded,
                onSpawnPane: onSpawnPane,
                onAddTask: {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    store.addNextTask(to: project.id.uuidString)
                    withAnimation(.easeOut(duration: 0.16)) {
                        isExpanded = true
                    }
                }
            )

            // Only show child tasks when the project actually has tasks and is expanded
            if !project.subProjects.isEmpty && isExpanded {
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(theme.border)
                        .frame(width: 1)
                        .padding(.leading, 20)
                        .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(project.subProjects.enumerated()), id: \.element.id) { index, sub in
                            SidebarSubProjectRow(
                                projectID: project.id.uuidString,
                                sub: sub,
                                isLast: index == project.subProjects.count - 1,
                                onSpawnPane: onSpawnPane
                            )
                        }
                    }
                    .padding(.leading, 8)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

struct SidebarProjectRow: View {
    let project: Project
    @Binding var isExpanded: Bool
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var themeManager: ThemeManager
    let onSpawnPane: (String) -> Void
    let onAddTask: () -> Void

    @State private var isHovered = false
    @State private var showingAgentPopup = false
    @State private var showSubprojectActions = false
    @State private var isIconHovered = false

    private var isSelected: Bool {
        store.selectedEntityID == project.id.uuidString
    }

    private var hasTasks: Bool {
        !project.subProjects.isEmpty
    }

    private var activePaneCount: Int {
        store.slots(for: project.id.uuidString).compactMap { $0 }.count
            + store.hiddenPanes(for: project.id.uuidString).count
    }

    var body: some View {
        let theme = themeManager.current
        HStack(alignment: .center, spacing: 8) {
            // Leading active indicator bar
            Capsule()
                .fill(isSelected ? theme.accent : Color.clear)
                .frame(width: 2.5, height: 18)

            HStack(spacing: 9) {
                ProjectIconView(project: project, size: 24)
                    .overlay(
                        Group {
                            if isIconHovered {
                                ZStack {
                                    Color.black.opacity(0.68)
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .transition(.opacity)
                            }
                        }
                    )
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.14)) {
                            isIconHovered = hovering
                        }
                    }
                    .onTapGesture {
                        pickAndSetIcon(for: project, store: store)
                    }
                    .help("Nhấp để thay đổi icon cho \(project.name)")

                VStack(alignment: .leading, spacing: 1.5) {
                    HStack(spacing: 5) {
                        Text(project.name)
                            .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(isSelected ? theme.textPrimary : theme.textPrimary.opacity(0.88))
                            .lineLimit(1)

                        if project.projectType != .unknown {
                            let badgeColor = projectTypeBadgeColor(project.projectType, theme: theme)
                            Text(project.projectType.displayName)
                                .font(.system(size: 8.5, weight: .semibold))
                                .foregroundColor(badgeColor)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(badgeColor.opacity(0.13))
                                .clipShape(Capsule())
                        }
                    }

                    Text(abbreviatedHomePath(project.path))
                        .font(.system(size: 10.5))
                        .foregroundColor(theme.textMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .layoutPriority(-1)

                Spacer(minLength: 4)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                NSApp.keyWindow?.makeFirstResponder(nil)
                withTransaction(Transaction(animation: nil)) {
                    store.selectDefaultEntity(for: project.id.uuidString)
                }
            }

            // Right trailing: compact counts at rest, quick actions on hover + task disclosure when tasks exist
            HStack(spacing: 3) {
                if isHovered {
                    HStack(spacing: 1) {
                        if showSubprojectActions {
                            Button {
                                showingAgentPopup.toggle()
                            } label: {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .buttonStyle(ActionButtonStyle(color: theme.accent))
                            .help("Thêm Agent / Thư mục con")
                            .popover(isPresented: $showingAgentPopup, arrowEdge: .top) {
                                AgentListPopupView(project: project, isOpen: $showingAgentPopup)
                                    .environmentObject(store)
                                    .environmentObject(themeManager)
                            }
                        }

                        Button(action: onAddTask) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(ActionButtonStyle(color: theme.accent))
                        .help("Tạo Task mới cho \(project.name)")

                        Button {
                            onSpawnPane(store.terminalTargetEntityID(for: project.id.uuidString))
                        } label: {
                            Image(systemName: "plus.rectangle.on.rectangle")
                                .font(.system(size: 10.5, weight: .semibold))
                        }
                        .buttonStyle(ActionButtonStyle(color: theme.success))
                        .help("Mở terminal cho \(project.name)")

                        Button {
                            store.deleteProject(id: project.id.uuidString)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 10.5))
                        }
                        .buttonStyle(ActionButtonStyle(color: theme.danger))
                        .help("Xóa \(project.name)")
                    }
                    .transition(.opacity)
                } else if activePaneCount > 0 {
                    Text("\(activePaneCount)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(isSelected ? theme.accentHover : theme.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? theme.accentSoft : theme.surfaceActive)
                        )
                        .transition(.opacity)
                }

                if hasTasks {
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 3) {
                            if !isHovered {
                                Text("\(project.subProjects.count)")
                                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                            }
                            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 8.5, weight: .bold))
                        }
                        .foregroundColor(theme.textMuted)
                        .padding(.horizontal, isHovered ? 5 : 6)
                        .frame(height: 20)
                        .background(
                            Capsule()
                                .fill(theme.surfaceHover)
                        )
                    }
                    .buttonStyle(.plain)
                    .help(isExpanded ? "Thu gọn \(project.subProjects.count) Task" : "Mở rộng \(project.subProjects.count) Task")
                }
            }
            .animation(.easeOut(duration: 0.14), value: isHovered)
        }
        .padding(.vertical, 7)
        .padding(.leading, 5)
        .padding(.trailing, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? theme.accentSoft : (isHovered ? theme.surfaceHover : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? theme.accent.opacity(0.30) : Color.clear, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(action: onAddTask) {
                Label("Tạo Task mới", systemImage: "plus.circle")
            }

            Button {
                onSpawnPane(store.terminalTargetEntityID(for: project.id.uuidString))
            } label: {
                Label("Mở Terminal cho Project", systemImage: "plus.rectangle.on.rectangle")
            }

            Divider()

            Button {
                pickAndSetIcon(for: project, store: store)
            } label: {
                Label("Thay đổi Icon Project...", systemImage: "photo.on.rectangle")
            }

            if project.customIconPath != nil {
                Button(role: .destructive) {
                    store.removeIcon(for: project.id.uuidString)
                } label: {
                    Label("Xóa Icon tùy chỉnh", systemImage: "trash")
                }
            }

            Divider()

            Button(role: .destructive) {
                store.deleteProject(id: project.id.uuidString)
            } label: {
                Label("Xóa Project", systemImage: "trash")
            }
        }
        .onDrag {
            projectPathItemProvider(project.path)
        }
        .help("Kéo vào terminal để chèn đường dẫn \(project.path)")
    }
}

struct SidebarSubProjectRow: View {
    let projectID: String
    let sub: SubProject
    let isLast: Bool
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var themeManager: ThemeManager
    let onSpawnPane: (String) -> Void

    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editedName = ""
    @State private var lastClickAt: Date?
    @FocusState private var isTextFieldFocused: Bool

    private var isSelected: Bool {
        store.selectedEntityID == sub.id.uuidString
    }

    private var activePaneCount: Int {
        store.slots(for: sub.id.uuidString).compactMap { $0 }.count
            + store.hiddenPanes(for: sub.id.uuidString).count
    }

    private func iconFor(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("claude") || lower.contains("gemini") || lower.contains("codex") || lower.contains("gpt") || lower.contains("agy") || lower.contains("ai") || lower.contains("openai") {
            return "sparkles"
        }
        if lower.contains("task") {
            return "terminal"
        }
        return "folder"
    }

    private func startEditing() {
        editedName = sub.name
        isEditing = true
        withTransaction(Transaction(animation: nil)) {
            store.selectedEntityID = sub.id.uuidString
        }
        DispatchQueue.main.async {
            isTextFieldFocused = true
        }
    }

    private func commitRename() {
        guard isEditing else { return }
        isEditing = false
        isTextFieldFocused = false
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed != sub.name {
            store.renameSubProject(in: projectID, subProjectID: sub.id.uuidString, newName: trimmed)
        }
    }

    private func handleClick() {
        guard !isEditing else { return }

        let now = Date()
        if let lastClickAt,
           now.timeIntervalSince(lastClickAt) <= NSEvent.doubleClickInterval {
            self.lastClickAt = nil
            startEditing()
            return
        }

        lastClickAt = now
        NSApp.keyWindow?.makeFirstResponder(nil)
        guard store.selectedEntityID != sub.id.uuidString else { return }
        withTransaction(Transaction(animation: nil)) {
            store.selectedEntityID = sub.id.uuidString
        }
    }

    var body: some View {
        let theme = themeManager.current
        HStack(spacing: 6) {
            HStack(spacing: 7) {
                Image(systemName: iconFor(sub.name))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(isSelected ? theme.accentHover : theme.textMuted)
                    .frame(width: 14)

                if isEditing {
                    TextField("Tên Task", text: $editedName, onCommit: commitRename)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(theme.accent, lineWidth: 1)
                        )
                        .focused($isTextFieldFocused)
                        .onAppear { isTextFieldFocused = true }
                        .onChange(of: isTextFieldFocused) { focused in
                            if !focused && isEditing { commitRename() }
                        }
                        .onSubmit { commitRename() }
                        .onExitCommand {
                            isEditing = false
                            isTextFieldFocused = false
                        }
                } else {
                    Text(sub.name)
                        .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? theme.textPrimary : theme.textSecondary)
                        .lineLimit(1)
                        .layoutPriority(-1)
                }

                Spacer(minLength: 4)
            }
            .contentShape(Rectangle())
            .onTapGesture { handleClick() }

            if !isEditing {
                if isHovered {
                    Button {
                        store.deleteSubProject(from: projectID, subProjectID: sub.id.uuidString)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(ActionButtonStyle(color: theme.danger))
                    .help("Xóa \(sub.name)")
                } else if activePaneCount > 0 {
                    Text("\(activePaneCount)")
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(isSelected ? theme.accentHover : theme.textMuted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(isSelected ? theme.accentSoft : theme.surfaceHover))
                }
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? theme.accentSoft : (isHovered ? theme.surfaceHover : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isSelected ? theme.accent.opacity(0.28) : Color.clear, lineWidth: 1)
        )
        .contextMenu {
            Button {
                startEditing()
            } label: {
                Label("Đổi tên Task...", systemImage: "pencil")
            }

            Button(role: .destructive) {
                store.deleteSubProject(from: projectID, subProjectID: sub.id.uuidString)
            } label: {
                Label("Xóa Task", systemImage: "trash")
            }
        }
        .onDrag {
            projectPathItemProvider(sub.path)
        }
        .help("Nhấn đúp để đổi tên • Kéo vào terminal để chèn đường dẫn")
        .onHover { isHovered = $0 }
    }
}

// MARK: - Default Terminal Row

struct SidebarDefaultTerminalRow: View {
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var themeManager: ThemeManager
    let onSpawnPane: (String) -> Void

    @State private var isHovered = false

    private var isSelected: Bool {
        store.selectedEntityID == "default-terminal"
    }

    private var activePaneCount: Int {
        store.slots(for: "default-terminal").compactMap { $0 }.count
            + store.hiddenPanes(for: "default-terminal").count
    }

    var body: some View {
        let theme = themeManager.current
        HStack(alignment: .center, spacing: 9) {
            Capsule()
                .fill(isSelected ? theme.accent : Color.clear)
                .frame(width: 2.5, height: 18)

            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(theme.success.opacity(0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(theme.success.opacity(0.26), lineWidth: 0.75)
                        )
                    Image(systemName: "terminal.fill")
                        .foregroundColor(theme.success)
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 1.5) {
                    Text("Terminal Mặc định")
                        .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? theme.textPrimary : theme.textPrimary.opacity(0.88))
                        .lineLimit(1)

                    Text("Thư mục gốc (~)")
                        .font(.system(size: 10.5))
                        .foregroundColor(theme.textMuted)
                        .lineLimit(1)
                }
                .layoutPriority(-1)

                Spacer(minLength: 4)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                NSApp.keyWindow?.makeFirstResponder(nil)
                withTransaction(Transaction(animation: nil)) {
                    store.selectedEntityID = "default-terminal"
                }
            }

            if isHovered {
                Button {
                    onSpawnPane("default-terminal")
                } label: {
                    Image(systemName: "plus.rectangle.on.rectangle")
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .buttonStyle(ActionButtonStyle(color: theme.success))
                .help("Mở terminal mặc định tại ~")
            } else if activePaneCount > 0 {
                Text("\(activePaneCount)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(isSelected ? theme.accentHover : theme.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(isSelected ? theme.accentSoft : theme.surfaceActive))
            }
        }
        .padding(.vertical, 7)
        .padding(.leading, 5)
        .padding(.trailing, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? theme.accentSoft : (isHovered ? theme.surfaceHover : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? theme.accent.opacity(0.30) : Color.clear, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Agent List Popup

struct AgentListPopupView: View {
    let project: Project
    @Binding var isOpen: Bool
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var themeManager: ThemeManager

    @State private var templateList: [String] = []
    @State private var newName: String = ""

    var body: some View {
        let theme = themeManager.current
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(theme.accentHover)
                        .font(.system(size: 11))
                    Text("Agent / Thư mục con")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                }
                Spacer()
                Button { isOpen = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(theme.surface)

            HairlineDivider()

            VStack(alignment: .leading, spacing: 4) {
                Text("DANH SÁCH MẶC ĐỊNH")
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(0.6)
                    .foregroundColor(theme.textMuted)
                    .padding(.bottom, 2)

                if templateList.isEmpty {
                    Text("Chưa có agent nào trong danh sách")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textMuted)
                        .padding(.vertical, 4)
                } else {
                    ForEach(templateList, id: \.self) { name in
                        agentItemRow(name: name)
                    }
                }
            }
            .padding(12)

            HairlineDivider()

            HStack(spacing: 6) {
                TextField("Thêm tên agent mới...", text: $newName, onCommit: addNewItem)
                    .textFieldStyle(.plain)
                    .foregroundColor(theme.textPrimary)
                    .font(.system(size: 12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(theme.borderStrong, lineWidth: 1)
                    )

                Button(action: addNewItem) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(ThemeButton(isPrimary: true, isCompact: true))
                .help("Thêm vào danh sách mặc định")
            }
            .padding(10)

            if !templateList.isEmpty {
                HairlineDivider()
                Button(action: createAllMissing) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.badge.plus")
                        Text("Tạo tất cả cho dự án")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ThemeButton(isPrimary: true, isCompact: true))
                .padding(10)
            }
        }
        .frame(width: 260)
        .background(theme.surface)
        .onAppear { loadTemplate() }
    }

    private func agentItemRow(name: String) -> some View {
        let theme = themeManager.current
        let isCreated = project.subProjects.contains { $0.name.lowercased() == name.lowercased() }

        return HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11))
                .foregroundColor(isCreated ? theme.success : theme.accentHover)

            Text(name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.textPrimary)

            Spacer()

            if isCreated {
                Text("Đã có")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(theme.success)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(theme.success.opacity(0.14))
                    .clipShape(Capsule())
            } else {
                Button { createSingle(name: name) } label: {
                    Text("+ Tạo")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.accentSoft)
                        .foregroundColor(theme.accentHover)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Button { deleteItemFromTemplate(name: name) } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10.5))
                    .foregroundColor(theme.danger)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 3)
    }

    private func loadTemplate() {
        if let saved = UserDefaults.standard.stringArray(forKey: "defaultSubprojectsTemplate"), !saved.isEmpty {
            templateList = saved
        } else {
            templateList = ["agy", "codex", "claude"]
        }
    }

    private func saveTemplate() {
        UserDefaults.standard.set(templateList, forKey: "defaultSubprojectsTemplate")
    }

    private func addNewItem() {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !templateList.contains(where: { $0.lowercased() == trimmed.lowercased() }) {
            templateList.append(trimmed)
            saveTemplate()
        }
        newName = ""
    }

    private func deleteItemFromTemplate(name: String) {
        templateList.removeAll { $0 == name }
        saveTemplate()
    }

    private func createSingle(name: String) {
        store.addSubProjects(to: project.id.uuidString, names: [name])
    }

    private func createAllMissing() {
        let missing = templateList.filter { item in
            !project.subProjects.contains { $0.name.lowercased() == item.lowercased() }
        }
        if !missing.isEmpty {
            store.addSubProjects(to: project.id.uuidString, names: missing)
        }
        isOpen = false
    }
}
