import Foundation
import UIKit

struct VerificationVerdict: Codable {
    var satisfied: Bool
    var confidence: Double
    var reason: String
}

/// Sends a screenshot or photo to the vision model and asks whether it proves the task was done.
enum VerificationService {
    static let schema: [String: Any] = [
        "type": "object",
        "additionalProperties": false,
        "required": ["satisfied", "confidence", "reason"],
        "properties": [
            "satisfied": ["type": "boolean"],
            "confidence": ["type": "number", "description": "0 to 1"],
            "reason": ["type": "string", "description": "One sentence the user will read"]
        ]
    ]

    static func verify(image: UIImage, for c: Commitment) async throws -> VerificationVerdict {
        guard let jpeg = downscaled(image).jpegData(compressionQuality: 0.8) else {
            throw LLMClient.LLMError.badResponse
        }
        let system = """
        You are the verifier for a self-commitment app. The user promised to complete a task and is \
        submitting evidence. Judge strictly but fairly: the evidence must plausibly show the task was \
        completed today, at the stated quantity if any. Reject screenshots that show only a problem \
        statement, an unfinished state, or unrelated content. Reject obvious stock images. If the image \
        is too ambiguous to judge, set satisfied=false and say what a convincing shot would show.
        """
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        let text = """
        Commitment: \(c.title)
        Task: \(c.taskDescription)\(c.quantityLine.isEmpty ? "" : " (\(c.quantityLine))")
        Evidence type: \(c.verification.rawValue)
        Now: \(f.string(from: Date()))
        Does this image prove the task is done?
        """
        let content: [[String: Any]] = [
            ["type": "input_image", "image_url": "data:image/jpeg;base64,\(jpeg.base64EncodedString())",
             "detail": "high"],
            ["type": "input_text", "text": text]
        ]
        let data = try await LLMClient.structured(model: LLMClient.verifyModel, system: system,
                                                  userContent: content, schemaName: "verdict",
                                                  schema: schema, reasoningEffort: "medium")
        return try JSONDecoder().decode(VerificationVerdict.self, from: data)
    }

    private static func downscaled(_ image: UIImage, maxSide: CGFloat = 1568) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxSide else { return image }
        let scale = maxSide / longest
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
