import SwiftUI

struct ResizableTerminalGrid<Content: View>: View {
    let rows: Int
    let columns: Int
    let spacing: CGFloat
    @ViewBuilder let content: (Int) -> Content

    var body: some View {
        GeometryReader { geometry in
            let availableHeight = max(0, geometry.size.height - CGFloat(rows - 1) * spacing)
            let rowHeight = availableHeight / CGFloat(rows)

            VStack(spacing: spacing) {
                ForEach(0..<rows, id: \.self) { row in
                    ResizableTerminalRow(columns: columns, spacing: spacing) { column in
                        content(row * columns + column)
                    }
                    .id("row-\(row)-cols-\(columns)")
                    .frame(height: rowHeight)
                }
            }
        }
    }
}

private struct ResizableTerminalRow<Content: View>: View {
    let columns: Int
    let spacing: CGFloat
    @ViewBuilder let content: (Int) -> Content

    @EnvironmentObject private var themeManager: ThemeManager
    @State private var weights: [CGFloat]
    @State private var dragStartWeights: [CGFloat]?
    @State private var hoveredDivider: Int?
    @State private var activeDivider: Int?

    init(columns: Int, spacing: CGFloat, @ViewBuilder content: @escaping (Int) -> Content) {
        self.columns = columns
        self.spacing = spacing
        self.content = content
        _weights = State(initialValue: Array(repeating: 1 / CGFloat(columns), count: columns))
    }

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = max(1, geometry.size.width - CGFloat(columns - 1) * spacing)
            let normalizedWeights = normalized(weights)

            ZStack(alignment: .topLeading) {
                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { column in
                        content(column)
                            .frame(
                                width: availableWidth * normalizedWeights[column],
                                height: geometry.size.height
                            )
                    }
                }

                if columns > 1 {
                    ForEach(0..<(columns - 1), id: \.self) { divider in
                        resizeHandle(
                            divider: divider,
                            availableWidth: availableWidth,
                            height: geometry.size.height,
                            normalizedWeights: normalizedWeights
                        )
                    }
                }
            }
            .transaction { $0.animation = nil }
        }
    }

    private func resizeHandle(
        divider: Int,
        availableWidth: CGFloat,
        height: CGFloat,
        normalizedWeights: [CGFloat]
    ) -> some View {
        let theme = themeManager.current
        let precedingWidth = normalizedWeights.prefix(divider + 1).reduce(0, +) * availableWidth
        let precedingSpacing = CGFloat(divider) * spacing
        let xPosition = precedingWidth + precedingSpacing + spacing / 2
        let handleWidth = max(10, spacing)
        let isHighlighted = hoveredDivider == divider || activeDivider == divider

        return ZStack {
            Color.clear
            Capsule()
                .fill(isHighlighted ? theme.accent : theme.borderStrong.opacity(0.6))
                .frame(width: isHighlighted ? 3 : 2, height: isHighlighted ? 46 : 24)
                .opacity(isHighlighted ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.14), value: isHighlighted)
        }
        .frame(width: handleWidth, height: height)
        .contentShape(Rectangle())
        .offset(x: xPosition - handleWidth / 2)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    activeDivider = divider
                    let start = dragStartWeights ?? normalizedWeights
                    if dragStartWeights == nil { dragStartWeights = start }

                    let pairTotal = start[divider] + start[divider + 1]
                    let minimumWidth = min(120, availableWidth / CGFloat(columns) * 0.55)
                    let minimumWeight = minimumWidth / availableWidth
                    let delta = value.translation.width / availableWidth
                    let left = min(pairTotal - minimumWeight, max(minimumWeight, start[divider] + delta))

                    var updated = start
                    updated[divider] = left
                    updated[divider + 1] = pairTotal - left
                    weights = updated
                }
                .onEnded { _ in
                    dragStartWeights = nil
                    activeDivider = nil
                }
        )
        .onHover { hovering in
            hoveredDivider = hovering ? divider : (hoveredDivider == divider ? nil : hoveredDivider)
            if hovering {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
        }
        .help("Kéo để thay đổi chiều rộng Terminal")
    }

    private func normalized(_ values: [CGFloat]) -> [CGFloat] {
        guard values.count == columns else {
            return Array(repeating: 1 / CGFloat(columns), count: columns)
        }
        let total = values.reduce(0, +)
        guard total > 0 else { return Array(repeating: 1 / CGFloat(columns), count: columns) }
        return values.map { $0 / total }
    }
}
