import SwiftUI

struct SubProjectCreationView: View {
    let project: Project
    @Binding var isPresented: Bool
    @EnvironmentObject var store: ProjectStore
    @EnvironmentObject var themeManager: ThemeManager

    @State private var subNames: [String] = []
    @State private var newSubName = ""
    @State private var saveAsDefault = true
    @State private var error: String? = nil

    var body: some View {
        let theme = themeManager.current
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Quản lý Agent / Thư mục con cho \(project.name)")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(theme.textPrimary)
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10.5, weight: .bold))
                }
                .buttonStyle(GlassIconButtonStyle(size: 24))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(theme.surface)

            HairlineDivider()

            // Body
            VStack(alignment: .leading, spacing: 15) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Các thư mục Agent sẽ được tạo trực tiếp bên trong:")
                        .font(.system(size: 11.5))
                        .foregroundColor(theme.textSecondary)

                    Text(abbreviatedHomePath(project.path))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(theme.textMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.terminalBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(theme.border, lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Tên Agent / Thư mục con mới")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.textSecondary)

                    HStack(spacing: 8) {
                        TextField("Ví dụ: claude, codex, gemini", text: $newSubName, onCommit: handleAddName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundColor(theme.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(theme.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .stroke(theme.borderStrong, lineWidth: 1)
                            )

                        Button("Thêm") {
                            handleAddName()
                        }
                        .buttonStyle(ThemeButton(isPrimary: false, isCompact: true))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Danh sách sẽ tạo")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.textSecondary)

                    ScrollView {
                        if subNames.isEmpty {
                            Text("Chưa có dự án con nào được thêm.")
                                .font(.system(size: 12))
                                .foregroundColor(theme.textMuted)
                                .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                                ForEach(subNames, id: \.self) { name in
                                    HStack(spacing: 5) {
                                        Text(name)
                                            .font(.system(size: 11.5, weight: .medium))
                                            .foregroundColor(theme.textPrimary)
                                        Button {
                                            subNames.removeAll { $0 == name }
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 8.5, weight: .bold))
                                                .foregroundColor(theme.textSecondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4.5)
                                    .background(theme.accentSoft)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(theme.accent.opacity(0.35), lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .frame(height: 80)
                    .padding(8)
                    .background(theme.surfaceHover)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    )
                }

                Toggle(isOn: $saveAsDefault) {
                    Text("Lưu danh sách này làm mặc định cho các dự án khác")
                        .font(.system(size: 11.5))
                        .foregroundColor(theme.textSecondary)
                }
                .toggleStyle(.checkbox)

                if let error = error {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(theme.danger)
                        Text(error)
                            .font(.system(size: 11.5))
                            .foregroundColor(theme.danger)
                    }
                }
            }
            .padding(16)

            HairlineDivider()

            HStack(spacing: 10) {
                Spacer()
                Button("Hủy") {
                    isPresented = false
                }
                .buttonStyle(ThemeButton(isPrimary: false, isCompact: true))

                Button("Xác nhận tạo") {
                    handleSubmit()
                }
                .buttonStyle(ThemeButton(isPrimary: true, isCompact: true))
                .disabled(subNames.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(theme.surface)
        }
        .frame(width: 440)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.borderStrong, lineWidth: 1)
        )
        .onAppear {
            let existing = project.subProjects.map { $0.name }
            if !existing.isEmpty {
                subNames = existing
            } else {
                subNames = UserDefaults.standard.stringArray(forKey: "defaultSubprojectsTemplate") ?? ["claude", "codex", "gemini"]
            }
        }
    }

    private func handleAddName() {
        let trimmed = newSubName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if subNames.contains(trimmed) {
            error = "Dự án con \"\(trimmed)\" đã có trong danh sách."
            return
        }
        subNames.append(trimmed)
        newSubName = ""
        error = nil
    }

    private func handleSubmit() {
        guard !subNames.isEmpty else {
            error = "Vui lòng thêm ít nhất một tên dự án con."
            return
        }

        if saveAsDefault {
            UserDefaults.standard.set(subNames, forKey: "defaultSubprojectsTemplate")
        }

        store.setSubProjects(for: project.id.uuidString, names: subNames)
        isPresented = false
    }
}
