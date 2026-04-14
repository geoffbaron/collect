import Foundation
import UIKit

// MARK: - Result type

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

// MARK: - Scan result

struct ScanResult {
    let assets: [AssetResult]
    /// All frames sent to Gemini — used to look up per-asset photos via frameIndices
    let selectedFrames: [UIImage]
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case noAPIKey
    case httpError(Int, String)
    case invalidResponse
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No Gemini API key set. Tap the key icon in Settings to add one."
        case .httpError(let code, let body):
            return "API error \(code): \(body.prefix(200))"
        case .invalidResponse:
            return "Unexpected response format from Gemini API."
        case .parseError(let msg):
            return "Could not parse AI response: \(msg)"
        }
    }
}

// MARK: - Service

actor AIService {
    static let shared = AIService()

    private let apiKeyKey = "gemini_api_key"
    private let model = "gemini-3-flash-preview"

    var apiKey: String {
        UserDefaults.standard.string(forKey: apiKeyKey) ?? ""
    }

    var hasAPIKey: Bool { !apiKey.isEmpty }

    func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: apiKeyKey)
    }

    func analyzeScan(_ frames: [UIImage], template: PromptTemplate) async throws -> ScanResult {
        let key = apiKey
        guard !key.isEmpty else { throw AIServiceError.noAPIKey }

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)"
        guard let url = URL(string: urlString) else { throw AIServiceError.invalidResponse }

        // Adaptive frame selection
        let maxFrames = 20
        let step = max(1, frames.count / maxFrames)
        let selected = Array(stride(from: 0, to: frames.count, by: step).prefix(maxFrames).map { frames[$0] })
        let quality: CGFloat = selected.count > 12 ? 0.45 : 0.65
        let frameCount = selected.count

        // System prompt: inject frame numbering + frame_indices requirement
        let frameSchema = """
        Also include:
        - "estimated_value": a number representing the estimated current market or replacement value \
        in USD for one unit of this item (omit the field if truly unknown, do not guess wildly).
        - "frame_indices": an array of exactly 1 or 2 integers (0-based, \
        from 0 to \(frameCount - 1)) identifying the frames where this specific asset \
        is most clearly visible. The \(frameCount) images provided are numbered 0 through \(frameCount - 1) in order.
        """
        let systemPrompt = template.systemPrompt + "\n" + frameSchema

        // Build parts: system prompt → numbered frames → user instruction
        var parts: [[String: Any]] = [["text": systemPrompt]]
        for (idx, frame) in selected.enumerated() {
            guard let jpeg = frame.jpegData(compressionQuality: quality) else { continue }
            // Label each frame so Gemini can reference it by number
            parts.append(["text": "Frame \(idx):"])
            parts.append([
                "inline_data": [
                    "mime_type": "image/jpeg",
                    "data": jpeg.base64EncodedString()
                ]
            ])
        }

        let userText = template.type == .custom
            ? template.userPromptPrefix
            : "\(template.userPromptPrefix) Return ONLY a JSON array, no markdown."
        parts.append(["text": userText])

        let body: [String: Any] = [
            "contents": [["parts": parts]],
            "generationConfig": [
                "response_mime_type": "application/json",
                "temperature": 0.1,
                "max_output_tokens": 8192
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 240

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AIServiceError.httpError(http.statusCode, body)
        }

        let assets = try parseResponse(data: data, frameCount: frameCount)
        return ScanResult(assets: assets, selectedFrames: selected)
    }

    // MARK: - Parsing

    private func parseResponse(data: Data, frameCount: Int) throws -> [AssetResult] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw AIServiceError.invalidResponse
        }

        let finishReason = first["finishReason"] as? String ?? ""

        func parse(_ t: String) -> [AssetResult]? {
            guard let d = t.data(using: .utf8),
                  let arr = try? JSONSerialization.jsonObject(with: d) as? [[String: Any]],
                  !arr.isEmpty else { return nil }
            return arr.compactMap { makeResult(from: $0, frameCount: frameCount) }
        }

        // 1. Direct parse as JSON array
        if let results = parse(text) { return results }

        // 2. Strip markdown code fences
        let stripped = text
            .replacingOccurrences(of: #"```json\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"```\s*"#,     with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let results = parse(stripped) { return results }

        // 3. Object wrapper — {"assets": [...]} or any key containing an array
        if let d = text.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
            for key in ["assets", "items", "results", "data", "inventory"] {
                if let arr = obj[key] as? [[String: Any]] {
                    let r = arr.compactMap { makeResult(from: $0, frameCount: frameCount) }
                    if !r.isEmpty { return r }
                }
            }
            for (_, val) in obj {
                if let arr = val as? [[String: Any]], !arr.isEmpty {
                    return arr.compactMap { makeResult(from: $0, frameCount: frameCount) }
                }
            }
        }

        // 4. Greedy regex — outermost [...] (non-lazy so it captures the full array)
        if let range = text.range(of: #"\[[\s\S]*\]"#, options: .regularExpression),
           let results = parse(String(text[range])) {
            return results
        }

        // 5. Truncation recovery — response cut off mid-JSON (MAX_TOKENS hit)
        if finishReason == "MAX_TOKENS" || text.contains("[") {
            if let results = recoverTruncated(text, frameCount: frameCount) { return results }
        }

        throw AIServiceError.parseError("Could not parse response (finishReason: \(finishReason)). Preview: \(text.prefix(300))")
    }

    /// Salvage partially-truncated JSON by closing the array after the last complete object.
    private func recoverTruncated(_ text: String, frameCount: Int) -> [AssetResult]? {
        guard let arrayStart = text.firstIndex(of: "["),
              let lastBrace  = text.range(of: "}", options: .backwards) else { return nil }
        let candidate = String(text[arrayStart...lastBrace.upperBound]) + "]"
        guard let d = candidate.data(using: .utf8),
              let arr = try? JSONSerialization.jsonObject(with: d) as? [[String: Any]],
              !arr.isEmpty else { return nil }
        return arr.compactMap { makeResult(from: $0, frameCount: frameCount) }
    }

    private func makeResult(from dict: [String: Any], frameCount: Int) -> AssetResult? {
        guard let name = dict["name"] as? String, !name.isEmpty else { return nil }

        // Parse frame_indices — clamp to valid range, take up to 2
        let rawIndices = dict["frame_indices"] as? [Int] ?? []
        let validIndices = Array(
            rawIndices
                .filter { $0 >= 0 && $0 < frameCount }
                .prefix(2)
        )
        // Fallback: use first 2 frames if Gemini omitted frame_indices
        let frameIndices = validIndices.isEmpty ? Array((0..<min(2, frameCount))) : validIndices

        // estimated_value may come back as Int or Double
        let estimatedValue: Double? = {
            if let d = dict["estimated_value"] as? Double { return d }
            if let i = dict["estimated_value"] as? Int { return Double(i) }
            return nil
        }()

        return AssetResult(
            name: name,
            category: dict["category"] as? String ?? "Other",
            description: dict["description"] as? String ?? "",
            condition: dict["condition"] as? String,
            quantity: dict["quantity"] as? Int ?? 1,
            confidence: dict["confidence"] as? Double ?? 1.0,
            estimatedValue: estimatedValue,
            frameIndices: frameIndices
        )
    }
}
