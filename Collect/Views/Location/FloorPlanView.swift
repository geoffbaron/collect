import SwiftUI

// MARK: - Coordinate converter

struct FloorPlanConverter {
    let bounds: CGRect
    let scale: CGFloat
    let ox: CGFloat
    let oy: CGFloat

    init(layout: RoomLayout, size: CGSize, padding: CGFloat = 20) {
        bounds = layout.bounds
        let aw = size.width  - padding * 2
        let ah = size.height - padding * 2
        scale  = bounds.width > 0 && bounds.height > 0
            ? min(aw / bounds.width, ah / bounds.height)
            : 1
        ox = padding + (aw - bounds.width  * scale) / 2
        oy = padding + (ah - bounds.height * scale) / 2
    }

    /// Room coordinates → canvas point
    func pt(_ x: Float, _ z: Float) -> CGPoint {
        CGPoint(x: (CGFloat(x) - bounds.minX) * scale + ox,
                y: (CGFloat(z) - bounds.minY) * scale + oy)
    }

    /// Canvas point → room coordinates (inverse transform)
    func roomCoord(from screen: CGPoint) -> (x: Float, z: Float) {
        (x: Float((screen.x - ox) / scale) + Float(bounds.minX),
         z: Float((screen.y - oy) / scale) + Float(bounds.minY))
    }

    /// Adjust a tap location from the outer frame into the zoomed/panned content space.
    func adjustedForZoom(_ tap: CGPoint, geoSize: CGSize, zoom: CGFloat, pan: CGSize) -> CGPoint {
        let cx = geoSize.width  / 2
        let cy = geoSize.height / 2
        return CGPoint(
            x: (tap.x - cx - pan.width)  / zoom + cx,
            y: (tap.y - cy - pan.height) / zoom + cy
        )
    }
}

// MARK: - Main view

struct FloorPlanView: View {
    let layout: RoomLayout
    var assets: [Asset] = []
    var showLegend: Bool = true
    var showLabel: Bool  = false

    @Environment(\.modelContext) private var modelContext
    @State private var selectedAsset: Asset?

    // Zoom / pan
    @State private var steadyZoom: CGFloat = 1.0
    @State private var gestureZoom: CGFloat = 1.0
    @State private var steadyPan:   CGSize  = .zero
    @State private var gesturePan:  CGSize  = .zero

    // Pin placement mode
    @State private var isPinMode  = false
    @State private var pinQueue:  [Asset] = []   // snapshot of unpinned assets at mode entry
    @State private var pinIndex   = 0

    private var currentZoom: CGFloat { steadyZoom * gestureZoom }
    private var currentPan: CGSize {
        CGSize(width: steadyPan.width + gesturePan.width,
               height: steadyPan.height + gesturePan.height)
    }

    private var currentPinAsset: Asset? {
        guard isPinMode, pinIndex < pinQueue.count else { return nil }
        return pinQueue[pinIndex]
    }

    var body: some View {
        GeometryReader { geo in
            let conv = FloorPlanConverter(layout: layout, size: geo.size)

            ZStack(alignment: .bottomLeading) {
                Color(uiColor: .secondarySystemBackground)
                    .ignoresSafeArea()

                // ── Zoomable content ──────────────────────────────────
                ZStack {
                    Canvas { ctx, _ in
                        drawWalls(ctx, conv)
                        drawOpenings(ctx, conv)
                        drawObjectBoxes(ctx, conv)
                    }

                    // Emoji labels for detected objects
                    ForEach(Array(layout.objects.enumerated()), id: \.offset) { _, obj in
                        let fontSize = max(10, min(22, conv.scale * 0.6))
                        Text(emoji(obj.category))
                            .font(.system(size: fontSize))
                            .position(conv.pt(obj.centerX, obj.centerZ))
                    }

                    // Placed asset pins (orange)
                    let pinnedAssets = assets.filter { $0.hasPinnedPosition }
                    ForEach(pinnedAssets) { asset in
                        if let x = asset.layoutX, let z = asset.layoutZ {
                            AssetPin(asset: asset,
                                     scale: conv.scale,
                                     isActive: isPinMode && asset.id == currentPinAsset?.id)
                                .position(conv.pt(x, z))
                                .onTapGesture {
                                    if !isPinMode { selectedAsset = asset }
                                }
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .scaleEffect(currentZoom)
                .offset(currentPan)
                .gesture(
                    SimultaneousGesture(
                        MagnificationGesture()
                            .onChanged { v in gestureZoom = v }
                            .onEnded { v in
                                steadyZoom = max(1.0, min(steadyZoom * v, 6.0))
                                gestureZoom = 1.0
                                if steadyZoom == 1.0 { steadyPan = .zero }
                            },
                        DragGesture()
                            .onChanged { v in gesturePan = v.translation }
                            .onEnded { _ in
                                steadyPan = currentPan
                                gesturePan = .zero
                            }
                    )
                )
                .onTapGesture(count: 2) {
                    withAnimation(.spring(response: 0.3)) {
                        steadyZoom = 1.0; gestureZoom = 1.0
                        steadyPan  = .zero; gesturePan = .zero
                    }
                }

                // ── Pin-mode tap overlay (above content, inside ZStack) ──
                if isPinMode {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            guard let asset = currentPinAsset else { return }
                            let adjusted = conv.adjustedForZoom(
                                location,
                                geoSize: geo.size,
                                zoom: currentZoom,
                                pan: currentPan
                            )
                            let (x, z) = conv.roomCoord(from: adjusted)
                            withAnimation(.spring(response: 0.2)) {
                                asset.layoutX = x
                                asset.layoutZ = z
                            }
                            try? modelContext.save()
                            advance()
                        }
                }

                // ── Fixed overlays (not zoomed) ──────────────────────
                if showLabel {
                    Text(layout.roomName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                        .padding(10)
                }

                if showLegend && !isPinMode {
                    legendView.padding(10)
                }
            }
            // ── Top banner (unpinned count) ──────────────────────────
            .overlay(alignment: .top) {
                let unpinned = assets.filter { !$0.hasPinnedPosition }
                if showLegend && !isPinMode && !unpinned.isEmpty {
                    Button {
                        enterPinMode()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.slash")
                            Text("\(unpinned.count) item\(unpinned.count == 1 ? "" : "s") not yet placed")
                            Spacer()
                            Text("Place All")
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(.orange.opacity(0.9), in: RoundedRectangle(cornerRadius: 10))
                        .padding(.top, 8)
                        .padding(.horizontal, 12)
                    }
                }
            }
            // ── Bottom pin-mode card ─────────────────────────────────
            .overlay(alignment: .bottom) {
                if isPinMode {
                    pinModeCard
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3), value: isPinMode)
        }
        .toolbar {
            if showLegend {
                ToolbarItem(placement: .primaryAction) {
                    if isPinMode {
                        Button("Done") {
                            withAnimation { isPinMode = false }
                        }
                        .fontWeight(.semibold)
                    } else {
                        let count = assets.filter { !$0.hasPinnedPosition }.count
                        if count > 0 {
                            Button("Place \(count)") {
                                enterPinMode()
                            }
                            .fontWeight(.semibold)
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedAsset) { asset in
            AssetFloorPlanPopup(asset: asset)
        }
    }

    // MARK: - Pin mode helpers

    private func enterPinMode() {
        pinQueue = assets.filter { !$0.hasPinnedPosition }
        pinIndex = 0
        guard !pinQueue.isEmpty else { return }
        withAnimation { isPinMode = true }
    }

    private func advance() {
        if pinIndex + 1 < pinQueue.count {
            withAnimation { pinIndex += 1 }
        } else {
            withAnimation { isPinMode = false }
        }
    }

    // MARK: - Pin mode card UI

    private var pinModeCard: some View {
        VStack(spacing: 14) {
            // Progress bar + counter
            HStack(spacing: 10) {
                Button {
                    if pinIndex > 0 { withAnimation { pinIndex -= 1 } }
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                        .foregroundStyle(pinIndex > 0 ? Color.blue : Color.secondary.opacity(0.4))
                }
                .disabled(pinIndex == 0)

                ProgressView(value: Double(pinIndex), total: Double(max(pinQueue.count, 1)))
                    .tint(.blue)

                Text("\(pinIndex + 1) / \(pinQueue.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, alignment: .trailing)
            }

            if let asset = currentPinAsset {
                HStack(spacing: 12) {
                    // Thumbnail or initial
                    if let data = asset.photo1Data, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.blue.opacity(0.12))
                                .frame(width: 48, height: 48)
                            Text(String(asset.name.prefix(1)).uppercased())
                                .font(.title3.bold())
                                .foregroundStyle(.blue)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(asset.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text(asset.category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button("Skip") { advance() }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    Image(systemName: "hand.tap")
                    Text("Tap the floor plan to place this item")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
        .shadow(color: .black.opacity(0.12), radius: 12, y: -4)
    }

    // MARK: - Legend

    private var legendView: some View {
        HStack(spacing: 10) {
            legendItem(.primary, "Wall")
            legendItem(.brown, "Door")
            legendItem(Color(uiColor: .systemCyan), "Window")
            if assets.contains(where: { $0.hasPinnedPosition }) {
                legendItem(.orange, "Asset")
            }
        }
        .font(.caption2)
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func legendItem(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(color)
                .frame(width: 14, height: 3)
            Text(label).foregroundStyle(color)
        }
    }

    // MARK: - Canvas drawing

    private func drawWalls(_ ctx: GraphicsContext, _ conv: FloorPlanConverter) {
        let lw = max(3, conv.scale * 0.14)
        for w in layout.walls {
            let c = CGFloat(cos(w.yaw)), s = CGFloat(sin(w.yaw)), hw = CGFloat(w.width) / 2
            let p1 = conv.pt(w.centerX + Float(c * hw), w.centerZ + Float(s * hw))
            let p2 = conv.pt(w.centerX - Float(c * hw), w.centerZ - Float(s * hw))
            var path = Path()
            path.move(to: p1); path.addLine(to: p2)
            ctx.stroke(path, with: .color(.primary),
                       style: StrokeStyle(lineWidth: lw, lineCap: .square))
        }
    }

    private func drawOpenings(_ ctx: GraphicsContext, _ conv: FloorPlanConverter) {
        let lw = max(2, conv.scale * 0.09)
        for o in layout.openings {
            let c = CGFloat(cos(o.yaw)), s = CGFloat(sin(o.yaw)), hw = CGFloat(o.width) / 2
            let p1 = conv.pt(o.centerX + Float(c * hw), o.centerZ + Float(s * hw))
            let p2 = conv.pt(o.centerX - Float(c * hw), o.centerZ - Float(s * hw))

            var path = Path()
            path.move(to: p1); path.addLine(to: p2)

            switch o.kind {
            case .door:
                ctx.stroke(path, with: .color(Color(uiColor: .secondarySystemBackground)),
                           style: StrokeStyle(lineWidth: lw * 2.5, lineCap: .round))
                ctx.stroke(path, with: .color(.brown),
                           style: StrokeStyle(lineWidth: lw, lineCap: .round))
                let r = CGFloat(o.width) * conv.scale * 0.85
                var arc = Path()
                arc.addArc(center: p1, radius: r,
                           startAngle: .radians(Double(atan2(p2.y - p1.y, p2.x - p1.x))),
                           endAngle: .radians(Double(atan2(p2.y - p1.y, p2.x - p1.x)) - .pi / 2),
                           clockwise: true)
                ctx.stroke(arc, with: .color(.brown.opacity(0.5)),
                           style: StrokeStyle(lineWidth: 1))
            case .window:
                ctx.stroke(path, with: .color(Color(uiColor: .systemCyan)),
                           style: StrokeStyle(lineWidth: lw, dash: [5, 4]))
            case .opening:
                ctx.stroke(path, with: .color(.secondary),
                           style: StrokeStyle(lineWidth: lw, dash: [3, 3]))
            }
        }
    }

    private func drawObjectBoxes(_ ctx: GraphicsContext, _ conv: FloorPlanConverter) {
        for obj in layout.objects {
            let w = CGFloat(obj.width) * conv.scale
            let d = CGFloat(obj.depth) * conv.scale
            guard w > 6, d > 6 else { continue }
            let center = conv.pt(obj.centerX, obj.centerZ)

            ctx.withCGContext { cg in
                cg.saveGState()
                cg.translateBy(x: center.x, y: center.y)
                cg.rotate(by: CGFloat(obj.yaw))
                let rect = CGRect(x: -w/2, y: -d/2, width: w, height: d)
                cg.setFillColor(UIColor.systemBlue.withAlphaComponent(0.12).cgColor)
                cg.setStrokeColor(UIColor.systemBlue.withAlphaComponent(0.45).cgColor)
                cg.setLineWidth(1.5)
                cg.addPath(UIBezierPath(roundedRect: rect, cornerRadius: 4).cgPath)
                cg.drawPath(using: .fillStroke)
                cg.restoreGState()
            }
        }
    }

    // MARK: - Emoji map

    private func emoji(_ category: String) -> String {
        switch category {
        case "sofa":        return "🛋️"
        case "bed":         return "🛏️"
        case "chair":       return "🪑"
        case "table":       return "🍽️"
        case "television":  return "📺"
        case "refrigerator":return "🧊"
        case "toilet":      return "🚽"
        case "bathtub":     return "🛁"
        case "sink":        return "🚿"
        case "stove":       return "🍳"
        case "storage":     return "🗄️"
        case "fireplace":   return "🔥"
        case "dishwasher",
             "washerDryer": return "🫧"
        case "stairs":      return "🪜"
        default:            return "📦"
        }
    }
}

// MARK: - Pin Drop (single asset, from AssetDetailView)

struct FloorPlanPinView: View {
    let layout: RoomLayout
    var initialX: Float? = nil
    var initialZ: Float? = nil
    var onPlace: (Float, Float) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var pendingX: Float?
    @State private var pendingZ: Float?

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                let conv = FloorPlanConverter(layout: layout, size: geo.size)

                ZStack {
                    FloorPlanView(layout: layout, showLegend: false)

                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            let (x, z) = conv.roomCoord(from: location)
                            withAnimation(.spring(response: 0.18)) {
                                pendingX = x
                                pendingZ = z
                            }
                        }

                    if let x = pendingX, let z = pendingZ {
                        PinShape()
                            .position(conv.pt(x, z))
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if pendingX == nil {
                    Label("Tap the floor plan where this item is located", systemImage: "hand.tap")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                }
            }
            .navigationTitle("Pin Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Place Here") {
                        if let x = pendingX, let z = pendingZ {
                            onPlace(x, z)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(pendingX == nil)
                }
            }
        }
        .onAppear {
            pendingX = initialX
            pendingZ = initialZ
        }
    }
}

private struct PinShape: View {
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(.red)
                    .frame(width: 30, height: 30)
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
                Circle()
                    .stroke(.white, lineWidth: 2.5)
                    .frame(width: 30, height: 30)
            }
            Triangle()
                .fill(.red)
                .frame(width: 10, height: 10)
        }
        .offset(y: -20)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Asset Pin

private struct AssetPin: View {
    let asset: Asset
    let scale: CGFloat
    var isActive: Bool = false

    private let size: CGFloat = 28

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(isActive ? Color.blue : Color.orange)
                    .frame(width: size, height: size)
                    .shadow(radius: isActive ? 4 : 2)
                    .scaleEffect(isActive ? 1.25 : 1.0)

                if let data = asset.photo1Data, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size - 4, height: size - 4)
                        .clipShape(Circle())
                } else {
                    Text(String(asset.name.prefix(1)).uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            Rectangle()
                .fill(isActive ? Color.blue : Color.orange)
                .frame(width: 2, height: 6)
        }
        .animation(.spring(response: 0.25), value: isActive)
    }
}

// MARK: - Asset tap popup

private struct AssetFloorPlanPopup: View {
    let asset: Asset
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let data = asset.photo1Data, let img = UIImage(data: data) {
                    Section {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipped()
                            .listRowInsets(EdgeInsets())
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                Section {
                    LabeledContent("Name", value: asset.name)
                    LabeledContent("Category", value: asset.category)
                    if let cond = asset.condition { LabeledContent("Condition", value: cond) }
                    LabeledContent("Qty", value: "\(asset.quantity)")
                    if let val = asset.estimatedValue {
                        LabeledContent("Est. Value", value: val, format: .currency(code: "USD"))
                    }
                }

                if !asset.assetDescription.isEmpty {
                    Section("Description") {
                        Text(asset.assetDescription).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(asset.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
