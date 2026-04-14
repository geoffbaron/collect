import SwiftUI
import UIKit

/// Wraps UIActivityViewController for use in SwiftUI sheets.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Identifiable wrapper so we can use .sheet(item:) with a URL.
struct ShareItem: Identifiable {
    let id = UUID()
    let url: URL
}
