import SwiftUI

struct GridSizePicker: View {
    @EnvironmentObject private var store: ProjectStore
    @Binding var grid: GridSize
    var entityID: String? = nil

    @State private var isOpen = false
    @State private var hoverRows = 0
    @State private var hoverCols = 0

    private let maxDim = 3

    var currentRows: Int { hoverRows > 0 ? hoverRows : grid.rows }
    var currentCols: Int { hoverCols > 0 ? hoverCols : grid.cols }

    private var hiddenCount: Int {
        guard let id = entityID else { return 0 }
        return store.hiddenPanesCount(for: id)
    }

    var body: some View {
        trigger
            .zIndex(98)
            .overlay(alignment: .topTrailing) {
                if isOpen {
                    ZStack(alignment: .topTrailing) {
                        // Invisible overlay to detect clicks outside without stretching parent layout
                        Color.black.opacity(0.001)
                            .frame(width: 2000, height: 2000)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    isOpen = false
                                }
                            }
                        
                        popover
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(red: 15/255, green: 16/255, blue: 21/255))
                                    .shadow(color: .black.opacity(0.5), radius: 15, y: 8)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .offset(y: 35)
                    }
                }
            }
    }

    private var trigger: some View {
        Button {
            withAnimation(.easeOut(duration: 0.15)) {
                isOpen.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: 13))
                    .foregroundColor(isOpen ? .themePrimaryHover : .themeTextSecondary)

                Text("Bố cục: \(grid.rows) × \(grid.cols)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isOpen ? .white : .themeTextSecondary)

                if hiddenCount > 0 {
                    Text("+\(hiddenCount) ẩn")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.themeGreen)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.themeGreen.opacity(0.18))
                        .cornerRadius(4)
                }

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.themeTextMuted)
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isOpen ? Color.white.opacity(0.06) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isOpen ? Color.themePrimary : Color.white.opacity(0.06), lineWidth: 1)
                .shadow(color: isOpen ? Color.themePrimaryGlow : Color.clear, radius: 6)
        )
    }

    private var popover: some View {
        VStack(spacing: 12) {
            if let id = entityID, hiddenCount > 0 {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        store.restoreAllHiddenPanes(for: id)
                        isOpen = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 13))
                            .foregroundColor(.themeGreen)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Khôi phục \(hiddenCount) Terminal ẩn")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                            Text("Trở về đúng vị trí & trạng thái")
                                .font(.system(size: 9.5))
                                .foregroundColor(.themeTextSecondary)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.themeGreen.opacity(0.18))
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.themeGreen.opacity(0.45), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            Text("CHỌN BỐ CỤC LƯỚI")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.themeTextMuted)
                .padding(.top, 4)

            // Matrix
            VStack(spacing: 5) {
                ForEach(1...maxDim, id: \.self) { r in
                    HStack(spacing: 5) {
                        ForEach(1...maxDim, id: \.self) { c in
                            let active = r <= currentRows && c <= currentCols
                            let selected = r <= grid.rows && c <= grid.cols

                            RoundedRectangle(cornerRadius: 4)
                                .fill(active ? (selected ? Color.themePrimary.opacity(0.5) : Color.themePrimary.opacity(0.4)) : (selected ? Color.themePrimary.opacity(0.2) : Color.white.opacity(0.04)))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(active ? Color.themePrimaryHover : (selected ? Color.themePrimary.opacity(0.5) : Color.white.opacity(0.15)), lineWidth: 1)
                                )
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                                .onHover { h in
                                    if h {
                                        hoverRows = r
                                        hoverCols = c
                                    } else {
                                        hoverRows = 0
                                        hoverCols = 0
                                    }
                                }
                                .onTapGesture {
                                    select(r, c)
                                }
                        }
                    }
                }
            }
            .padding(.bottom, 4)

            // Status
            Text("\(currentRows) × \(currentCols) \(currentRows * currentCols == 1 ? "Terminal" : "Terminals")")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 6)
                .frame(maxWidth: .infinity)
                .overlay(
                    Rectangle()
                        .fill(Color.themeBorder)
                        .frame(height: 1),
                    alignment: .bottom
                )

            // Presets
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    presetButton("1×1 (Đơn)", 1, 1)
                    presetButton("1×2 (Đôi)", 1, 2)
                }
                HStack(spacing: 6) {
                    presetButton("2×2 (Bốn)", 2, 2)
                    presetButton("2×3 (Sáu)", 2, 3)
                }
                HStack(spacing: 6) {
                    presetButton("3×3 (Chín)", 3, 3)
                }
            }
        }
        .padding(14)
        .frame(width: 180)
    }

    private func presetButton(_ label: String, _ r: Int, _ c: Int) -> some View {
        PresetButton(label: label) {
            select(r, c)
        }
    }

    private func select(_ rows: Int, _ cols: Int) {
        withAnimation(.easeOut(duration: 0.15)) {
            grid = GridSize(rows: rows, cols: cols)
            isOpen = false
            hoverRows = 0
            hoverCols = 0
        }
    }
}

struct PresetButton: View {
    let label: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button {
            action()
        } label: {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isHovered ? .white : .themeTextSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? Color.themePrimary.opacity(0.18) : Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isHovered ? Color.themePrimary.opacity(0.5) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }
}
