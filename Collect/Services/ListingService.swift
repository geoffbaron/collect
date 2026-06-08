import Foundation
import UIKit

// MARK: - Draft

struct ListingDraft {
    var title: String
    var description: String
    var suggestedPrice: Double?
    var priceRationale: String
}

// MARK: - Errors

enum ListingError: LocalizedError {
    case invalidURL
    case serverError(Int, String)
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid listing service URL."
        case .serverError(let code, let msg):
            return "Server error \(code): \(msg.prefix(120))"
        case .parseError:
            return "Could not parse the listing response."
        }
    }
}

// MARK: - Service

actor ListingService {
    static let shared = ListingService()

    private var edgeFunctionURL: String {
        "\(SupabaseManager.projectURL)/functions/v1/generate-listing"
    }

    func generate(asset: Asset, platform: Marketplace) async throws -> ListingDraft {
        // Prefer a refreshed user session JWT; fall back to nil so we send
        // no Authorization header (gateway has verify_jwt = false).
        let accessToken: String? = await {
            // Try to get (and auto-refresh) the current session
            if let session = try? await SupabaseManager.shared.client.auth.session {
                return session.accessToken
            }
            return nil
        }()

        // Encode up to 2 photos as base64 JPEG. Downscale defensively — assets
        // saved before the capture-time cap may hold full-resolution photos, which
        // bloat the request and can make Gemini fail (502).
        let photos: [String] = asset.photos.prefix(2).compactMap { data in
            UIImage(data: data)?
                .downscaled(maxDimension: 768)
                .jpegData(compressionQuality: 0.7)?
                .base64EncodedString()
        }

        var assetPayload: [String: Any] = [
            "id":          asset.id.uuidString,
            "name":        asset.name,
            "category":    asset.category,
            "description": asset.assetDescription,
        ]
        if let c = asset.condition      { assetPayload["condition"]      = c }
        if let v = asset.estimatedValue { assetPayload["estimatedValue"] = v }

        let body: [String: Any] = [
            "photos":   photos,
            "asset":    assetPayload,
            "platform": platform.rawValue,
        ]

        guard let url = URL(string: edgeFunctionURL) else {
            throw ListingError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Always send a Bearer token — gateway requires a header even with verify_jwt=false.
        // Fall back to the anon key when there's no active session.
        let token = accessToken ?? SupabaseManager.anonKey
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody    = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw ListingError.serverError(http.statusCode, body)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ListingError.parseError
        }

        // Edge function returns camelCase keys; accept both camel and snake variants
        let price: Double? = {
            if let d = json["suggestedPrice"] as? Double { return d }
            if let d = json["suggested_price"] as? Double { return d }
            return nil
        }()
        let rationale: String = (json["priceRationale"] as? String)
            ?? (json["price_rationale"] as? String) ?? ""

        return ListingDraft(
            title:          json["title"]       as? String ?? asset.name,
            description:    json["description"] as? String ?? "",
            suggestedPrice: price,
            priceRationale: rationale
        )
    }
}
