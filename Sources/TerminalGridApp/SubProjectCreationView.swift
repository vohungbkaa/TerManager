import SwiftUI

struct SubProjectCreationView: View {
    let project: Project
    @Binding var isPresented: Bool
    @EnvironmentObject var store: ProjectStore
    
    @State private var subNames: [String] = []
    @State private var newSubName = ""
    @State private var saveAsDefault = true
    @State private var error: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Quản lý Agent / Thư mục con cho \(project.name)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.themeTextSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.themeSurface)
            
            Divider().background(Color.themeBorder)
            
            // Body
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Các thư mục Agent sẽ được tạo trực tiếp dưới dạng cây bên trong:")
                        .font(.system(size: 12))
                        .foregroundColor(.themeTextSecondary)
                    
                    Text(project.path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.themeTextMuted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(4)
                }
                
                // Form input
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tên Agent / Thư mục con mới")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.themeTextSecondary)
                    
                    HStack(spacing: 8) {
                        TextField("Ví dụ: claude, codex, gemini", text: $newSubName, onCommit: handleAddName)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.2))
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        
                        Button("Thêm") {
                            handleAddName()
                        }
                        .buttonStyle(ThemeButton(isPrimary: false))
                    }
                }
                
                // Tags list
                VStack(alignment: .leading, spacing: 6) {
                    Text("Danh sách sẽ tạo")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.themeTextSecondary)
                    
                    ScrollView {
                        if subNames.isEmpty {
                            Text("Chưa có dự án con nào được thêm.")
                                .font(.system(size: 12))
                                .foregroundColor(.themeTextMuted)
                                .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                                ForEach(subNames, id: \.self) { name in
                                    HStack(spacing: 4) {
                                        Text(name)
                                            .font(.system(size: 11, weight: .medium))
                                            .foregroundColor(.white)
                                        Button {
                                            subNames.removeAll { $0 == name }
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.themePrimary.opacity(0.15))
                                    .cornerRadius(4)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.themePrimary.opacity(0.35), lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .frame(height: 80)
                    .padding(8)
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                }
                
                // Checkbox
                Toggle(isOn: $saveAsDefault) {
                    Text("Lưu danh sách này làm mặc định cho các dự án khác")
                        .font(.system(size: 12))
                        .foregroundColor(.themeTextSecondary)
                }
                .toggleStyle(.checkbox)
                
                if let error = error {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundColor(.themeRed)
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundColor(.themeRed)
                    }
                }
            }
            .padding(16)
            
            Divider().background(Color.themeBorder)
            
            // Footer
            HStack(spacing: 12) {
                Spacer()
                Button("Hủy") {
                    isPresented = false
                }
                .buttonStyle(ThemeButton(isPrimary: false))
                
                Button("Xác nhận tạo") {
                    handleSubmit()
                }
                .buttonStyle(ThemeButton(isPrimary: true))
                .disabled(subNames.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.themeSurface)
        }
        .frame(width: 440)
        .background(Color.themeSurface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.themeBorder, lineWidth: 1)
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
