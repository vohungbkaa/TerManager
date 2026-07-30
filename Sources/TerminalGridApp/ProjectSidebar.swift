import SwiftUI
import AppKit

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

struct ProjectSidebar: View {
    @EnvironmentObject private var store: ProjectStore
    let onSpawnPane: (String) -> Void

    @State private var showingSubSheet = false
    @State private var targetProject: Project? = nil

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
            .padding(.vertical, 16)
            
            Divider().background(Color.themeBorder)

            // Project list
            if store.projects.isEmpty {
                emptyHint
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
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
            }
        }
        .background(Color.themeSurface)
        .sheet(isPresented: $showingSubSheet) {
            if let project = targetProject {
                SubProjectCreationView(project: project, isPresented: $showingSubSheet)
                    .environmentObject(store)
            }
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(.themeTextMuted)
            Text("Chưa có dự án")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.themeTextSecondary)
            Text("Bấm + để thêm thư mục")
                .font(.system(size: 11))
                .foregroundColor(.themeTextMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func projectSection(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // Project row
            SidebarProjectRow(
                project: project,
                onSpawnPane: onSpawnPane,
                onManageSubprojects: { proj in
                    targetProject = proj
                    showingSubSheet = true
                }
            )

            // SubProjects
            if !project.subProjects.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(project.subProjects) { sub in
                        SidebarSubProjectRow(projectID: project.id.uuidString, sub: sub, onSpawnPane: onSpawnPane)
                    }
                }
                .padding(.leading, 14)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(Color.themeBorder)
                        .frame(width: 1)
                        .padding(.vertical, 4)
                }
                .padding(.leading, 20)
            }
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

struct SidebarProjectRow: View {
    let project: Project
    @EnvironmentObject var store: ProjectStore
    let onSpawnPane: (String) -> Void
    let onManageSubprojects: (Project) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Main click area
            HStack(spacing: 10) {
                Image(systemName: "folder")
                    .font(.system(size: 14))
                    .foregroundColor(store.selectedEntityID == project.id.uuidString ? .themePrimaryHover : .themeTextMuted)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(store.selectedEntityID == project.id.uuidString ? .white : Color(red: 229/255, green: 231/255, blue: 235/255))
                        .lineLimit(1)
                    Text(project.path)
                        .font(.system(size: 10.5))
                        .foregroundColor(.themeTextMuted)
                        .lineLimit(1)
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                store.selectedEntityID = project.id.uuidString
            }
            
            // Action buttons
            HStack(spacing: 2) {
                Button {
                    onManageSubprojects(project)
                } label: {
                    Image(systemName: "square.3.layers.3d")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(ActionButtonStyle(color: .themePrimary))
                .help("Dự án con")
                
                Button {
                    onSpawnPane(project.id.uuidString)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(ActionButtonStyle(color: .themeGreen))
                .help("Mở terminal")
                
                Button {
                    store.deleteProject(id: project.id.uuidString)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                }
                .buttonStyle(ActionButtonStyle(color: .themeRed))
                .help("Xoá")
            }
            .opacity(isHovered ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .padding(.vertical, 8)
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(store.selectedEntityID == project.id.uuidString ? Color.themePrimary.opacity(0.07) : (isHovered ? Color.white.opacity(0.03) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(store.selectedEntityID == project.id.uuidString ? Color.themePrimary.opacity(0.18) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct SidebarSubProjectRow: View {
    let projectID: String
    let sub: SubProject
    @EnvironmentObject var store: ProjectStore
    let onSpawnPane: (String) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "folder")
                    .font(.system(size: 12))
                    .foregroundColor(store.selectedEntityID == sub.id.uuidString ? .themePrimaryHover : .themeTextMuted)
                
                Text(sub.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(store.selectedEntityID == sub.id.uuidString ? .white : Color(red: 201/255, green: 204/255, blue: 211/255))
                    .lineLimit(1)
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                store.selectedEntityID = sub.id.uuidString
            }
            
            HStack(spacing: 2) {
                Button {
                    onSpawnPane(sub.id.uuidString)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(ActionButtonStyle(color: .themeGreen))
                
                Button {
                    store.deleteSubProject(from: projectID, subProjectID: sub.id.uuidString)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .buttonStyle(ActionButtonStyle(color: .themeRed))
            }
            .opacity(isHovered ? 1.0 : 0.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
        }
        .padding(.vertical, 6)
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(store.selectedEntityID == sub.id.uuidString ? Color.themePrimary.opacity(0.05) : (isHovered ? Color.white.opacity(0.03) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(store.selectedEntityID == sub.id.uuidString ? Color.themePrimary.opacity(0.12) : Color.clear, lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
