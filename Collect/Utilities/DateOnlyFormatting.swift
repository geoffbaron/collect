import Foundation

/// Formats "YYYY-MM-DD" date-only strings (as stored/returned by Supabase)
/// for display, without going through a timezone-aware Date conversion.
extension String {
    var formattedAsDateOnly: String {
        let parts = split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else {
            return self
        }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let date = Calendar.current.date(from: components) else { return self }
        return date.formatted(.dateTime.month().day().year())
    }
}
