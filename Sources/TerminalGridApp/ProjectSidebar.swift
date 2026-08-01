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

struct ProjectIconView: View {
    let project: Project
    var size: CGFloat = 24

    var body: some View {
        if let path = project.customIconPath,
           let nsImage = NSImage(contentsOfFile: path) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: max(5, size * 0.22)))
                .overlay(
                    RoundedRectangle(cornerRadius: max(5, size * 0.22))
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 2, y: 1)
        } else {
            Image(systemName: "folder.fill")
                .foregroundColor(.themePrimary)
                .font(.system(size: size * 0.75))
                .frame(width: size, height: size)
        }
    }
}

struct ProjectSidebar: View {
    @EnvironmentObject private var store: ProjectStore
    let onSpawnPane: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.themePrimary)
                    Text("Terminal Manager")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Button {
                    if let url = pickFolder() {
                        store.addProject(folderURL: url)
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(AddFolderButtonStyle())
                .help("Thêm thư mục")
            }
            .padding(.horizontal, 18)
            .padding(.top, 24)
            .padding(.bottom, 14)
            
            Divider().background(Color.themeBorder)

            // Project list
            if store.projects.isEmpty {
                emptyHint
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("THƯ MỤC DỰ ÁN")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.themeTextMuted)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)

                        ForEach(store.projects) { project in
                            projectSection(project)
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
            }
        }
        .background(Color.themeSurface)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
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
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(.themeTextMuted)
            Text("Chưa có dự án nào")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.themeTextSecondary)
            Text("Kéo thả thư mục vào đây hoặc bấm nút +")
                .font(.system(size: 11))
                .foregroundColor(.themeTextMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
    }

    private func projectSection(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // Project row
            SidebarProjectRow(
                project: project,
                onSpawnPane: onSpawnPane
            )

            // Task Tree (Header "Task" with "+" icon + Child Tasks "Task 1, Task 2...")
            SidebarTaskTreeSection(
                project: project,
                onSpawnPane: onSpawnPane
            )
        }
    }
}

// ── Button styles ──

struct AddFolderButtonStyle: ButtonStyle {
    @State private var isHovered = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 28, height: 28)
            .foregroundColor(isHovered ? .themePrimaryHover : .themeTextSecondary)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.themePrimary.opacity(0.1) : Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isHovered ? Color.themePrimary.opacity(0.3) : Color.white.opacity(0.06), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .onHover { isHovered = $0 }
    }
}

struct ActionButtonStyle: ButtonStyle {
    var color: Color
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isHovered ? color : .themeTextSecondary)
            .font(.system(size: 11, weight: .bold))
            .frame(width: 24, height: 24)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? color.opacity(0.12) : Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .onHover { isHovered = $0 }
    }
}

// ── Sidebar Rows ──

struct TreeBranchConnector: View {
    let isLast: Bool
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { path in
                path.move(to: CGPoint(x: w / 2, y: 0))
                path.addLine(to: CGPoint(x: w / 2, y: isLast ? h / 2 : h))
                
                path.move(to: CGPoint(x: w / 2, y: h / 2))
                path.addLine(to: CGPoint(x: w, y: h / 2))
            }
            .stroke(Color.themeBorder, lineWidth: 1.5)
        }
        .frame(width: 14)
    }
}

struct SidebarProjectRow: View {
    let project: Project
    @EnvironmentObject var store: ProjectStore
    let onSpawnPane: (String) -> Void
    
    @State private var isHovered = false
    @State private var showingAgentPopup = false
    @State private var showSubprojectActions = false
    @State private var isIconHovered = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            HStack(spacing: 10) {
                ProjectIconView(project: project, size: 24)
                    .overlay(
                        Group {
                            if isIconHovered {
                                ZStack {
                                    Color.black.opacity(0.75)
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .transition(.opacity)
                            }
                        }
                    )
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isIconHovered = hovering
                        }
                    }
                    .onTapGesture {
                        pickAndSetIcon(for: project, store: store)
                    }
                    .help("Nhấp để upload / thay đổi Icon cho \(project.name)")
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(project.name)
                            .font(.system(size: 13.5, weight: store.selectedEntityID == project.id.uuidString ? .bold : .semibold))
                            .foregroundColor(store.selectedEntityID == project.id.uuidString ? .white : .themeTextPrimary)
                            .lineLimit(1)

                        if project.projectType != .unknown {
                            Text(project.projectType.displayName)
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(.themePrimaryHover)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.themePrimary.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                    Text(project.path)
                        .font(.system(size: 11))
                        .foregroundColor(.themeTextMuted)
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
            
            // Action buttons on the RIGHT of the same row!
            HStack(spacing: 4) {
                if showSubprojectActions {
                    Button {
                        showingAgentPopup.toggle()
                    } label: {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .buttonStyle(ActionButtonStyle(color: .themePrimary))
                    .help("Thêm Agent / Thư mục con (agy, codex, claude...)")
                    .popover(isPresented: $showingAgentPopup, arrowEdge: .top) {
                        AgentListPopupView(project: project, isOpen: $showingAgentPopup)
                            .environmentObject(store)
                    }
                    .opacity(isHovered ? 1.0 : 0.0)
                }
                
                Button {
                    onSpawnPane(store.terminalTargetEntityID(for: project.id.uuidString))
                } label: {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(ActionButtonStyle(color: .themeGreen))
                .help("Mở terminal cho \(project.name)")
                
                Button {
                    store.deleteProject(id: project.id.uuidString)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(ActionButtonStyle(color: .themeRed))
                .help("Xóa \(project.name)")
                .opacity(isHovered ? 1.0 : 0.0)
            }
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(store.selectedEntityID == project.id.uuidString ? Color.themePrimary.opacity(0.12) : (isHovered ? Color.white.opacity(0.04) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(store.selectedEntityID == project.id.uuidString ? Color.themePrimary.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
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
            
            Button {
                onSpawnPane(store.terminalTargetEntityID(for: project.id.uuidString))
            } label: {
                Label("Mở Terminal cho Project", systemImage: "plus.rectangle.on.rectangle")
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

struct SidebarTaskTreeSection: View {
    let project: Project
    @EnvironmentObject var store: ProjectStore
    let onSpawnPane: (String) -> Void
    
    @State private var isExpanded = true
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // "Task" Header Row with "+" button
            HStack(spacing: 0) {
                HStack(spacing: 6) {
                    TreeBranchConnector(isLast: project.subProjects.isEmpty || !isExpanded)
                    
                    if !project.subProjects.isEmpty {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(.themeTextMuted)
                    }
                    
                    Image(systemName: "checklist")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.themePrimaryHover)
                    
                    Text("Task")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(Color(red: 215/255, green: 220/255, blue: 230/255))
                    
                    if !project.subProjects.isEmpty {
                        Text("\(project.subProjects.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.themePrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.themePrimary.opacity(0.18))
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    if !project.subProjects.isEmpty {
                        withAnimation(.easeOut(duration: 0.15)) {
                            isExpanded.toggle()
                        }
                    }
                }
                
                // "+" Button to create Task 1, Task 2...
                Button {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    store.addNextTask(to: project.id.uuidString)
                    isExpanded = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(ActionButtonStyle(color: .themePrimary))
                .help("Tạo Task mới (Task 1, Task 2...)")
            }
            .padding(.vertical, 5)
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color.white.opacity(0.03) : Color.clear)
            )
            .onHover { isHovered = $0 }
            
            // Children Tasks (Task 1, Task 2...)
            if isExpanded && !project.subProjects.isEmpty {
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
                .padding(.leading, 24)
            }
        }
    }
}

struct SidebarSubProjectRow: View {
    let projectID: String
    let sub: SubProject
    let isLast: Bool
    @EnvironmentObject var store: ProjectStore
    let onSpawnPane: (String) -> Void
    
    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editedName = ""
    @FocusState private var isTextFieldFocused: Bool
    
    private func iconFor(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("claude") || lower.contains("gemini") || lower.contains("codex") || lower.contains("gpt") || lower.contains("agy") || lower.contains("ai") || lower.contains("openai") {
            return "sparkles"
        }
        if lower.contains("task") {
            return "terminal.fill"
        }
        return "folder.fill"
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
    
    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                TreeBranchConnector(isLast: isLast)
                
                Image(systemName: iconFor(sub.name))
                    .font(.system(size: 11))
                    .foregroundColor(store.selectedEntityID == sub.id.uuidString ? .themePrimaryHover : .themeTextSecondary)
                
                if isEditing {
                    TextField("Tên Task", text: $editedName, onCommit: {
                        commitRename()
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.themeSurface)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.themePrimary, lineWidth: 1)
                    )
                    .focused($isTextFieldFocused)
                    .onAppear {
                        isTextFieldFocused = true
                    }
                    .onChange(of: isTextFieldFocused) { focused in
                        if !focused && isEditing {
                            commitRename()
                        }
                    }
                    .onSubmit {
                        commitRename()
                    }
                    .onExitCommand {
                        isEditing = false
                        isTextFieldFocused = false
                    }
                } else {
                    Text(sub.name)
                        .font(.system(size: 12, weight: store.selectedEntityID == sub.id.uuidString ? .semibold : .medium))
                        .foregroundColor(store.selectedEntityID == sub.id.uuidString ? .white : .themeTextSecondary)
                        .lineLimit(1)
                        .layoutPriority(-1)
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    guard !isEditing else { return }
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    withTransaction(Transaction(animation: nil)) {
                        store.selectedEntityID = sub.id.uuidString
                    }
                }
            )
            .onTapGesture(count: 2) {
                startEditing()
            }

            if !isEditing {
                HStack(spacing: 2) {
                    Button {
                        store.deleteSubProject(from: projectID, subProjectID: sub.id.uuidString)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(ActionButtonStyle(color: .themeRed))
                    .help("Xóa \(sub.name)")
                    .opacity(isHovered ? 1.0 : 0.0)
                }
                .animation(.easeOut(duration: 0.15), value: isHovered)
            }
        }
        .padding(.vertical, 6)
        .padding(.leading, 6)
        .padding(.trailing, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(store.selectedEntityID == sub.id.uuidString ? Color.themePrimary.opacity(0.12) : (isHovered ? Color.white.opacity(0.03) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(store.selectedEntityID == sub.id.uuidString ? Color.themePrimary.opacity(0.3) : Color.clear, lineWidth: 1)
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
        .help("Kéo vào terminal để chèn đường dẫn \(sub.path)")
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// ── Agent List Popup Below Button ──

struct AgentListPopupView: View {
    let project: Project
    @Binding var isOpen: Bool
    @EnvironmentObject var store: ProjectStore
    
    @State private var templateList: [String] = []
    @State private var newName: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.themePrimaryHover)
                        .font(.system(size: 11))
                    Text("Agent / Thư mục con")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                Button {
                    isOpen = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.themeTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.themeSurface)
            
            Divider().background(Color.themeBorder)
            
            // List of default template items (agy, codex, claude)
            VStack(alignment: .leading, spacing: 4) {
                Text("DANH SÁCH MẶC ĐỊNH")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.themeTextMuted)
                    .padding(.bottom, 2)
                
                if templateList.isEmpty {
                    Text("Chưa có agent nào trong danh sách")
                        .font(.system(size: 11))
                        .foregroundColor(.themeTextMuted)
                        .padding(.vertical, 4)
                } else {
                    ForEach(templateList, id: \.self) { name in
                        agentItemRow(name: name)
                    }
                }
            }
            .padding(12)
            
            Divider().background(Color.themeBorder)
            
            // Add new item to template list
            HStack(spacing: 6) {
                TextField("Thêm tên agent mới...", text: $newName, onCommit: addNewItem)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(red: 35/255, green: 37/255, blue: 48/255))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.themePrimary.opacity(0.6), lineWidth: 1)
                    )
                
                Button {
                    addNewItem()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.themePrimary)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Thêm vào danh sách mặc định")
            }
            .padding(10)
            
            // Create all missing button
            if !templateList.isEmpty {
                Divider().background(Color.themeBorder)
                
                Button {
                    createAllMissing()
                } label: {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                        Text("Tạo tất cả cho dự án")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ThemeButton(isPrimary: true))
                .padding(10)
            }
        }
        .frame(width: 250)
        .background(Color(red: 15/255, green: 16/255, blue: 21/255))
        .onAppear {
            loadTemplate()
        }
    }
    
    private func agentItemRow(name: String) -> some View {
        let isCreated = project.subProjects.contains { $0.name.lowercased() == name.lowercased() }
        
        return HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11))
                .foregroundColor(isCreated ? .themeGreen : .themePrimaryHover)
            
            Text(name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            if isCreated {
                Text("Đã có")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.themeGreen)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.themeGreen.opacity(0.12))
                    .cornerRadius(4)
            } else {
                Button {
                    createSingle(name: name)
                } label: {
                    Text("+ Tạo")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.themePrimary.opacity(0.2))
                        .foregroundColor(.themePrimaryHover)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("Tạo thư mục \(name) cho dự án")
            }
            
            Button {
                deleteItemFromTemplate(name: name)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.themeRed)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help("Xóa khỏi danh sách mặc định")
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
