import SwiftUI

struct AgentCommandsPanel: View {
    @EnvironmentObject private var agentCommandStore: AgentCommandStore
    @EnvironmentObject private var themeManager: ThemeManager
    @Binding var isPinned: Bool
    @Binding var isPopoverOpen: Bool
    let onLaunchCommand: (String, String) -> Void

    @State private var addTargetGroupID: UUID?

    var body: some View {
        let theme = themeManager.current
        VStack(spacing: 0) {
            // Compact drawer header
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.accentHover)

                Text("Agent Commands")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(theme.textPrimary)

                Spacer()

                Button {
                    addTargetGroupID = agentCommandStore.groups.first?.id
                    isPopoverOpen = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(GlassIconButtonStyle(size: 24))
                .help("Thêm lệnh mới hoặc Agent mới")
                .popover(isPresented: $isPopoverOpen, arrowEdge: .leading) {
                    AddAgentCommandPopover(
                        defaultGroupID: addTargetGroupID,
                        isPresented: $isPopoverOpen,
                        onCreatedGroup: { _ in }
                    )
                    .environmentObject(agentCommandStore)
                    .environmentObject(themeManager)
                }

                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isPinned.toggle()
                    }
                } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 10.5, weight: .medium))
                }
                .buttonStyle(GlassIconButtonStyle(active: isPinned, size: 24))
                .help(isPinned ? "Bỏ ghim (tự ẩn khi rời chuột)" : "Ghim cố định bảng lệnh")
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .overlay(HairlineDivider(), alignment: .bottom)

            // Flat vertically-grouped list of ALL agents & their commands (zero tabs!)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(agentCommandStore.groups) { group in
                        AgentFlatSectionView(
                            group: group,
                            onLaunchCommand: onLaunchCommand,
                            onQuickAdd: {
                                addTargetGroupID = group.id
                                isPopoverOpen = true
                            },
                            onDeleteCommand: { cmdID in
                                agentCommandStore.deleteCommand(in: group.id, commandID: cmdID)
                            },
                            onDeleteGroup: agentCommandStore.groups.count > 1 ? {
                                agentCommandStore.deleteGroup(group.id)
                            } : nil
                        )
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
            }

            // Subtle drag hint footer
            HStack(spacing: 5) {
                Image(systemName: "hand.draw")
                    .font(.system(size: 9.5))
                Text("Kéo thả vào Terminal")
                    .font(.system(size: 10))
                Spacer()
            }
            .foregroundColor(theme.textMuted)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .overlay(HairlineDivider(), alignment: .top)
        }
        .background(
            ZStack {
                VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                theme.surface.opacity(0.86)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.borderStrong, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 22, x: -6, y: 6)
    }
}

private struct AgentFlatSectionView: View {
    let group: AgentCommandGroup
    let onLaunchCommand: (String, String) -> Void
    let onQuickAdd: () -> Void
    let onDeleteCommand: (UUID) -> Void
    let onDeleteGroup: (() -> Void)?

    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isHeaderHovered = false

    var body: some View {
        let theme = themeManager.current
        let tint = Color(hex: group.colorHex)

        VStack(alignment: .leading, spacing: 5) {
            // Flat section header
            HStack(spacing: 6) {
                Image(systemName: group.icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(tint)

                Text(group.agentName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)

                Text(group.shortTag)
                    .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                    .foregroundColor(theme.textMuted)

                Spacer()

                if isHeaderHovered {
                    Button(action: onQuickAdd) {
                        Image(systemName: "plus")
                            .font(.system(size: 9.5, weight: .bold))
                    }
                    .buttonStyle(ActionButtonStyle(color: tint))
                    .help("Thêm lệnh cho \(group.agentName)")
                }
            }
            .padding(.horizontal, 4)
            .frame(height: 20)
            .contentShape(Rectangle())
            .onHover { isHeaderHovered = $0 }
            .contextMenu {
                Button(action: onQuickAdd) {
                    Label("Thêm lệnh cho \(group.agentName)...", systemImage: "plus")
                }
                if let onDeleteGroup {
                    Divider()
                    Button(role: .destructive, action: onDeleteGroup) {
                        Label("Xóa nhóm \(group.agentName)", systemImage: "trash")
                    }
                }
            }

            if group.commands.isEmpty {
                Button(action: onQuickAdd) {
                    Text("+ Thêm lệnh đầu tiên")
                        .font(.system(size: 10.5))
                        .foregroundColor(theme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(theme.border, style: StrokeStyle(lineWidth: 1, dash: [3]))
                        )
                }
                .buttonStyle(.plain)
            } else {
                VStack(spacing: 4) {
                    ForEach(group.commands) { preset in
                        DraggableAgentCommandChip(
                            group: group,
                            preset: preset,
                            tint: tint,
                            onTap: {
                                onLaunchCommand("\(group.shortTag) • \(preset.title)", preset.command)
                            },
                            onDelete: {
                                onDeleteCommand(preset.id)
                            }
                        )
                    }
                }
            }
        }
    }
}

struct DraggableAgentCommandChip: View {
    let group: AgentCommandGroup
    let preset: AgentCommandPreset
    let tint: Color
    let onTap: () -> Void
    let onDelete: () -> Void

    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isHovered = false
    @State private var isDeleteHovered = false

    var body: some View {
        let theme = themeManager.current
        HStack(spacing: 7) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(isHovered ? tint : theme.textMuted.opacity(0.6))
                .frame(width: 10)

            VStack(alignment: .leading, spacing: 1.5) {
                Text(preset.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(theme.textPrimary.opacity(0.92))
                    .lineLimit(1)

                Text(preset.command)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundColor(theme.textMuted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .layoutPriority(-1)

            Spacer(minLength: 2)

            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundColor(isDeleteHovered ? theme.danger : theme.textMuted)
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .onHover { isDeleteHovered = $0 }
                .help("Xóa lệnh này")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(isHovered ? theme.surfaceActive : theme.surfaceElevated.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(isHovered ? tint.opacity(0.5) : theme.border, lineWidth: 0.75)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture { onTap() }
        .onDrag {
            AgentCommandDragCodec.itemProvider(
                title: "\(group.shortTag) • \(preset.title)",
                command: preset.command
            )
        }
        .help("Kéo thả vào Terminal để chạy ngay • Hoặc nhấn để mở Terminal mới\n\(preset.command)")
    }
}

// MARK: - Add Command / Agent Popover

struct AddAgentCommandPopover: View {
    let defaultGroupID: UUID?
    @Binding var isPresented: Bool
    let onCreatedGroup: (UUID) -> Void

    @EnvironmentObject private var agentCommandStore: AgentCommandStore
    @EnvironmentObject private var themeManager: ThemeManager

    @State private var selectedGroupID: UUID?
    @State private var isCreatingNewAgent = false
    @State private var newAgentName = ""
    @State private var newAgentTag = ""
    @State private var commandTitle = ""
    @State private var commandText = ""

    private var canSubmit: Bool {
        let hasCmd = !commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if isCreatingNewAgent {
            return hasCmd && !newAgentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return hasCmd && (selectedGroupID ?? agentCommandStore.groups.first?.id) != nil
    }

    var body: some View {
        let theme = themeManager.current
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.accentHover)
                    Text("Thêm lệnh Agent")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(theme.textPrimary)
                }
                Spacer()
                Button { isPresented = false } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(GlassIconButtonStyle(size: 22))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(theme.surface)

            HairlineDivider()

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("NHÓM AGENT")
                            .font(.system(size: 9.5, weight: .semibold))
                            .tracking(0.8)
                            .foregroundColor(theme.textMuted)
                        Spacer()
                        Button {
                            withAnimation(.easeOut(duration: 0.14)) {
                                isCreatingNewAgent.toggle()
                            }
                        } label: {
                            Text(isCreatingNewAgent ? "Chọn agent có sẵn" : "+ Agent mới")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundColor(theme.accentHover)
                        }
                        .buttonStyle(.plain)
                    }

                    if isCreatingNewAgent {
                        HStack(spacing: 6) {
                            TextField("Tên (vd: Gemini)", text: $newAgentName)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12))
                                .foregroundColor(theme.textPrimary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .background(theme.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(theme.borderStrong, lineWidth: 1))

                            TextField("Tag (vd: gemini)", text: $newAgentTag)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(theme.textPrimary)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 6)
                                .frame(width: 105)
                                .background(theme.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(theme.border, lineWidth: 1))
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 5) {
                                ForEach(agentCommandStore.groups) { group in
                                    let isSel = (selectedGroupID ?? agentCommandStore.groups.first?.id) == group.id
                                    let tint = Color(hex: group.colorHex)
                                    Button {
                                        selectedGroupID = group.id
                                    } label: {
                                        Text(group.agentName)
                                            .font(.system(size: 11, weight: isSel ? .semibold : .medium))
                                            .foregroundColor(isSel ? theme.textPrimary : theme.textSecondary)
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 4.5)
                                            .background(Capsule().fill(isSel ? tint.opacity(0.18) : theme.surfaceHover))
                                            .overlay(Capsule().stroke(isSel ? tint.opacity(0.5) : theme.border, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("TÊN HIỂN THỊ")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(0.8)
                        .foregroundColor(theme.textMuted)
                    TextField("vd: Skip permissions, Fast mode...", text: $commandTitle)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6.5)
                        .background(theme.surfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(theme.border, lineWidth: 1))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("LỆNH TERMINAL")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(0.8)
                        .foregroundColor(theme.textMuted)
                    TextField("vd: agy --dangerously-skip-permissions", text: $commandText, onCommit: submit)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundColor(theme.textPrimary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(theme.terminalBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(theme.borderStrong, lineWidth: 1))
                }
            }
            .padding(14)

            HairlineDivider()

            HStack {
                Button("Khôi phục mặc định") {
                    agentCommandStore.resetDefaults()
                    selectedGroupID = agentCommandStore.groups.first?.id
                }
                .font(.system(size: 10.5))
                .foregroundColor(theme.textMuted)
                .buttonStyle(.plain)

                Spacer()

                Button("Hủy") { isPresented = false }
                    .buttonStyle(ThemeButton(isPrimary: false, isCompact: true))

                Button("Thêm lệnh", action: submit)
                    .buttonStyle(ThemeButton(isPrimary: true, isCompact: true))
                    .disabled(!canSubmit)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(theme.surface)
        }
        .frame(width: 310)
        .background(theme.surface)
        .onAppear {
            selectedGroupID = defaultGroupID ?? agentCommandStore.groups.first?.id
        }
    }

    private func submit() {
        guard canSubmit else { return }
        if isCreatingNewAgent {
            if let id = agentCommandStore.addAgentGroup(
                name: newAgentName,
                shortTag: newAgentTag,
                firstCommandTitle: commandTitle,
                firstCommand: commandText
            ) {
                onCreatedGroup(id)
            }
        } else if let targetID = selectedGroupID ?? agentCommandStore.groups.first?.id {
            agentCommandStore.addCommand(to: targetID, title: commandTitle, command: commandText)
            onCreatedGroup(targetID)
        }
        isPresented = false
    }
}
