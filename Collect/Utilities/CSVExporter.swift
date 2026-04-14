import Foundation

struct CSVExporter {

    // MARK: - Single collection

    static func csv(for collection: Collection) -> String {
        let room = collection.room?.name ?? ""
        let floor = collection.room?.floor?.name ?? ""
        let property = collection.room?.floor?.property?.name ?? ""
        let date = collection.capturedAt.formatted(date: .abbreviated, time: .shortened)
        let scanType = collection.prompt.displayName

        var rows: [String] = [header]
        for asset in collection.sortedAssets {
            rows.append(row(asset: asset, property: property, floor: floor, room: room, date: date, scanType: scanType))
        }
        return rows.joined(separator: "\n")
    }

    // MARK: - Entire property

    static func csv(for property: Property) -> String {
        var rows: [String] = [header]
        for floor in property.sortedFloors {
            for room in floor.sortedRooms {
                for collection in room.sortedCollections {
                    let date = collection.capturedAt.formatted(date: .abbreviated, time: .shortened)
                    let scanType = collection.prompt.displayName
                    for asset in collection.sortedAssets {
                        rows.append(row(
                            asset: asset,
                            property: property.name,
                            floor: floor.name,
                            room: room.name,
                            date: date,
                            scanType: scanType
                        ))
                    }
                }
            }
        }
        return rows.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static let header = "Name,Category,Quantity,Condition,Est. Value (USD),Confidence %,Description,Property,Floor,Room,Scan Type,Scan Date"

    private static func row(
        asset: Asset,
        property: String,
        floor: String,
        room: String,
        date: String,
        scanType: String
    ) -> String {
        let value = asset.estimatedValue.map { String(format: "%.2f", $0) } ?? ""
        return [
            escape(asset.name),
            escape(asset.category),
            "\(asset.quantity)",
            escape(asset.condition ?? ""),
            value,
            "\(Int(asset.confidence * 100))",
            escape(asset.assetDescription),
            escape(property),
            escape(floor),
            escape(room),
            escape(scanType),
            escape(date)
        ].joined(separator: ",")
    }

    /// Wrap in quotes and escape any internal quotes per RFC 4180.
    private static func escape(_ value: String) -> String {
        let cleaned = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(cleaned)\""
    }

    // MARK: - Write to temp file

    static func temporaryURL(csv: String, filename: String) -> URL? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename)
            .appendingPathExtension("csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
