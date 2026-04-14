import Foundation
import UIKit

// MARK: - Result types

struct AssetResult: Identifiable {
    let id = UUID()
    var name: String
    var category: String
    var description: String
    var condition: String?
    var quantity: Int
    var confidence: Double
    /// AI-suggested market/replacement value in USD (nil if unknown)
    var estimatedValue: Double?
    /// 0-based indices into ScanResult.selectedFrames where this asset is most visible
    var frameIndices: [Int]
}

struct ScanResult {
    let assets: [AssetResult]
    /// Frames sent to the Edge Function — used to look up per-asset photos via frameIndices
    let selectedFrames: [UIImage]
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case notAuthenticated
    case httpError(Int, String)
    case invalidResponse
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to scan rooms."
        case .httpError(let code, let body):
            return "Server error \(code): \(body.prefix(200))"
        case .invalidResponse:
            return "Unexpected response from the server."
        case .parseError(let msg):
            return "Could not parse scan results: \(msg)"
        }
    }
}

// MARK: - Service

actor AIService {
    static let shared = AIService()

    func analyzeScan(_ frames: [UIImage], template: PromptTemplate) async throws -> ScanResult {
        // Guests don't have a Supabase session — gate scanning on real accounts.
        let session = try? await SupabaseManager.shared.client.auth.session
        guard let accessToken = session?.accessToken else {
            throw AIServiceError.notAuthenticated
        }

        // Adaptive frame selection (same logic as before)
        let maxFrames = 20
        let step = max(1, frames.count / maxFrames)
        let selected = Array(
            stride(from: 0, to: frames.count, by: step)
                .prefix(maxFrames)
                .map { frames[$0] }
        )
        let quality: CGFloat = selected.count > 12 ? 0.45 : 0.65

        // Encode frames as base64 JPEG
        let base64Frames = selected.compactMap {
            $0.jpegData(compressionQuality: quality)?.base64EncodedString()
        }

        // Build request body
        let body: [String: Any] = [
            "frames": base64Frames,
            "template": [
                "systemPrompt":    template.systemPrompt,
                "userPromptPrefix": template.userPromptPrefix,
                "type":            template.type.rawValue
            ]
        ]

        // Call the Supabase Edge Function
        let edgeFunctionURL = "\(SupabaseManager.projectURL)/functions/v1/analyze"
        guard let url = URL(string: edgeFunctionURL) else {
            throw AIServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json",        forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)",   forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 240

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let responseBody = String(data: data, encoding: .utf8) ?? ""
            if http.statusCode == 401 { throw AIServiceError.notAuthenticated }
            throw AIServiceError.httpError(http.statusCode, responseBody)
        }

        let assets = try parseResponse(data: data, frameCount: selected.count)
        return ScanResult(assets: assets, selectedFrames: selected)
    }

    // MARK: - Parsing
    // The Edge Function returns a clean { "assets": [...] } envelope.

    private func parseResponse(data: Data, frameCount: Int) throws -> [AssetResult] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let assetsArray = json["assets"] as? [[String: Any]] else {
            throw AIServiceError.invalidResponse
        }
        return assetsArray.compactMap { makeResult(from: $0, frameCount: frameCount) }
    }

    private func makeResult(from dict: [String: Any], frameCount: Int) -> AssetResult? {
        guard let name = dict["name"] as? String, !name.isEmpty else { return nil }

        let rawIndices = dict["frame_indices"] as? [Int] ?? []
        let validIndices = Array(
            rawIndices.filter { $0 >= 0 && $0 < frameCount }.prefix(2)
        )
        let frameIndices = validIndices.isEmpty ? Array((0..<min(2, frameCount))) : validIndices

        let estimatedValue: Double? = {
            if let d = dict["estimated_value"] as? Double { return d }
            if let i = dict["estimated_value"] as? Int    { return Double(i) }
            return nil
        }()

        return AssetResult(
            name:           name,
            category:       dict["category"]    as? String ?? "Other",
            description:    dict["description"] as? String ?? "",
            condition:      dict["condition"]   as? String,
            quantity:       dict["quantity"]    as? Int    ?? 1,
            confidence:     dict["confidence"]  as? Double ?? 1.0,
            estimatedValue: estimatedValue,
            frameIndices:   frameIndices
        )
    }
}
