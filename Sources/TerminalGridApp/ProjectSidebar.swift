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

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("Projects", systemImage: "terminal")
                    .font(.headline.weight(.semibold))
                Spacer()
                Button {
                    if let url = pickFolder() { store.addProject(folderURL: url) }
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.plain)
                .help("Thêm thư mục")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            // Project list
            if store.projects.isEmpty {
                emptyHint
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Text("THƯ MỤC DỰ ÁN")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)

                        ForEach(store.projects) { project in
                            projectSection(project)
                        }
                    }
                }
            }
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("Chưa có dự án")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Bấm + để thêm thư mục")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func projectSection(_ project: Project) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Project row
            projectRow(project)

            // SubProjects
            if !project.subProjects.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(project.subProjects) { sub in
                        subProjectRow(projectID: project.id.uuidString, sub: sub)
                    }
                }
            }
        }
    }

    private func projectRow(_ project: Project) -> some View {
        HStack(spacing: 0) {
            // Main click area
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.system(size: 13))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 1) {
                    Text(project.name)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Text(project.path)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .onTapGesture {
                store.selectedEntityID = project.id.uuidString
            }

            // Action buttons
            projectActions(project)
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .background(
            store.selectedEntityID == project.id.uuidString
                ? Color.accentColor.opacity(0.15)
                : Color.clear
        )
        .overlay(alignment: .leading) {
            if store.selectedEntityID == project.id.uuidString {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor)
                    .frame(width: 3)
            }
        }
    }

    private func projectActions(_ project: Project) -> some View {
        HStack(spacing: 2) {
            // Manage subprojects
            Button {
                showSubProjectSheet(for: project)
            } label: {
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Dự án con")

            // Spawn terminal
            Button {
                onSpawnPane(project.id.uuidString)
            } label: {
                Image(systemName: "plus.square")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Mở terminal")

            // Delete
            Button {
                store.deleteProject(id: project.id.uuidString)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Xoá")
        }
        .opacity(0.5)
    }

    private func subProjectRow(projectID: String, sub: SubProject) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text(sub.name)
                    .font(.system(size: 11))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.leading, 24)
            .contentShape(Rectangle())
            .onTapGesture {
                store.selectedEntityID = sub.id.uuidString
            }

            HStack(spacing: 2) {
                Button {
                    onSpawnPane(sub.id.uuidString)
                } label: {
                    Image(systemName: "plus.square")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)

                Button {
                    store.deleteSubProject(from: projectID, subProjectID: sub.id.uuidString)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
            }
            .opacity(0.4)
            .padding(.trailing, 4)
        }
        .background(
            store.selectedEntityID == sub.id.uuidString
                ? Color.accentColor.opacity(0.12)
                : Color.clear
        )
    }

    // ── SubProject management ──

    @State private var showingSubSheet = false
    @State private var subProjectProjectID: String = ""
    @State private var subProjectNames = ""

    private func showSubProjectSheet(for project: Project) {
        subProjectProjectID = project.id.uuidString
        subProjectNames = ""
        showingSubSheet = true
    }

    private var subSheet: some View {
        VStack(spacing: 12) {
            Text("Tạo dự án con").font(.headline)
            TextField("Tên (cách nhau bằng dấu phẩy)", text: $subProjectNames)
                .frame(width: 280)
            Text("vd: claude, agy, codex")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Huỷ") { showingSubSheet = false }
                Button("Tạo") {
                    let names = subProjectNames
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                    store.addSubProjects(to: subProjectProjectID, names: names)
                    showingSubSheet = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(subProjectNames.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .onAppear { subProjectNames = "" }
    }
}
