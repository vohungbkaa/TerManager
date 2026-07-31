import SwiftUI

struct PresetOption: Identifiable {
    let key: String?
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color

    var id: String { key ?? "__default_nil__" }
}

struct SettingsPopover: View {
    @Binding var isOpen: Bool
    @State private var selectedCommand: String?
    @State private var customCommand: String = ""
    @State private var templateList: [String] = []
    @State private var newTemplateName: String = ""

    private let presets: [PresetOption] = [
        PresetOption(key: nil, title: "Shell mặc định", subtitle: "/bin/zsh (mở shell bình thường)", icon: "terminal.fill", iconColor: .themeTextSecondary),
        PresetOption(key: "claude", title: "Claude Code", subtitle: "Anthropic AI Coding Assistant", icon: "sparkles", iconColor: Color(red: 234/255, green: 179/255, blue: 8/255)),
        PresetOption(key: "codex", title: "Codex AI", subtitle: "OpenAI Codex CLI Tool", icon: "cpu", iconColor: Color(red: 59/255, green: 130/255, blue: 246/255)),
        PresetOption(key: "agy", title: "Antigravity CLI", subtitle: "Google Antigravity AI Agent", icon: "bolt.fill", iconColor: .themePrimary)
    ]

    private let startCommandKey = "defaultStartCommand"
    private let templatesKey = "defaultSubprojectsTemplate"

    // Tạm thời ẩn theo yêu cầu: Mẫu thư mục con mặc định, Phím tắt hướng dẫn (đổi thành true khi cần mở lại)
    private let showHiddenSettings = false

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider().background(Color.themeBorder)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    startCommandSection
                    
                    if showHiddenSettings {
                        templatesSection
                        shortcutsSection
                    }
                }
                .padding(18)
            }

            Divider().background(Color.themeBorder)
            footerView
        }
        .frame(width: 360)
        .frame(maxHeight: .infinity)
        .background(
            ZStack {
                Color(red: 10/255, green: 11/255, blue: 15/255)
                LinearGradient(
                    colors: [
                        Color.themePrimary.opacity(0.09),
                        Color.clear,
                        Color.clear
                    ],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
            }
        )
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.65), radius: 30, x: -8, y: 8)
        .padding(.top, 56) // Tránh tuyệt đối bị tràn lên thanh tiêu đề
        .padding(.bottom, 16)
        .padding(.trailing, 16)
        .onAppear { loadSelection() }
        .onExitCommand {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                isOpen = false
            }
        }
    }

    // ── Header ──

    private var headerView: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.themePrimaryGradient)
                    .frame(width: 36, height: 36)
                    .shadow(color: Color.themePrimary.opacity(0.35), radius: 8, y: 2)

                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Thiết Lập Hệ Thống")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)

                Text("Tùy chỉnh môi trường & tác vụ tự động")
                    .font(.system(size: 11))
                    .foregroundColor(.themeTextMuted)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                    isOpen = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.themeTextSecondary)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.05))
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .help("Đóng (ESC)")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.themeSurface)
    }

    // ── Sections ──

    private var startCommandSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(icon: "terminal.fill", title: "LỆNH KHỞI ĐỘNG MẶC ĐỊNH")

            sectionCard {
                Text("Lệnh hoặc CLI tự động thực thi ngay khi mở một pane Terminal mới.")
                    .font(.system(size: 11))
                    .foregroundColor(.themeTextSecondary)

                VStack(spacing: 8) {
                    ForEach(presets) { preset in
                        PresetRowView(
                            option: preset,
                            isSelected: (selectedCommand == preset.key),
                            onSelect: {
                                selectedCommand = preset.key
                                saveSelection()
                            }
                        )
                    }
                }

                Divider()
                    .background(Color.white.opacity(0.06))
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Lệnh tùy chỉnh khác")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.themeTextSecondary)
                        Spacer()
                        if let cmd = selectedCommand, !presets.contains(where: { $0.key == cmd }) {
                            Text("Đang chọn: \(cmd)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.themePrimaryHover)
                        }
                    }

                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "command")
                                .font(.system(size: 11))
                                .foregroundColor(.themeTextMuted)

                            TextField("vd: gemini, nvim, tmux...", text: $customCommand)
                                .font(.system(size: 12, design: .monospaced))
                                .textFieldStyle(.plain)
                                .foregroundColor(.white)
                                .onSubmit { applyCustomCommand() }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )

                        Button {
                            applyCustomCommand()
                        } label: {
                            Text("Áp dụng")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .buttonStyle(ThemeButton(isPrimary: !customCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                        .disabled(customCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(icon: "folder.fill.badge.gearshape", title: "MẪU THƯ MỤC CON MẶC ĐỊNH")

            sectionCard {
                Text("Danh sách mẫu hiển thị nhanh khi tạo tác vụ AI hoặc thư mục con.")
                    .font(.system(size: 11))
                    .foregroundColor(.themeTextSecondary)

                if templateList.isEmpty {
                    Text("Chưa có mẫu nào.")
                        .font(.system(size: 11))
                        .foregroundColor(.themeTextMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(templateList, id: \.self) { name in
                            TemplateChipView(
                                name: name,
                                onDelete: {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        templateList.removeAll { $0.lowercased() == name.lowercased() }
                                        saveTemplates()
                                    }
                                }
                            )
                        }
                    }
                }

                Divider()
                    .background(Color.white.opacity(0.06))
                    .padding(.vertical, 2)

                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 12))
                            .foregroundColor(.themePrimaryHover)

                        TextField("Thêm mẫu mới (vd: gemini)...", text: $newTemplateName)
                            .font(.system(size: 12))
                            .textFieldStyle(.plain)
                            .foregroundColor(.white)
                            .onSubmit { addTemplate() }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                    Button {
                        addTemplate()
                    } label: {
                        Text("+ Thêm")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .buttonStyle(ThemeButton(isPrimary: !newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    .disabled(newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(icon: "keyboard.fill", title: "PHÍM TẮT & HƯỚNG DẪN")

            sectionCard {
                ShortcutRowView(shortcut: "⌘ + W", description: "Đóng terminal pane đang chọn")
                ShortcutRowView(shortcut: "ESC", description: "Đóng bảng thiết lập hệ thống")
                ShortcutRowView(shortcut: "Kéo & Thả", description: "Thả thư mục vào ô trống để mở terminal")
                ShortcutRowView(shortcut: "Click ô trống", description: "Tạo terminal mới tại thư mục hiện tại")
            }
        }
    }

    // ── Footer ──

    private var footerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("TerManager v1.0")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.themeTextSecondary)
                Text("macOS Native Terminal Grid")
                    .font(.system(size: 10))
                    .foregroundColor(.themeTextMuted)
            }

            Spacer()

            Button {
                resetToDefaults()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .bold))
                    Text("Khôi phục mặc định")
                }
            }
            .buttonStyle(ThemeButton(isPrimary: false))
            .help("Đặt lại về cấu hình mặc định ban đầu")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color.themeSurface)
    }

    // ── Helper Views ──

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.themePrimaryHover)

            Text(title)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundColor(.themeTextMuted)
                .kerning(0.5)

            Spacer()
        }
        .padding(.bottom, 2)
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.themeSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // ── Logic ──

    private func loadSelection() {
        selectedCommand = UserDefaults.standard.string(forKey: startCommandKey)
        if let cmd = selectedCommand, !presets.contains(where: { $0.key == cmd }) {
            customCommand = cmd
        } else {
            customCommand = ""
        }

        if let saved = UserDefaults.standard.stringArray(forKey: templatesKey), !saved.isEmpty {
            templateList = saved
        } else {
            templateList = ["agy", "codex", "claude"]
        }
    }

    private func saveSelection() {
        if let cmd = selectedCommand, !cmd.isEmpty {
            UserDefaults.standard.set(cmd, forKey: startCommandKey)
        } else {
            UserDefaults.standard.removeObject(forKey: startCommandKey)
        }
    }

    private func saveTemplates() {
        UserDefaults.standard.set(templateList, forKey: templatesKey)
    }

    private func applyCustomCommand() {
        let trimmed = customCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        selectedCommand = trimmed
        saveSelection()
    }

    private func addTemplate() {
        let trimmed = newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !templateList.contains(where: { $0.lowercased() == trimmed.lowercased() }) {
            withAnimation(.easeInOut(duration: 0.15)) {
                templateList.append(trimmed)
            }
            saveTemplates()
        }
        newTemplateName = ""
    }

    private func resetToDefaults() {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedCommand = nil
            customCommand = ""
            templateList = ["agy", "codex", "claude"]
            saveSelection()
            saveTemplates()
        }
    }
}

// ── Sub-components ──

struct PresetRowView: View {
    let option: PresetOption
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? option.iconColor.opacity(0.2) : Color.white.opacity(0.04))
                        .frame(width: 32, height: 32)

                    Image(systemName: option.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSelected ? option.iconColor : .themeTextSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .themeTextPrimary)

                    Text(option.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.themeTextMuted)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isSelected ? .themePrimaryHover : .themeTextMuted.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.themePrimary.opacity(0.12) : (isHovered ? Color.white.opacity(0.04) : Color.white.opacity(0.015)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.themePrimary.opacity(0.45) : (isHovered ? Color.white.opacity(0.12) : Color.white.opacity(0.05)), lineWidth: 1)
        )
        .onHover { h in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = h
            }
        }
    }
}

struct TemplateChipView: View {
    let name: String
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11))
                .foregroundColor(.themePrimaryHover)

            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(isHovered ? .themeRed : .themeTextMuted)
            }
            .buttonStyle(.plain)
            .help("Xóa mẫu này")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.themePrimary.opacity(0.14))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(isHovered ? Color.themeRed.opacity(0.5) : Color.themePrimary.opacity(0.35), lineWidth: 1)
        )
        .onHover { h in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = h
            }
        }
    }
}

struct ShortcutRowView: View {
    let shortcut: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Text(description)
                .font(.system(size: 11.5))
                .foregroundColor(.themeTextSecondary)

            Spacer()

            Text(shortcut)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
        .padding(.vertical, 3)
    }
}
