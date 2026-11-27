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
    var size: CGFloat = 20
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        let theme = themeManager.current
        let radius = max(4.5, size * 0.26)

        if let path = project.customIconPath,
           let nsImage = NSImage(contentsOfFile: path) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 0.5)
                )
        } else {
            let tint = project.projectType == .unknown ? theme.accent : projectTypeBadgeColor(project.projectType, theme: theme)
            ZStack {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(tint.opacity(0.15))
                Image(systemName: iconSymbol)
                    .foregroundColor(tint)
                    .font(.system(size: size * 0.52, weight: .semibold))
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

// MARK: - Project Sidebar (Arc / Linear Style)

struct ProjectSidebar: View {
    @EnvironmentObject private var store: ProjectStore
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var isPinned: Bool
    var isFloating: Bool = false
    let onSpawnPane: (String) -> Void
    let onToggleSettings: () -> Void

    @State private var isDropTargeted = false
    @State private var searchQuery = ""

    private var filteredProjects: [Project] {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return store.projects }
        return store.projects.filter { project in
            project.name.localizedCaseInsensitiveContains(trimmed)
                || project.subProjects.contains { $0.name.localizedCaseInsensitiveContains(trimmed) }
        }
    }

    var body: some View {
        let theme = themeManager.current
        VStack(spacing: 0) {
            // Top Header Zone (40pt when docked behind traffic lights, 38pt when floating)
            HStack(spacing: 6) {
                if isFloating {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.accentHover)
                    Text("Workspaces")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                }

                Spacer() // When docked, macOS traffic lights occupy the leading ~72pt

                Button {
                    if let url = pickFolder() {
                        store.addProject(folderURL: url)
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11.5, weight: .semibold))
                }
                .buttonStyle(GlassIconButtonStyle(size: 24))
                .help("Thêm thư mục dự án")

                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        isPinned.toggle()
                    }
                } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 10.5, weight: .medium))
                }
                .buttonStyle(GlassIconButtonStyle(active: isPinned, size: 24))
                .help(isPinned ? "Bỏ ghim Sidebar (tự ẩn khi rời chuột • ⌘\\)" : "Ghim cố định Sidebar (⌘\\)")
            }
            .padding(.horizontal, 10)
            .frame(height: isFloating ? 38 : 40)

            if isFloating {
                HairlineDivider()
            }

            // Quick Filter (appears when there are 4+ projects or user is searching)
            if store.projects.count >= 4 || !searchQuery.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(theme.textMuted)
                    TextField("Lọc dự án...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5))
                        .foregroundColor(theme.textPrimary)
                    if !searchQuery.isEmpty {
                        Button { searchQuery = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundColor(theme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .frame(height: 27)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(theme.surfaceHover)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }

            // Main Scrollable Workspace List
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    // System Terminal (Home ~)
                    VStack(alignment: .leading, spacing: 2) {
                        SidebarDefaultTerminalRow(onSpawnPane: onSpawnPane)
                    }

                    // Workspaces / Projects
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("WORKSPACES")
                                .font(.system(size: 9.5, weight: .semibold))
                                .tracking(0.9)
                                .foregroundColor(theme.textMuted)
                            Spacer()
                            if !store.projects.isEmpty {
                                Text("\(store.projects.count)")
                                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                    .foregroundColor(theme.textMuted)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 2)

                        if store.projects.isEmpty {
                            emptyHint
                        } else if filteredProjects.isEmpty {
                            Text("Không tìm thấy dự án phù hợp")
                                .font(.system(size: 11))
                                .foregroundColor(theme.textMuted)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                ForEach(filteredProjects) { project in
                                    SidebarProjectSection(
                                        project: project,
                                        onSpawnPane: onSpawnPane
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }

            HairlineDivider()

            // Anchored Bottom Footer Dock: Instant 4-Theme Swatch + Settings
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    ForEach(AppTheme.allThemes, id: \.id) { option in
                        let selected = themeManager.currentID == option.id
                        Button {
                            themeManager.select(option.id)
                        } label: {
                            Circle()
                                .fill(option.accent)
                                .frame(width: selected ? 10 : 8, height: selected ? 10 : 8)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(selected ? 0.85 : 0.15), lineWidth: selected ? 1.5 : 0.75)
                                )
                                .frame(width: 14, height: 14)
                        }
                        .buttonStyle(.plain)
                        .help("Theme: \(option.name)")
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Capsule().fill(theme.surfaceHover))

                Spacer()

                Button(action: onToggleSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(GlassIconButtonStyle(size: 26))
                .help("Thiết lập & Giao diện (⌘,)")
            }
            .padding(.horizontal, 10)
            .frame(height: 40)
        }
        .background(
            Group {
                if isFloating {
                    ZStack {
                        VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                        theme.surface.opacity(0.86)
                    }
                } else {
                    ZStack {
                        VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                        theme.sidebarTint
                    }
                    .ignoresSafeArea()
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: isFloating ? 12 : 0, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: isFloating ? 12 : 0, style: .continuous)
                .stroke(
                    isDropTargeted ? theme.accent.opacity(0.65) : (isFloating ? theme.borderStrong : Color.clear),
                    lineWidth: isDropTargeted ? 2 : 1
                )
                .allowsHitTesting(false)
        )
        .shadow(color: isFloating ? .black.opacity(0.45) : .clear, radius: isFloating ? 22 : 0, x: 6, y: 6)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleFolderDrop(providers)
        }
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
        return VStack(spacing: 6) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 20, weight: .light))
                .foregroundColor(theme.textMuted)
            Text("Kéo thả thư mục vào đây")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.textSecondary)
            Text("hoặc nhấn + ở góc trên")
                .font(.system(size: 10))
                .foregroundColor(theme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(theme.surfaceHover)
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )
        )
        .padding(.top, 4)
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
            .font(.system(size: 10.5, weight: .semibold))
            .frame(width: 20, height: 20)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isHovered ? color.opacity(0.16) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .onHover { isHovered = $0 }
    }
}

// MARK: - Sidebar Project Section & Clean Tree Rows

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
                    withAnimation(.easeOut(duration: 0.15)) {
                        isExpanded = true
                    }
                }
            )

            if !project.subProjects.isEmpty && isExpanded {
                HStack(spacing: 0) {
                    // Subtle vertical guide aligned neatly under the project icon
                    Rectangle()
                        .fill(theme.border)
                        .frame(width: 1)
                        .padding(.leading, 27)
                        .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 1) {
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
                .padding(.bottom, 4)
                .transition(.opacity)
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
        HStack(alignment: .center, spacing: 4) {
            // Left disclosure rail (fixed 14pt so all project icons stay razor-aligned)
            Group {
                if hasTasks {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(isHovered ? theme.textSecondary : theme.textMuted)
                            .frame(width: 14, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(isExpanded ? "Thu gọn" : "Mở rộng (\(project.subProjects.count) Task)")
                } else {
                    Spacer().frame(width: 14)
                }
            }

            // Icon + Name
            HStack(spacing: 8) {
                ProjectIconView(project: project, size: 18)
                    .overlay(
                        Group {
                            if isIconHovered {
                                ZStack {
                                    Color.black.opacity(0.68)
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
                                .transition(.opacity)
                            }
                        }
                    )
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.12)) {
                            isIconHovered = hovering
                        }
                    }
                    .onTapGesture {
                        pickAndSetIcon(for: project, store: store)
                    }
                    .help("Nhấp để thay đổi icon")

                Text(project.name)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? theme.textPrimary : theme.textPrimary.opacity(0.84))
                    .lineLimit(1)
                    .layoutPriority(-1)

                Spacer(minLength: 2)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                NSApp.keyWindow?.makeFirstResponder(nil)
                withTransaction(Transaction(animation: nil)) {
                    store.selectDefaultEntity(for: project.id.uuidString)
                }
            }

            // Calm right side: 1 subtle metric at rest, 2 clean actions on hover (+ and ⋯)
            if isHovered {
                HStack(spacing: 1) {
                    Button {
                        onSpawnPane(store.terminalTargetEntityID(for: project.id.uuidString))
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(ActionButtonStyle(color: theme.success))
                    .help("Mở terminal mới")

                    Menu {
                        Button(action: onAddTask) {
                            Label("Tạo Task mới", systemImage: "plus.circle")
                        }
                        Button {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.path)
                        } label: {
                            Label("Mở trong Finder", systemImage: "folder")
                        }
                        Button {
                            pickAndSetIcon(for: project, store: store)
                        } label: {
                            Label("Thay đổi Icon...", systemImage: "photo.on.rectangle")
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
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.textSecondary)
                            .frame(width: 20, height: 20)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .frame(width: 20, height: 20)
                    .help("Tùy chọn khác")
                }
            } else if activePaneCount > 0 {
                Text("\(activePaneCount)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(isSelected ? theme.accentHover : theme.textMuted)
                    .padding(.trailing, 4)
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 6)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isSelected ? theme.surfaceActive : (isHovered ? theme.surfaceHover : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(isSelected ? theme.borderStrong : Color.clear, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(action: onAddTask) {
                Label("Tạo Task mới", systemImage: "plus.circle")
            }

            Button {
                onSpawnPane(store.terminalTargetEntityID(for: project.id.uuidString))
            } label: {
                Label("Mở Terminal mới", systemImage: "plus.rectangle.on.rectangle")
            }

            Button {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.path)
            } label: {
                Label("Mở trong Finder", systemImage: "folder")
            }

            Divider()

            Button {
                pickAndSetIcon(for: project, store: store)
            } label: {
                Label("Thay đổi Icon...", systemImage: "photo.on.rectangle")
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
        .help("\(abbreviatedHomePath(project.path)) • Kéo vào terminal để chèn đường dẫn")
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
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isSelected ? theme.accentHover : theme.textMuted)
                    .frame(width: 13)

                if isEditing {
                    TextField("Tên Task", text: $editedName, onCommit: commitRename)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
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
        .padding(.horizontal, 8)
        .frame(height: 27)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? theme.surfaceActive : (isHovered ? theme.surfaceHover : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(isSelected ? theme.border : Color.clear, lineWidth: 1)
        )
        .contextMenu {
            Button { startEditing() } label: {
                Label("Đổi tên Task...", systemImage: "pencil")
            }
            Button(role: .destructive) {
                store.deleteSubProject(from: projectID, subProjectID: sub.id.uuidString)
            } label: {
                Label("Xóa Task", systemImage: "trash")
            }
        }
        .onDrag { projectPathItemProvider(sub.path) }
        .help("Nhấn đúp để đổi tên • Kéo vào terminal để chèn đường dẫn")
        .onHover { isHovered = $0 }
    }
}

// MARK: - Default Terminal Row (Compact Single-Line)

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
        HStack(alignment: .center, spacing: 4) {
            Spacer().frame(width: 14)

            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                        .fill(theme.success.opacity(0.15))
                    Image(systemName: "terminal.fill")
                        .foregroundColor(theme.success)
                        .font(.system(size: 9.5, weight: .semibold))
                }
                .frame(width: 18, height: 18)

                Text("Home (~)")
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? theme.textPrimary : theme.textPrimary.opacity(0.84))
                    .lineLimit(1)

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
                    Image(systemName: "plus")
                }
                .buttonStyle(ActionButtonStyle(color: theme.success))
                .help("Mở terminal tại ~")
            } else if activePaneCount > 0 {
                Text("\(activePaneCount)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(isSelected ? theme.accentHover : theme.textMuted)
                    .padding(.trailing, 4)
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 6)
        .frame(height: 30)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isSelected ? theme.surfaceActive : (isHovered ? theme.surfaceHover : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(isSelected ? theme.borderStrong : Color.clear, lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .help("Terminal hệ thống tại thư mục gốc (~)")
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
