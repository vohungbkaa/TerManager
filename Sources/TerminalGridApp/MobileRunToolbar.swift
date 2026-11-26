import SwiftUI

struct MobileRunToolbar: View {
    @ObservedObject var controller: MobileRunController
    @ObservedObject var session: BuildSession
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var devicePopoverOpen = false

    var body: some View {
        let theme = themeManager.current
        HStack(spacing: 6) {
            // Grouped Device & Target capsule
            HStack(spacing: 0) {
                deviceSelector
                HairlineDivider(vertical: true)
                    .frame(height: 16)
                targetDisplay
            }
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(theme.surfaceHover)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )

            runButton

            Button { session.isDrawerVisible.toggle() } label: {
                Image(systemName: session.isDrawerVisible ? "chevron.down.square.fill" : "hammer.fill")
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .buttonStyle(GlassIconButtonStyle(active: session.isDrawerVisible, size: 28))
            .help(session.isDrawerVisible ? "Thu gọn Build Terminal" : "Mở Build Terminal")
        }
    }

    private var deviceSelector: some View {
        let theme = themeManager.current
        return Button {
            devicePopoverOpen.toggle()
            if devicePopoverOpen { controller.refresh() }
        } label: {
            HStack(spacing: 6) {
                if controller.isDiscovering {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: deviceIcon)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(controller.selectedDevice == nil ? theme.textMuted : theme.accentHover)
                }
                Text(controller.selectedDevice?.name ?? "Chọn device")
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(theme.textMuted)
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundColor(theme.textPrimary.opacity(0.9))
            .padding(.horizontal, 9)
            .frame(minWidth: 120, maxWidth: 195, minHeight: 28, maxHeight: 28, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $devicePopoverOpen, arrowEdge: .bottom) {
            DeviceSelectorPopover(controller: controller, isOpen: $devicePopoverOpen)
                .environmentObject(themeManager)
        }
    }

    private var targetDisplay: some View {
        let theme = themeManager.current
        return HStack(spacing: 5) {
            if controller.target == nil && controller.targetError == nil {
                ProgressView().controlSize(.mini)
            } else {
                Image(systemName: controller.target?.iconName ?? "exclamationmark.triangle.fill")
                    .font(.system(size: 10.5))
                    .foregroundColor(controller.target == nil ? theme.danger : theme.textSecondary)
            }
            Text(controller.target?.displayName ?? "No target")
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(theme.textSecondary)
        .padding(.horizontal, 9)
        .frame(minWidth: 72, maxWidth: 120, minHeight: 28, maxHeight: 28, alignment: .leading)
        .help(controller.targetError ?? "Build target mặc định")
    }

    private var runButton: some View {
        let theme = themeManager.current
        let isActive = session.state.isActive
        let color = isActive ? theme.danger : theme.success
        return Button { controller.runOrStop() } label: {
            Image(systemName: isActive ? "stop.fill" : "play.fill")
                .font(.system(size: 11, weight: .bold))
        }
        .buttonStyle(GlassIconButtonStyle(active: isActive, tint: color, size: 28))
        .disabled(!isActive && (controller.selectedDevice == nil || controller.target == nil))
        .opacity(!isActive && (controller.selectedDevice == nil || controller.target == nil) ? 0.45 : 1.0)
        .help(isActive ? "Dừng tiến trình đang chạy" : "Build, cài đặt và Run")
    }

    private var deviceIcon: String {
        guard let device = controller.selectedDevice else { return "iphone.slash" }
        switch device.kind {
        case .physical: return "iphone"
        case .simulator: return "iphone.gen3"
        case .emulator: return "rectangle.inset.filled.and.person.filled"
        }
    }
}

struct DeviceSelectorPopover: View {
    @ObservedObject var controller: MobileRunController
    @Binding var isOpen: Bool
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        let theme = themeManager.current
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("DEVICES")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundColor(theme.textMuted)
                Spacer()
                Button { controller.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(GlassIconButtonStyle(size: 24))
                .disabled(controller.isDiscovering)
                .help("Làm mới danh sách device")
            }
            .padding(.horizontal, 12)
            .frame(height: 36)

            HairlineDivider()

            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    if controller.devices.isEmpty && !controller.isDiscovering {
                        Text("Không có device đang sẵn sàng")
                            .font(.system(size: 11.5))
                            .foregroundColor(theme.textMuted)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 16)
                    }
                    ForEach(controller.devices) { device in
                        Button {
                            controller.select(device)
                            isOpen = false
                        } label: {
                            DeviceRow(device: device, selected: controller.selectedDeviceID == device.id)
                        }
                        .buttonStyle(.plain)
                    }

                    if !controller.virtualActions.isEmpty {
                        HairlineDivider().padding(.vertical, 5)
                    }
                    ForEach(controller.virtualActions) { action in
                        VirtualDeviceActionRow(
                            action: action,
                            disabled: controller.isLaunchingVirtualDevice
                        ) {
                            controller.launch(action)
                            isOpen = false
                        }
                    }
                }
                .padding(8)
            }

            if let warning = controller.discoveryWarning {
                HairlineDivider()
                Text(warning)
                    .font(.system(size: 10))
                    .foregroundColor(theme.danger)
                    .lineLimit(2)
                    .padding(10)
            }
        }
        .frame(width: 320, height: 300)
        .background(theme.surface)
    }
}

private struct DeviceRow: View {
    let device: MobileDevice
    let selected: Bool
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isHovered = false

    var body: some View {
        let theme = themeManager.current
        HStack(spacing: 9) {
            Image(systemName: device.kind == .physical ? "iphone" : (device.platform == .ios ? "iphone.gen3" : "rectangle.inset.filled.and.person.filled"))
                .font(.system(size: 12))
                .foregroundColor(device.platform == .android ? theme.success : theme.accentHover)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(device.name)
                    .font(.system(size: 12, weight: selected ? .semibold : .medium))
                    .foregroundColor(theme.textPrimary)
                if let detail = device.detail {
                    Text(detail)
                        .font(.system(size: 10))
                        .foregroundColor(theme.textMuted)
                }
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(theme.accentHover)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: device.detail == nil ? 32 : 40)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(selected ? theme.accentSoft : (isHovered ? theme.surfaceHover : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

private struct VirtualDeviceActionRow: View {
    let action: VirtualDeviceAction
    let disabled: Bool
    let onTap: () -> Void
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isHovered = false

    var body: some View {
        let theme = themeManager.current
        Button(action: onTap) {
            HStack(spacing: 9) {
                Image(systemName: action.kind == .iosSimulator ? "iphone.gen3" : "play.rectangle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(action.kind == .iosSimulator ? theme.accentHover : theme.success)
                    .frame(width: 18)
                Text(action.title)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(isHovered ? theme.textPrimary : theme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHovered ? theme.surfaceHover : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { isHovered = $0 }
    }
}
