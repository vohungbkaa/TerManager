import SwiftUI

struct MobileRunToolbar: View {
    @ObservedObject var controller: MobileRunController
    @ObservedObject var session: BuildSession
    @State private var devicePopoverOpen = false

    var body: some View {
        HStack(spacing: 5) {
            deviceSelector
            targetDisplay
            runButton
            debugButton

            Button { session.isDrawerVisible.toggle() } label: {
                Image(systemName: session.isDrawerVisible ? "chevron.down.square.fill" : "hammer.fill")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(HeaderToolButtonStyle(color: .themePrimaryHover))
            .help(session.isDrawerVisible ? "Thu gọn Build Terminal" : "Mở Build Terminal")
        }
    }

    private var deviceSelector: some View {
        Button {
            devicePopoverOpen.toggle()
            if devicePopoverOpen { controller.refresh() }
        } label: {
            HStack(spacing: 7) {
                if controller.isDiscovering {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: deviceIcon)
                        .foregroundColor(.themePrimaryHover)
                }
                Text(controller.selectedDevice?.name ?? "Chọn device")
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.themeTextMuted)
            }
            .font(.system(size: 11.5, weight: .medium))
            .foregroundColor(.themeTextSecondary)
            .padding(.horizontal, 9)
            .frame(width: 205, height: 30, alignment: .leading)
            .background(Color.white.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.themeBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $devicePopoverOpen, arrowEdge: .top) {
            DeviceSelectorPopover(controller: controller, isOpen: $devicePopoverOpen)
        }
    }

    private var targetDisplay: some View {
        HStack(spacing: 6) {
            if controller.target == nil && controller.targetError == nil {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: controller.target?.iconName ?? "exclamationmark.triangle.fill")
                    .foregroundColor(controller.target == nil ? .themeRed : .themePrimaryHover)
            }
            Text(controller.target?.displayName ?? "No target")
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.system(size: 11.5, weight: .medium))
        .foregroundColor(.themeTextSecondary)
        .padding(.horizontal, 9)
        .frame(width: 125, height: 30, alignment: .leading)
        .background(Color.white.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .help(controller.targetError ?? "Build target mặc định")
    }

    private var runButton: some View {
        Button { controller.runOrStop() } label: {
            Image(systemName: session.state.isActive ? "stop.fill" : "play.fill")
                .frame(width: 28, height: 28)
        }
        .buttonStyle(HeaderToolButtonStyle(color: session.state.isActive ? .themeRed : .themeGreen))
        .disabled(!session.state.isActive && (controller.selectedDevice == nil || controller.target == nil))
        .help(session.state.isActive ? "Dừng tiến trình đang chạy" : "Build, cài đặt và Run")
    }

    private var debugButton: some View {
        Button {} label: {
            Image(systemName: "ladybug.fill")
                .frame(width: 28, height: 28)
        }
        .buttonStyle(HeaderToolButtonStyle(color: .themeTextMuted))
        .disabled(true)
        .help("Debug sẽ được hỗ trợ ở phiên bản sau")
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("DEVICES")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.themeTextMuted)
                Spacer()
                Button { controller.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(controller.isDiscovering)
                .help("Làm mới danh sách device")
            }
            .padding(.horizontal, 12)
            .frame(height: 34)

            Divider().background(Color.themeBorder)

            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    if controller.devices.isEmpty && !controller.isDiscovering {
                        Text("Không có device đang sẵn sàng")
                            .font(.system(size: 11))
                            .foregroundColor(.themeTextMuted)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
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
                        Divider().background(Color.themeBorder).padding(.vertical, 5)
                    }
                    ForEach(controller.virtualActions) { action in
                        Button {
                            controller.launch(action)
                            isOpen = false
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: actionIcon(action))
                                    .foregroundColor(actionColor(action))
                                    .frame(width: 16)
                                Text(action.title)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundColor(.themeTextSecondary)
                                Spacer()
                            }
                            .padding(.horizontal, 9)
                            .frame(height: 29)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(controller.isLaunchingVirtualDevice)
                    }
                }
                .padding(6)
            }

            if let warning = controller.discoveryWarning {
                Divider().background(Color.themeBorder)
                Text(warning)
                    .font(.system(size: 9.5))
                    .foregroundColor(.themeRed)
                    .lineLimit(2)
                    .padding(9)
            }
        }
        .frame(width: 330, height: 300)
        .background(Color.themeSurface)
    }

    private func actionIcon(_ action: VirtualDeviceAction) -> String {
        switch action.kind {
        case .iosSimulator: return "iphone.gen3"
        case .androidEmulator: return "play.rectangle.fill"
        }
    }

    private func actionColor(_ action: VirtualDeviceAction) -> Color {
        switch action.kind {
        case .iosSimulator: return .themePrimaryHover
        case .androidEmulator: return .themeGreen
        }
    }
}

private struct DeviceRow: View {
    let device: MobileDevice
    let selected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: device.kind == .physical ? "iphone" : (device.platform == .ios ? "iphone.gen3" : "rectangle.inset.filled.and.person.filled"))
                .foregroundColor(device.platform == .android ? .themeGreen : .themePrimaryHover)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(device.name)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.themeTextPrimary)
                if let detail = device.detail {
                    Text(detail)
                        .font(.system(size: 9.5))
                        .foregroundColor(.themeTextMuted)
                }
            }
            Spacer()
            if selected {
                Image(systemName: "checkmark")
                    .foregroundColor(.themePrimaryHover)
            }
        }
        .padding(.horizontal, 9)
        .frame(height: device.detail == nil ? 29 : 38)
        .background(selected ? Color.themePrimary.opacity(0.12) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .contentShape(Rectangle())
    }
}

private struct HeaderToolButtonStyle: ButtonStyle {
    let color: Color
    @State private var hovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(hovered ? color : color.opacity(0.85))
            .background(RoundedRectangle(cornerRadius: 6).fill(hovered ? color.opacity(0.12) : Color.white.opacity(0.025)))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .onHover { hovered = $0 }
    }
}
