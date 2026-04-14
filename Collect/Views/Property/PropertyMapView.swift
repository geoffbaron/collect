import SwiftUI
import MapKit

// MARK: - GPS coordinate helpers

/// Convert a room-local point (meters) to a GPS coordinate given an anchor and heading.
/// RoomPlan: +X = right, +Z = toward viewer (south in top-down view).
/// headingDeg rotates the whole floor plan clockwise from north.
private func roomToGPS(_ x: Double, _ z: Double,
                        anchor: CLLocationCoordinate2D,
                        headingRad: Double) -> CLLocationCoordinate2D {
    // Rotate room coords by heading
    let rx =  x * cos(headingRad) - z * sin(headingRad)
    let rz =  x * sin(headingRad) + z * cos(headingRad)
    // rz+ = south (decreases lat), rx+ = east (increases lon)
    let latOff = -rz / 111_111.0
    let lonOff =  rx / (111_111.0 * cos(anchor.latitude * .pi / 180))
    return CLLocationCoordinate2D(latitude:  anchor.latitude  + latOff,
                                  longitude: anchor.longitude + lonOff)
}

private func wallCoords(_ wall: RoomLayout.Wall,
                        anchor: CLLocationCoordinate2D,
                        headingDeg: Double) -> [CLLocationCoordinate2D] {
    let h  = headingDeg * .pi / 180
    let hw = Double(wall.width) / 2
    let c  = cos(Double(wall.yaw)), s = sin(Double(wall.yaw))
    return [
        roomToGPS(Double(wall.centerX) + c * hw, Double(wall.centerZ) + s * hw, anchor: anchor, headingRad: h),
        roomToGPS(Double(wall.centerX) - c * hw, Double(wall.centerZ) - s * hw, anchor: anchor, headingRad: h)
    ]
}

// MARK: - Stable segment type for ForEach inside Map

private struct WallSeg: Identifiable {
    let id: String   // "\(roomID)-\(wallIndex)"
    let coords: [CLLocationCoordinate2D]
    let highlighted: Bool
}

private struct RoomAnn: Identifiable {
    let id: UUID
    let name: String
    let coord: CLLocationCoordinate2D
}

// MARK: - PropertyMapView

struct PropertyMapView: View {
    let property: Property
    @Environment(\.modelContext) private var modelContext

    @State private var camera: MapCameraPosition = .automatic
    @State private var mapCenter = CLLocationCoordinate2D(latitude: 0, longitude: 0)

    // Adjust state
    @State private var selectedRoomID: UUID?
    @State private var isAdjusting    = false
    @State private var adjustAnchor   = CLLocationCoordinate2D(latitude: 0, longitude: 0)
    @State private var adjustHeading: Double = 0

    // MARK: - Derived data

    private var allRoomsWithLayout: [Room] {
        property.sortedFloors.flatMap { $0.sortedRooms }.filter { $0.hasLayout }
    }
    private var placedRooms: [Room]   { allRoomsWithLayout.filter { $0.effectiveMapCenter != nil } }
    private var unplacedRooms: [Room] { allRoomsWithLayout.filter { $0.effectiveMapCenter == nil } }

    private func selectedRoom() -> Room? {
        guard let id = selectedRoomID else { return nil }
        return allRoomsWithLayout.first { $0.id == id }
    }

    private var wallSegs: [WallSeg] {
        placedRooms.flatMap { room -> [WallSeg] in
            // Skip the room being live-adjusted (drawn in overlay)
            guard !(isAdjusting && room.id == selectedRoomID) else { return [] }
            guard let c = room.effectiveMapCenter,
                  let layout = room.layoutData.flatMap({ RoomLayout.from($0) }) else { return [] }
            let anchor = CLLocationCoordinate2D(latitude: c.lat, longitude: c.lon)
            let hi = room.id == selectedRoomID
            return layout.walls.enumerated().map { (i, w) in
                WallSeg(id: "\(room.id)-\(i)",
                        coords: wallCoords(w, anchor: anchor, headingDeg: room.mapHeading),
                        highlighted: hi)
            }
        }
    }

    private var roomAnns: [RoomAnn] {
        placedRooms.compactMap { room -> RoomAnn? in
            guard !(isAdjusting && room.id == selectedRoomID),
                  let c = room.effectiveMapCenter else { return nil }
            return RoomAnn(id: room.id, name: room.name,
                           coord: CLLocationCoordinate2D(latitude: c.lat, longitude: c.lon))
        }
    }

    // MARK: - Body

    var body: some View {
        MapReader { proxy in
            Map(position: $camera) {
                // Static walls for all placed rooms (except the one being adjusted)
                ForEach(wallSegs) { seg in
                    MapPolyline(coordinates: seg.coords)
                        .stroke(seg.highlighted ? Color.blue : Color.orange, lineWidth: 3)
                }
                // Room name label annotations
                ForEach(roomAnns) { ann in
                    Annotation(ann.name, coordinate: ann.coord, anchor: .bottom) {
                        roomLabel(ann)
                    }
                }
            }
            .onMapCameraChange(frequency: .continuous) { ctx in
                mapCenter = ctx.region.center
                if isAdjusting { adjustAnchor = ctx.region.center }
            }
            // Live floor plan overlay for the room being adjusted
            .overlay {
                if isAdjusting, let room = selectedRoom(),
                   let layout = room.layoutData.flatMap({ RoomLayout.from($0) }) {
                    liveFloorPlanCanvas(layout: layout, proxy: proxy)
                    crosshair
                }
            }
            .overlay(alignment: .top) {
                if !unplacedRooms.isEmpty && !isAdjusting {
                    unplacedBanner
                }
            }
            .overlay(alignment: .bottom) {
                bottomCard
            }
        }
        .navigationTitle("Property Map")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.spring(response: 0.3), value: isAdjusting)
        .onAppear { setupCamera() }
    }

    // MARK: - Subviews

    private func roomLabel(_ ann: RoomAnn) -> some View {
        Button {
            if let room = allRoomsWithLayout.first(where: { $0.id == ann.id }) {
                startAdjusting(room)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "pencil.circle.fill")
                    .font(.caption2)
                Text(ann.name)
                    .font(.caption2.weight(.semibold))
            }
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func liveFloorPlanCanvas(layout: RoomLayout, proxy: MapProxy) -> some View {
        Canvas { ctx, _ in
            for wall in layout.walls {
                let coords = wallCoords(wall, anchor: adjustAnchor, headingDeg: adjustHeading)
                guard let p1 = proxy.convert(coords[0], to: .local),
                      let p2 = proxy.convert(coords[1], to: .local) else { continue }
                var path = Path()
                path.move(to: p1); path.addLine(to: p2)
                ctx.stroke(path, with: .color(.blue),
                           style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        }
        .allowsHitTesting(false)
    }

    private var crosshair: some View {
        ZStack {
            Circle()
                .stroke(Color.blue.opacity(0.35), lineWidth: 1)
                .frame(width: 22, height: 22)
            Rectangle().fill(Color.blue).frame(width: 1, height: 14)
            Rectangle().fill(Color.blue).frame(width: 14, height: 1)
        }
        .allowsHitTesting(false)
    }

    private var unplacedBanner: some View {
        VStack(spacing: 0) {
            ForEach(unplacedRooms) { room in
                Button { startAdjusting(room) } label: {
                    HStack {
                        Image(systemName: "mappin.slash")
                        Text(room.name).font(.caption.weight(.medium))
                        Text("— tap to place").font(.caption)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption2)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                }
            }
        }
        .background(.orange.opacity(0.92), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12).padding(.top, 8)
    }

    @ViewBuilder
    private var bottomCard: some View {
        if isAdjusting, let room = selectedRoom() {
            adjustCard(for: room)
        } else if !placedRooms.isEmpty {
            hintPill
        }
    }

    private func adjustCard(for room: Room) -> some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(room.name).font(.headline)
                    Text("Pan map to position · Rotate with slider")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                // Quick reset
                Button {
                    room.mapLatitude = nil; room.mapLongitude = nil
                    try? modelContext.save()
                    cancelAdjusting()
                } label: {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Rotation slider
            HStack(spacing: 8) {
                Image(systemName: "arrow.counterclockwise").font(.caption).foregroundStyle(.secondary)
                Slider(value: $adjustHeading, in: 0...360, step: 1)
                Image(systemName: "arrow.clockwise").font(.caption).foregroundStyle(.secondary)
                Text("\(Int(adjustHeading))°")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") { cancelAdjusting() }
                    .buttonStyle(.bordered).frame(maxWidth: .infinity)
                Button("Place Here") { commitAdjusting(room) }
                    .buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 12).padding(.bottom, 4)
        .shadow(color: .black.opacity(0.12), radius: 12, y: -4)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var hintPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "hand.tap").font(.caption)
            Text("Tap a room label to reposition its floor plan")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 12)
        .transition(.opacity)
    }

    // MARK: - Actions

    private func startAdjusting(_ room: Room) {
        adjustHeading = room.mapHeading
        if let c = room.effectiveMapCenter {
            adjustAnchor = CLLocationCoordinate2D(latitude: c.lat, longitude: c.lon)
            camera = .region(MKCoordinateRegion(
                center: adjustAnchor, latitudinalMeters: 40, longitudinalMeters: 40
            ))
        } else {
            adjustAnchor = mapCenter
        }
        withAnimation {
            selectedRoomID = room.id
            isAdjusting = true
        }
    }

    private func commitAdjusting(_ room: Room) {
        room.mapLatitude  = adjustAnchor.latitude
        room.mapLongitude = adjustAnchor.longitude
        room.mapHeading   = adjustHeading
        try? modelContext.save()
        withAnimation { isAdjusting = false; selectedRoomID = nil }
    }

    private func cancelAdjusting() {
        withAnimation { isAdjusting = false; selectedRoomID = nil }
    }

    private func setupCamera() {
        let anchors = placedRooms.compactMap { $0.effectiveMapCenter }
        guard !anchors.isEmpty else { return }
        let lats = anchors.map(\.lat), lons = anchors.map(\.lon)
        let minLat = lats.min()!, maxLat = lats.max()!
        let minLon = lons.min()!, maxLon = lons.max()!
        let center = CLLocationCoordinate2D(latitude:  (minLat + maxLat) / 2,
                                            longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta:  max(0.0005, (maxLat - minLat) * 3.5),
            longitudeDelta: max(0.0005, (maxLon - minLon) * 3.5)
        )
        camera = .region(MKCoordinateRegion(center: center, span: span))
    }
}
