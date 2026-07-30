import SwiftUI

extension Color {
    static let themeBase = Color(red: 6/255, green: 7/255, blue: 10/255)         // #06070a
    static let themeSurface = Color(red: 11/255, green: 12/255, blue: 16/255)    // #0b0c10
    static let themeSurfaceHover = Color.white.opacity(0.03)
    static let themeSurfaceActive = Color.white.opacity(0.06)
    
    static let themeBorder = Color.white.opacity(0.06)
    static let themeBorderHover = Color.white.opacity(0.15)
    
    static let themePrimary = Color(red: 139/255, green: 92/255, blue: 246/255)   // #8b5cf6
    static let themePrimaryHover = Color(red: 167/255, green: 139/255, blue: 250/255) // #a78bfa
    static let themePrimaryGlow = Color(red: 139/255, green: 92/255, blue: 246/255).opacity(0.25)
    
    static let themeTextPrimary = Color(red: 243/255, green: 244/255, blue: 246/255)   // #f3f4f6
    static let themeTextSecondary = Color(red: 156/255, green: 163/255, blue: 175/255) // #9ca3af
    static let themeTextMuted = Color(red: 107/255, green: 114/255, blue: 128/255)     // #6b7280
    
    static let themeGreen = Color(red: 16/255, green: 185/255, blue: 129/255)     // #10b981
    static let themeRed = Color(red: 239/255, green: 68/255, blue: 68/255)        // #ef4444
    
    static let themePrimaryGradient = LinearGradient(
        colors: [Color(red: 139/255, green: 92/255, blue: 246/255), Color(red: 109/255, green: 40/255, blue: 217/255)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct ThemeButton: ButtonStyle {
    var isPrimary = false
    var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        if isPrimary {
            configuration.label
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.themePrimaryGradient)
                )
                .shadow(color: Color.themePrimary.opacity(configuration.isPressed ? 0.15 : 0.35), radius: isHovered ? 8 : 4, y: 2)
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
        } else {
            configuration.label
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.themeTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(isHovered ? 0.06 : 0.03))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(isHovered ? 0.15 : 0.06), lineWidth: 1)
                )
                .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
                .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
        }
    }
}
