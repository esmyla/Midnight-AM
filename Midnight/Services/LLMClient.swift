import Foundation

/// Minimal raw-HTTP client for the OpenAI Responses API.
/// Prototype only: the key lives in the app bundle. Put a proxy in front before shipping.
struct LLMClient {
    enum LLMError: LocalizedError {
        case missingKey
        case http(Int, String)
        case refusal(String)
        case badResponse

        var errorDescription: String? {
            switch self {
            case .missingKey: return "No OpenAI API key. Add OPENAI_API_KEY to Secrets.xcconfig."
            case .http(let code, let body): return "OpenAI API error \(code): \(body.prefix(200))"
            case .refusal(let why): return "The model declined this request. \(why)"
            case .badResponse: return "Unexpected response from the model."
            }
        }
    }

    /// Cheap and fast: turning a sentence into a schema-constrained JSON commitment.
    static let parseModel = "gpt-5-nano"
    /// Stronger vision judgment: deciding whether a screenshot proves the task was done.
    static let verifyModel = "gpt-5-mini"

    static var apiKey: String? {
        let k = Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String
        guard let k, !k.isEmpty, !k.contains("REPLACE_ME") else { return nil }
        return k
    }

    /// One turn, JSON-constrained output via text.format json_schema (strict). Returns the JSON text.
    static func structured(model: String,
                           system: String,
                           userContent: [[String: Any]],
                           schemaName: String,
                           schema: [String: Any],
                           reasoningEffort: String = "low",
                           maxOutputTokens: Int = 2048) async throws -> Data {
        guard let apiKey else { throw LLMError.missingKey }

        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "max_output_tokens": maxOutputTokens,
            "reasoning": ["effort": reasoningEffort],
            "input": [
                ["role": "system", "content": system],
                ["role": "user", "content": userContent]
            ],
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": schemaName,
                    "strict": true,
                    "schema": schema
                ]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw LLMError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw LLMError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [[String: Any]] else {
            throw LLMError.badResponse
        }
        for item in output where item["type"] as? String == "message" {
            for part in item["content"] as? [[String: Any]] ?? [] {
                if part["type"] as? String == "refusal" {
                    throw LLMError.refusal(part["refusal"] as? String ?? "")
                }
                if part["type"] as? String == "output_text",
                   let text = part["text"] as? String,
                   let out = text.data(using: .utf8) {
                    return out
                }
            }
        }
        throw LLMError.badResponse
    }
}
