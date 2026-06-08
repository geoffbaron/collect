import SwiftUI

// MARK: - Listing Status

enum ListingStatus: String, CaseIterable {
    case notListed  = "not_listed"
    case ready      = "ready"
    case listed     = "listed"
    case pending    = "pending"
    case sold       = "sold"

    var displayName: String {
        switch self {
        case .notListed: "Not Listed"
        case .ready:     "Ready"
        case .listed:    "Listed"
        case .pending:   "Pending"
        case .sold:      "Sold"
        }
    }

    var icon: String {
        switch self {
        case .notListed: "tag"
        case .ready:     "shippingbox"
        case .listed:    "storefront"
        case .pending:   "clock"
        case .sold:      "checkmark.seal.fill"
        }
    }

    var color: Color {
        switch self {
        case .notListed: .secondary
        case .ready:     .purple
        case .listed:    .blue
        case .pending:   .orange
        case .sold:      .green
        }
    }
}

// MARK: - Marketplace

enum Marketplace: String, CaseIterable, Identifiable {
    case facebook   = "facebook"
    case craigslist = "craigslist"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .facebook:   "Facebook Marketplace"
        case .craigslist: "Craigslist"
        }
    }

    var shortName: String {
        switch self {
        case .facebook:   "Facebook"
        case .craigslist: "Craigslist"
        }
    }

    var icon: String {
        switch self {
        case .facebook:   "person.2.wave.2"
        case .craigslist: "list.bullet.rectangle"
        }
    }

    /// Try to open the native app first; fall back to the web URL.
    func open() {
        let app = URL(string: appScheme)
        let web = webURL
        if let app, UIApplication.shared.canOpenURL(app) {
            UIApplication.shared.open(app)
        } else {
            UIApplication.shared.open(web)
        }
    }

    private var appScheme: String {
        switch self {
        case .facebook:   "fb://marketplace"
        case .craigslist: "https://post.craigslist.org/"
        }
    }

    var webURL: URL {
        switch self {
        case .facebook:
            return URL(string: "https://www.facebook.com/marketplace/create/item")!
        case .craigslist:
            return URL(string: "https://post.craigslist.org/")!
        }
    }
}
