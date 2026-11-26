import SwiftUI
import AppKit

// MARK: - Theme Identifiers & Definitions

enum AppThemeID: String, CaseIterable, Identifiable, Codable {
    case graphite
    case obsidian
    case warmDusk
    case nordFrost

    var id: String { rawValue }
}

struct AppTheme: Equatable {
    let id: AppThemeID
    let name: String
    let subtitle: String

    // Core Surfaces
    let windowBackground: Color
    let windowNSColor: NSColor
    let sidebarTint: Color
    let toolbarBackground: Color
    let surface: Color
    let surfaceElevated: Color
    let surfaceHover: Color
    let surfaceActive: Color

    // Borders
    let border: Color
    let borderStrong: Color

    // Accent
    let accent: Color
    let accentHover: Color
    let accentSoft: Color
    let accentNSColor: NSColor

    // Text
    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color

    // Semantic
    let success: Color
    let warning: Color
    let danger: Color
    let info: Color

    // Terminal Surface & Palette
    let terminalBackground: Color
    let terminalBackgroundNS: NSColor
    let terminalForegroundNS: NSColor
    let terminalCursorNS: NSColor
    let ansiHexColors: [String] // 16 standard ANSI colors

    // Preview Swatches for Settings UI
    var previewColors: [Color] {
        [windowBackground, terminalBackground, accent, success]
    }

    var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accentHover, accent],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Built-in Curated Themes

    static let graphite = AppTheme(
        id: .graphite,
        name: "Graphite",
        subtitle: "Linear / Raycast • Kính mờ chuẩn macOS",
        windowBackground: Color(hex: 0x0E1015),
        windowNSColor: NSColor(hex: 0x0E1015),
        sidebarTint: Color(hex: 0x11131A).opacity(0.55),
        toolbarBackground: Color(hex: 0x12151C).opacity(0.88),
        surface: Color(hex: 0x141720),
        surfaceElevated: Color(hex: 0x1A1E29),
        surfaceHover: Color.white.opacity(0.045),
        surfaceActive: Color.white.opacity(0.08),
        border: Color.white.opacity(0.075),
        borderStrong: Color.white.opacity(0.14),
        accent: Color(hex: 0x5E9BFF),
        accentHover: Color(hex: 0x7EB0FF),
        accentSoft: Color(hex: 0x5E9BFF).opacity(0.15),
        accentNSColor: NSColor(hex: 0x5E9BFF),
        textPrimary: Color(hex: 0xF2F4F8),
        textSecondary: Color(hex: 0x9BA3B4),
        textMuted: Color(hex: 0x646D82),
        success: Color(hex: 0x34D399),
        warning: Color(hex: 0xFBBF24),
        danger: Color(hex: 0xF87171),
        info: Color(hex: 0x38BDF8),
        terminalBackground: Color(hex: 0x12151C),
        terminalBackgroundNS: NSColor(hex: 0x12151C),
        terminalForegroundNS: NSColor(hex: 0xD8DEE9),
        terminalCursorNS: NSColor(hex: 0x5E9BFF),
        ansiHexColors: [
            "1B1F2A", "F87171", "34D399", "FBBF24",
            "60A5FA", "C084FC", "38BDF8", "D8DEE9",
            "4B5568", "FCA5A5", "6EE7B7", "FDE68A",
            "93C5FD", "D8B4FE", "7DD3FC", "F8FAFC"
        ]
    )

    static let obsidian = AppTheme(
        id: .obsidian,
        name: "Obsidian",
        subtitle: "Đen sâu tối giản • Tím bạc tinh tế",
        windowBackground: Color(hex: 0x090A0E),
        windowNSColor: NSColor(hex: 0x090A0E),
        sidebarTint: Color(hex: 0x0C0D12).opacity(0.62),
        toolbarBackground: Color(hex: 0x0D0F14).opacity(0.90),
        surface: Color(hex: 0x101218),
        surfaceElevated: Color(hex: 0x161922),
        surfaceHover: Color.white.opacity(0.04),
        surfaceActive: Color.white.opacity(0.075),
        border: Color.white.opacity(0.07),
        borderStrong: Color.white.opacity(0.14),
        accent: Color(hex: 0xA78BFA),
        accentHover: Color(hex: 0xC4B5FD),
        accentSoft: Color(hex: 0xA78BFA).opacity(0.15),
        accentNSColor: NSColor(hex: 0xA78BFA),
        textPrimary: Color(hex: 0xF4F4F6),
        textSecondary: Color(hex: 0x9A9FB0),
        textMuted: Color(hex: 0x5E6478),
        success: Color(hex: 0x2DD4BF),
        warning: Color(hex: 0xF59E0B),
        danger: Color(hex: 0xFB7185),
        info: Color(hex: 0x60A5FA),
        terminalBackground: Color(hex: 0x0E1016),
        terminalBackgroundNS: NSColor(hex: 0x0E1016),
        terminalForegroundNS: NSColor(hex: 0xC8D3F5),
        terminalCursorNS: NSColor(hex: 0xA78BFA),
        ansiHexColors: [
            "181B26", "F7768E", "9ECE6A", "E0AF68",
            "7AA2F7", "BB9AF7", "7DCFFF", "C0CAF5",
            "414868", "FF899D", "B9F27C", "FFD08A",
            "8DB0FF", "CDA9FF", "A4DAFF", "FFFFFF"
        ]
    )

    static let warmDusk = AppTheme(
        id: .warmDusk,
        name: "Warm Dusk",
        subtitle: "Charcoal ấm áp • Hổ phách dịu mắt",
        windowBackground: Color(hex: 0x131110),
        windowNSColor: NSColor(hex: 0x131110),
        sidebarTint: Color(hex: 0x181513).opacity(0.60),
        toolbarBackground: Color(hex: 0x181513).opacity(0.90),
        surface: Color(hex: 0x1A1715),
        surfaceElevated: Color(hex: 0x221E1B),
        surfaceHover: Color.white.opacity(0.045),
        surfaceActive: Color.white.opacity(0.08),
        border: Color.white.opacity(0.08),
        borderStrong: Color.white.opacity(0.15),
        accent: Color(hex: 0xE59853),
        accentHover: Color(hex: 0xF2B172),
        accentSoft: Color(hex: 0xE59853).opacity(0.16),
        accentNSColor: NSColor(hex: 0xE59853),
        textPrimary: Color(hex: 0xF4EFEA),
        textSecondary: Color(hex: 0xADA39A),
        textMuted: Color(hex: 0x736960),
        success: Color(hex: 0x5CC489),
        warning: Color(hex: 0xE5B567),
        danger: Color(hex: 0xE56B6F),
        info: Color(hex: 0x6BB2D8),
        terminalBackground: Color(hex: 0x181513),
        terminalBackgroundNS: NSColor(hex: 0x181513),
        terminalForegroundNS: NSColor(hex: 0xE8DFD5),
        terminalCursorNS: NSColor(hex: 0xE59853),
        ansiHexColors: [
            "26211E", "E56B6F", "78C293", "E5B567",
            "6EA8D6", "C88EC7", "6CC2BD", "E8DFD5",
            "594F48", "F28F92", "97D6AE", "F2CC8A",
            "94C2E6", "DCAFE0", "92D9D4", "FAF6F2"
        ]
    )

    static let nordFrost = AppTheme(
        id: .nordFrost,
        name: "Nord Frost",
        subtitle: "Xanh Bắc Âu • Mát mẻ & tập trung",
        windowBackground: Color(hex: 0x191E28),
        windowNSColor: NSColor(hex: 0x191E28),
        sidebarTint: Color(hex: 0x1E2430).opacity(0.58),
        toolbarBackground: Color(hex: 0x1E2430).opacity(0.90),
        surface: Color(hex: 0x202633),
        surfaceElevated: Color(hex: 0x283040),
        surfaceHover: Color.white.opacity(0.05),
        surfaceActive: Color.white.opacity(0.09),
        border: Color.white.opacity(0.085),
        borderStrong: Color.white.opacity(0.16),
        accent: Color(hex: 0x81C8EE),
        accentHover: Color(hex: 0x9ED8F7),
        accentSoft: Color(hex: 0x81C8EE).opacity(0.16),
        accentNSColor: NSColor(hex: 0x81C8EE),
        textPrimary: Color(hex: 0xECEFF4),
        textSecondary: Color(hex: 0xA8B5C8),
        textMuted: Color(hex: 0x6D7B91),
        success: Color(hex: 0xA3BE8C),
        warning: Color(hex: 0xEBCB8B),
        danger: Color(hex: 0xBF616A),
        info: Color(hex: 0x88C0D0),
        terminalBackground: Color(hex: 0x1E2430),
        terminalBackgroundNS: NSColor(hex: 0x1E2430),
        terminalForegroundNS: NSColor(hex: 0xD8DEE9),
        terminalCursorNS: NSColor(hex: 0x88C0D0),
        ansiHexColors: [
            "3B4252", "BF616A", "A3BE8C", "EBCB8B",
            "81A1C1", "B48EAD", "88C0D0", "E5E9F0",
            "4C566A", "D0727B", "B5CF9E", "F5D99F",
            "94B4D4", "C7A1C0", "8FBCBB", "ECEFF4"
        ]
    )

    static let allThemes: [AppTheme] = [.graphite, .obsidian, .warmDusk, .nordFrost]

    static func resolve(_ id: AppThemeID) -> AppTheme {
        switch id {
        case .graphite: return .graphite
        case .obsidian: return .obsidian
        case .warmDusk: return .warmDusk
        case .nordFrost: return .nordFrost
        }
    }
}

// MARK: - Theme Manager

extension Notification.Name {
    static let appThemeChanged = Notification.Name("appThemeChanged")
}

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    private static let storageKey = "selectedAppThemeID"

    @Published var currentID: AppThemeID {
        didSet {
            UserDefaults.standard.set(currentID.rawValue, forKey: Self.storageKey)
            let theme = current
            DispatchQueue.main.async {
                for window in NSApp.windows {
                    window.backgroundColor = theme.windowNSColor
                }
                NotificationCenter.default.post(name: .appThemeChanged, object: nil)
            }
        }
    }

    var current: AppTheme {
        AppTheme.resolve(currentID)
    }

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let saved = AppThemeID(rawValue: raw) {
            currentID = saved
        } else {
            currentID = .graphite
        }
    }

    func select(_ id: AppThemeID) {
        guard currentID != id else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            currentID = id
        }
    }

    func reset() {
        select(.graphite)
    }
}

// MARK: - Color & SwiftTerm Helpers

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, opacity: alpha)
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1.0) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}

// MARK: - Native macOS Frosted Glass & Hairline Components

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

struct HairlineDivider: View {
    @EnvironmentObject private var themeManager: ThemeManager
    var vertical: Bool = false

    var body: some View {
        Rectangle()
            .fill(themeManager.current.border)
            .frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
    }
}

// MARK: - Refined Button Styles

struct ThemeButton: ButtonStyle {
    var isPrimary = false
    var isCompact = false
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        let theme = themeManager.current
        if isPrimary {
            configuration.label
                .font(.system(size: isCompact ? 11.5 : 12.5, weight: .semibold))
                .foregroundColor(Color(hex: 0x0B0D12))
                .padding(.horizontal, isCompact ? 11 : 15)
                .padding(.vertical, isCompact ? 5.5 : 7.5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(theme.accentGradient)
                        .opacity(isHovered ? 1.0 : 0.94)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 0.75)
                )
                .shadow(color: theme.accent.opacity(configuration.isPressed ? 0.12 : (isHovered ? 0.28 : 0.18)), radius: isHovered ? 8 : 4, y: 1.5)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .onHover { isHovered = $0 }
        } else {
            configuration.label
                .font(.system(size: isCompact ? 11.5 : 12, weight: .medium))
                .foregroundColor(isHovered ? theme.textPrimary : theme.textSecondary)
                .padding(.horizontal, isCompact ? 10 : 12)
                .padding(.vertical, isCompact ? 5.5 : 6.5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(isHovered ? theme.surfaceActive : theme.surfaceHover)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(isHovered ? theme.borderStrong : theme.border, lineWidth: 1)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
                .onHover { isHovered = $0 }
        }
    }
}

struct GlassIconButtonStyle: ButtonStyle {
    var active: Bool = false
    var tint: Color? = nil
    var size: CGFloat = 28
    @EnvironmentObject private var themeManager: ThemeManager
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        let theme = themeManager.current
        let resolvedTint = tint ?? theme.accent
        configuration.label
            .frame(width: size, height: size)
            .foregroundColor(active ? resolvedTint : (isHovered ? (tint ?? theme.textPrimary) : theme.textSecondary))
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        active
                            ? resolvedTint.opacity(0.16)
                            : (isHovered ? (tint?.opacity(0.12) ?? theme.surfaceActive) : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(active ? resolvedTint.opacity(0.4) : (isHovered ? theme.border : Color.clear), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}
