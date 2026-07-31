import SwiftUI

struct SettingsPopover: View {
    @Binding var isOpen: Bool
    @State private var selectedCommand: String?

    private let options = ["claude", "codex", "agy"]

    private let key = "defaultStartCommand"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().background(Color.themeBorder)
            content
        }
        .frame(width: 260)
        .background(Color(red: 15/255, green: 16/255, blue: 21/255))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 15, y: 8)
        .onAppear { loadSelection() }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.themePrimaryHover)
                Text("Thiết lập")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            Spacer()
            Button {
                withAnimation(.easeOut(duration: 0.2)) { isOpen = false }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.themeTextSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.themeSurface)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("START TERMINAL MẶC ĐỊNH VỚI")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.themeTextMuted)

            VStack(spacing: 6) {
                ForEach(options, id: \.self) { name in
                    radioRow(name: name)
                }
            }

            Text("Không chọn = mở shell thường. Chọn lệnh = tự chạy khi mở terminal mới.")
                .font(.system(size: 10))
                .foregroundColor(.themeTextMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
    }

    private func radioRow(name: String) -> some View {
        let isSelected = selectedCommand == name

        return Button {
            selectedCommand = isSelected ? nil : name
            saveSelection()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 13))
                    .foregroundColor(isSelected ? .themePrimaryHover : .themeTextMuted)

                Text(name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isSelected ? .white : .themeTextSecondary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.themePrimary.opacity(0.1) : Color.white.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.themePrimary.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private func loadSelection() {
        selectedCommand = UserDefaults.standard.string(forKey: key)
    }

    private func saveSelection() {
        if let cmd = selectedCommand {
            UserDefaults.standard.set(cmd, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
