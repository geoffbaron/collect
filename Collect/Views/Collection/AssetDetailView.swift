import SwiftUI
import MapKit

struct AssetDetailView: View {
    @Bindable var asset: Asset
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var showDeleteConfirm = false
    @State private var selectedPhotoIndex = 0
    @State private var showPinDrop = false

    private var roomLayout: RoomLayout? {
        asset.collection?.room?.layoutData.flatMap { RoomLayout.from($0) }
    }

    var body: some View {
        List {
            // Photo carousel
            if !asset.photos.isEmpty {
                Section {
                    TabView(selection: $selectedPhotoIndex) {
                        ForEach(Array(asset.photos.enumerated()), id: \.offset) { idx, data in
                            if let img = UIImage(data: data) {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 220)
                                    .clipped()
                                    .tag(idx)
                            }
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .frame(height: 220)
                    .listRowInsets(EdgeInsets())
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            Section {
                if isEditing {
                    LabeledContent("Name") {
                        TextField("Name", text: $asset.name)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Category") {
                        TextField("Category", text: $asset.category)
                            .multilineTextAlignment(.trailing)
                    }
                } else {
                    LabeledContent("Name", value: asset.name)
                    LabeledContent("Category", value: asset.category)
                }
            }

            Section("Details") {
                if let condition = asset.condition, !condition.isEmpty {
                    LabeledContent("Condition", value: condition)
                }

                LabeledContent("Quantity") {
                    if isEditing {
                        Stepper("\(asset.quantity)", value: $asset.quantity, in: 1...999)
                    } else {
                        Text("\(asset.quantity)")
                    }
                }

                if isEditing {
                    LabeledContent("Value (USD)") {
                        TextField("$0", value: $asset.estimatedValue, format: .currency(code: "USD"))
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                } else if let val = asset.estimatedValue {
                    LabeledContent("Est. Value", value: val, format: .currency(code: "USD"))
                }

                LabeledContent("Confidence") {
                    HStack(spacing: 8) {
                        ProgressView(value: asset.confidence)
                            .frame(width: 80)
                        Text("\(Int(asset.confidence * 100))%")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("Confirmed") {
                    Toggle("", isOn: $asset.isConfirmed)
                        .labelsHidden()
                }
            }

            if !asset.assetDescription.isEmpty {
                Section("Description") {
                    if isEditing {
                        TextField("Description", text: $asset.assetDescription, axis: .vertical)
                            .lineLimit(3...8)
                    } else {
                        Text(asset.assetDescription)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Floor plan location
            Section("Floor Plan Location") {
                if let layout = roomLayout {
                    if asset.hasPinnedPosition {
                        // Mini floor plan preview with pin
                        FloorPlanView(layout: layout, assets: [asset], showLegend: false)
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .listRowInsets(EdgeInsets())
                        Button {
                            showPinDrop = true
                        } label: {
                            Label("Move Pin", systemImage: "mappin.and.ellipse")
                        }
                        Button(role: .destructive) {
                            asset.layoutX = nil
                            asset.layoutZ = nil
                        } label: {
                            Label("Remove Pin", systemImage: "mappin.slash")
                        }
                    } else {
                        Button {
                            showPinDrop = true
                        } label: {
                            Label("Pin to Floor Plan", systemImage: "mappin.and.ellipse")
                                .foregroundStyle(.blue)
                        }
                    }
                } else {
                    Label("Scan this room's layout to enable floor plan pinning", systemImage: "map")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // GPS Location
            if let lat = asset.latitude, let lon = asset.longitude {
                Section("Location") {
                    let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    let region = MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.001, longitudeDelta: 0.001)
                    )
                    Map(initialPosition: .region(region)) {
                        Marker(asset.name, coordinate: coord)
                    }
                    .frame(height: 160)
                    .listRowInsets(EdgeInsets())
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    LabeledContent("Latitude",  value: String(format: "%.6f", lat))
                    LabeledContent("Longitude", value: String(format: "%.6f", lon))
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Remove Item", systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle(asset.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                }
            }
        }
        .sheet(isPresented: $showPinDrop) {
            if let layout = roomLayout {
                FloorPlanPinView(
                    layout: layout,
                    initialX: asset.layoutX,
                    initialZ: asset.layoutZ
                ) { x, z in
                    asset.layoutX = x
                    asset.layoutZ = z
                }
            }
        }
        .confirmationDialog(
            "Remove \"\(asset.name)\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Remove Item", role: .destructive) {
                modelContext.delete(asset)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This item will be permanently removed from the scan.")
        }
    }
}
