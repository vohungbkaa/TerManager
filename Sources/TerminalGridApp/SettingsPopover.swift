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
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var selectedCommand: String?
    @State private var customCommand: String = ""
    @State private var templateList: [String] = []
    @State private var newTemplateName: String = ""
    @State private var fontSize: Double = TerminalFontSize.defaultSize

    private let startCommandKey = "defaultStartCommand"
    private let templatesKey = "defaultSubprojectsTemplate"
    private let showHiddenSettings = false

    private var presets: [PresetOption] {
        let theme = themeManager.current
        return [
            PresetOption(key: nil, title: "Shell mặc định", subtitle: "/bin/zsh (mở shell bình thường)", icon: "terminal.fill", iconColor: theme.textSecondary),
            PresetOption(key: "claude", title: "Claude Code", subtitle: "Anthropic AI Coding Assistant", icon: "sparkles", iconColor: Color(hex: 0xE59853)),
            PresetOption(key: "codex", title: "Codex AI", subtitle: "OpenAI Codex CLI Tool", icon: "cpu", iconColor: theme.info),
            PresetOption(key: "agy", title: "Antigravity CLI", subtitle: "Google Antigravity AI Agent", icon: "bolt.fill", iconColor: theme.accent)
        ]
    }

    var body: some View {
        let theme = themeManager.current
        VStack(spacing: 0) {
            headerView
            HairlineDivider()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    appearanceSection
                    fontSizeSection
                    startCommandSection

                    if showHiddenSettings {
                        templatesSection
                        shortcutsSection
                    }
                }
                .padding(16)
            }

            HairlineDivider()
            footerView
        }
        .frame(width: 372)
        .frame(maxHeight: .infinity)
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                theme.surface.opacity(0.84)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.borderStrong, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.55), radius: 32, x: -6, y: 10)
        .padding(.top, 52)
        .padding(.bottom, 14)
        .padding(.trailing, 14)
        .onAppear { loadSelection() }
        .onExitCommand {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                isOpen = false
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        let theme = themeManager.current
        return HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(theme.accentSoft)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(theme.accent.opacity(0.32), lineWidth: 1)
                    )
                    .frame(width: 34, height: 34)

                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.accentHover)
            }

            VStack(alignment: .leading, spacing: 1.5) {
                Text("Thiết Lập & Giao Diện")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(theme.textPrimary)

                Text("Đồng bộ giao diện và màu Terminal")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textMuted)
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                    isOpen = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10.5, weight: .bold))
            }
            .buttonStyle(GlassIconButtonStyle(size: 26))
            .help("Đóng (ESC)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Theme Picker Section

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(icon: "paintpalette.fill", title: "GIAO DIỆN & BẢNG MÀU")

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(AppTheme.allThemes, id: \.id) { item in
                    ThemeOptionCard(
                        themeOption: item,
                        isSelected: themeManager.currentID == item.id
                    ) {
                        themeManager.select(item.id)
                    }
                }
            }
        }
    }

    // MARK: - Font Size Section

    private var fontSizeSection: some View {
        let theme = themeManager.current
        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader(icon: "textformat.size", title: "CỠ CHỮ TERMINAL")

            sectionCard {
                HStack(spacing: 10) {
                    Image(systemName: "textformat.size.smaller")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textMuted)

                    Slider(
                        value: $fontSize,
                        in: TerminalFontSize.range,
                        step: 1,
                        onEditingChanged: { editing in
                            if !editing { saveFontSize() }
                        }
                    )
                    .tint(theme.accent)

                    Image(systemName: "textformat.size.larger")
                        .font(.system(size: 13))
                        .foregroundColor(theme.textMuted)

                    Text("\(Int(fontSize)) pt")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(theme.surfaceElevated)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(theme.border, lineWidth: 1)
                        )
                }

                Text("$ echo \"Terminal Manager\"  # \(Int(fontSize))pt")
                    .font(.system(size: min(16, max(10, fontSize)), design: .monospaced))
                    .foregroundColor(theme.accentHover)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(theme.terminalBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    )
            }
        }
    }

    // MARK: - Start Command Section

    private var startCommandSection: some View {
        let theme = themeManager.current
        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader(icon: "terminal.fill", title: "LỆNH KHỞI ĐỘNG MẶC ĐỊNH")

            sectionCard {
                Text("Tự động chạy khi mở một Terminal pane mới.")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textMuted)

                VStack(spacing: 6) {
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

                HairlineDivider().padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Lệnh tùy chỉnh")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.textSecondary)
                        Spacer()
                        if let cmd = selectedCommand, !presets.contains(where: { $0.key == cmd }) {
                            Text("Đang dùng: \(cmd)")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(theme.accentHover)
                        }
                    }

                    HStack(spacing: 7) {
                        HStack(spacing: 6) {
                            Image(systemName: "command")
                                .font(.system(size: 10.5))
                                .foregroundColor(theme.textMuted)

                            TextField("vd: gemini, nvim, tmux...", text: $customCommand)
                                .font(.system(size: 12, design: .monospaced))
                                .textFieldStyle(.plain)
                                .foregroundColor(theme.textPrimary)
                                .onSubmit { applyCustomCommand() }
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6.5)
                        .background(theme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(theme.border, lineWidth: 1)
                        )

                        Button(action: applyCustomCommand) {
                            Text("Áp dụng")
                        }
                        .buttonStyle(ThemeButton(isPrimary: !customCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, isCompact: true))
                        .disabled(customCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    private var templatesSection: some View {
        let theme = themeManager.current
        return VStack(alignment: .leading, spacing: 8) {
            sectionHeader(icon: "folder.fill.badge.gearshape", title: "MẪU THƯ MỤC CON")

            sectionCard {
                if templateList.isEmpty {
                    Text("Chưa có mẫu nào.")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 10)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(templateList, id: \.self) { name in
                            TemplateChipView(name: name) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    templateList.removeAll { $0.lowercased() == name.lowercased() }
                                    saveTemplates()
                                }
                            }
                        }
                    }
                }

                HStack(spacing: 8) {
                    TextField("Thêm mẫu mới...", text: $newTemplateName)
                        .font(.system(size: 12))
                        .textFieldStyle(.plain)
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6.5)
                        .background(theme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(theme.border, lineWidth: 1))
                        .onSubmit { addTemplate() }

                    Button(action: addTemplate) { Text("+ Thêm") }
                        .buttonStyle(ThemeButton(isPrimary: !newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, isCompact: true))
                        .disabled(newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var shortcutsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(icon: "keyboard.fill", title: "PHÍM TẮT")
            sectionCard {
                ShortcutRowView(shortcut: "⌘ + W", description: "Đóng terminal pane đang chọn")
                ShortcutRowView(shortcut: "ESC", description: "Đóng bảng thiết lập")
                ShortcutRowView(shortcut: "Kéo & Thả", description: "Thả thư mục vào ô trống để mở")
            }
        }
    }

    // MARK: - Footer

    private var footerView: some View {
        let theme = themeManager.current
        return HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Terminal Manager")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                Text("macOS Native • Glass & Graphite")
                    .font(.system(size: 10))
                    .foregroundColor(theme.textMuted)
            }

            Spacer()

            Button(action: resetToDefaults) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Mặc định")
                }
            }
            .buttonStyle(ThemeButton(isPrimary: false, isCompact: true))
            .help("Đặt lại giao diện và cấu hình mặc định")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String) -> some View {
        let theme = themeManager.current
        return HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundColor(theme.accentHover)

            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.8)
                .foregroundColor(theme.textMuted)

            Spacer()
        }
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let theme = themeManager.current
        return VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.surfaceHover)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
    }

    // MARK: - Persistence Logic

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

        fontSize = TerminalFontSize.current
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

    private func saveFontSize() {
        TerminalFontSize.current = fontSize
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
            themeManager.reset()
            selectedCommand = nil
            customCommand = ""
            templateList = ["agy", "codex", "claude"]
            fontSize = TerminalFontSize.defaultSize
            saveSelection()
            saveTemplates()
            saveFontSize()
        }
    }
}

// MARK: - Theme Option Swatch Card

struct ThemeOptionCard: View {
    let themeOption: AppTheme
    let isSelected: Bool
    let onSelect: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isHovered = false

    var body: some View {
        let active = themeManager.current
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                // Mini terminal preview bar
                HStack(spacing: 4) {
                    Circle().fill(themeOption.danger.opacity(0.85)).frame(width: 6, height: 6)
                    Circle().fill(themeOption.warning.opacity(0.85)).frame(width: 6, height: 6)
                    Circle().fill(themeOption.success.opacity(0.85)).frame(width: 6, height: 6)
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(themeOption.accent)
                        .frame(width: 18, height: 4)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(themeOption.terminalBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.75)
                        )
                )

                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(themeOption.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(active.textPrimary)
                        Text(themeOption.subtitle.components(separatedBy: " • ").first ?? "")
                            .font(.system(size: 9.5))
                            .foregroundColor(active.textMuted)
                            .lineLimit(1)
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(active.accentHover)
                    }
                }
            }
            .padding(9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? active.accentSoft : (isHovered ? active.surfaceActive : active.surfaceHover))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? active.accent.opacity(0.65) : (isHovered ? active.borderStrong : active.border), lineWidth: isSelected ? 1.25 : 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Sub-components

struct PresetRowView: View {
    let option: PresetOption
    let isSelected: Bool
    let onSelect: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isHovered = false

    var body: some View {
        let theme = themeManager.current
        Button(action: onSelect) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isSelected ? option.iconColor.opacity(0.18) : theme.surfaceElevated)
                        .frame(width: 28, height: 28)

                    Image(systemName: option.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isSelected ? option.iconColor : theme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 1.5) {
                    Text(option.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isSelected ? theme.textPrimary : theme.textPrimary.opacity(0.88))

                    Text(option.subtitle)
                        .font(.system(size: 10.5))
                        .foregroundColor(theme.textMuted)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? theme.accentHover : theme.textMuted.opacity(0.45))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? theme.accentSoft : (isHovered ? theme.surfaceActive : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? theme.accent.opacity(0.45) : (isHovered ? theme.border : Color.clear), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }
}

struct TemplateChipView: View {
    let name: String
    let onDelete: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isHovered = false

    var body: some View {
        let theme = themeManager.current
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 10.5))
                .foregroundColor(theme.accentHover)

            Text(name)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(theme.textPrimary)

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(isHovered ? theme.danger : theme.textMuted)
            }
            .buttonStyle(.plain)
            .help("Xóa mẫu này")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(theme.accentSoft))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(isHovered ? theme.danger.opacity(0.5) : theme.accent.opacity(0.32), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }
}

struct ShortcutRowView: View {
    let shortcut: String
    let description: String
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        let theme = themeManager.current
        HStack(spacing: 10) {
            Text(description)
                .font(.system(size: 11.5))
                .foregroundColor(theme.textSecondary)

            Spacer()

            Text(shortcut)
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .foregroundColor(theme.textPrimary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(theme.surfaceElevated))
                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(theme.border, lineWidth: 1))
        }
        .padding(.vertical, 2)
    }
}
