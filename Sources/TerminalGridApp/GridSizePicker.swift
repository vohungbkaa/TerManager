import SwiftUI

struct GridSizePicker: View {
    @Binding var grid: GridSize
    @State private var isOpen = false
    @State private var hoverRows = 0
    @State private var hoverCols = 0

    private let maxDim = 3

    var currentRows: Int { hoverRows > 0 ? hoverRows : grid.rows }
    var currentCols: Int { hoverCols > 0 ? hoverCols : grid.cols }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            trigger
            if isOpen {
                popover
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
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
        VStack(spacing: 10) {
            Text("CHỌN BỐ CỤC LƯỚI")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.themeTextMuted)
                .padding(.top, 4)

            // Matrix
            VStack(spacing: 4) {
                ForEach(1...maxDim, id: \.self) { r in
                    HStack(spacing: 4) {
                        ForEach(1...maxDim, id: \.self) { c in
                            let active = r <= currentRows && c <= currentCols
                            let selected = r <= grid.rows && c <= grid.cols
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(active ? (selected ? Color.themePrimary.opacity(0.5) : Color.themePrimary.opacity(0.4)) : (selected ? Color.themePrimary.opacity(0.2) : Color.white.opacity(0.02)))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(active ? Color.themePrimaryHover : (selected ? Color.themePrimary.opacity(0.5) : Color.white.opacity(0.15)), lineWidth: 1)
                                )
                                .frame(width: 22, height: 22)
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
                .font(.system(size: 11, weight: .semibold))
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
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 15/255, green: 16/255, blue: 21/255)) // #0F1015
                .shadow(color: .black.opacity(0.5), radius: 15, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .frame(width: 170)
        .offset(y: 40)
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
                .padding(.vertical, 5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? Color.themePrimary.opacity(0.15) : Color.white.opacity(0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isHovered ? Color.themePrimary.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
    }
}
