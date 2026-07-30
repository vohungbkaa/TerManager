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
            if isOpen { popover }
        }
    }

    private var trigger: some View {
        Button {
            isOpen.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "square.grid.3x3")
                Text("Bố cục: \(grid.rows)×\(grid.cols)")
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .font(.system(size: 11, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isOpen ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .onHover { hovering in
            if !hovering && !isOpen { isOpen = false }
        }
    }

    private var popover: some View {
        VStack(spacing: 8) {
            Text("Chọn bố cục lưới")
                .font(.caption.weight(.semibold))

            // Matrix
            VStack(spacing: 3) {
                ForEach(1...maxDim, id: \.self) { r in
                    HStack(spacing: 3) {
                        ForEach(1...maxDim, id: \.self) { c in
                            let active = r <= currentRows && c <= currentCols
                            let selected = r <= grid.rows && c <= grid.cols
                            RoundedRectangle(cornerRadius: 3)
                                .fill(active ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.12))
                                .overlay(
                                    selected && hoverRows == 0
                                        ? RoundedRectangle(cornerRadius: 3)
                                            .stroke(Color.accentColor, lineWidth: 2)
                                        : nil
                                )
                                .frame(width: 22, height: 22)
                                .onHover { h in
                                    if h { hoverRows = r; hoverCols = c }
                                    else { hoverRows = 0; hoverCols = 0 }
                                }
                                .onTapGesture { select(r, c) }
                        }
                    }
                }
            }

            // Status
            Text("\(currentRows)×\(currentCols) Terminal\(currentRows * currentCols == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.vertical, 2)

            // Presets
            HStack(spacing: 4) {
                presetButton("1×1", 1, 1)
                presetButton("1×2", 1, 2)
                presetButton("2×2", 2, 2)
                presetButton("2×3", 2, 3)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
        )
        .frame(width: 180)
        .offset(y: 30)
    }

    private func presetButton(_ label: String, _ r: Int, _ c: Int) -> some View {
        Button(label) { select(r, c) }
            .buttonStyle(.plain)
            .font(.system(size: 10))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.08))
            )
    }

    private func select(_ rows: Int, _ cols: Int) {
        grid = GridSize(rows: rows, cols: cols)
        isOpen = false
        hoverRows = 0
        hoverCols = 0
    }
}
