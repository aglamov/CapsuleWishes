//
//  OpenAIResponsesClient.swift
//  CapsuleWishes
//
//  Created by Codex on 25.04.2026.
//

import Foundation

struct OpenAIResponsesClient {
    private let configuration: OpenAIConfiguration
    private let session: URLSession

    init(configuration: OpenAIConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    func generateText(instructions: String, input: String, maxOutputTokens: Int = 180) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/responses")!
        let body = ResponseRequest(
            model: configuration.model,
            instructions: instructions,
            input: input,
            maxOutputTokens: maxOutputTokens
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 18
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            AppLog.ai.error("OpenAI prompt failed: invalid response")
            throw OpenAIResponsesClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            AppLog.ai.error("OpenAI prompt failed: status=\(httpResponse.statusCode, privacy: .public)")
            throw OpenAIResponsesClientError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        guard let text = decoded.outputText else {
            AppLog.ai.error("OpenAI prompt failed: missing output text")
            throw OpenAIResponsesClientError.missingOutputText
        }

        AppLog.ai.debug("OpenAI prompt succeeded")
        return text
    }
}

private struct ResponseRequest: Encodable {
    let model: String
    let instructions: String
    let input: String
    let maxOutputTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case instructions
        case input
        case maxOutputTokens = "max_output_tokens"
    }
}

private struct ResponseEnvelope: Decodable {
    let output: [ResponseOutputItem]

    var outputText: String? {
        let text = output
            .flatMap(\.content)
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return text.isEmpty ? nil : text
    }
}

private struct ResponseOutputItem: Decodable {
    let content: [ResponseContentItem]

    enum CodingKeys: String, CodingKey {
        case content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = (try? container.decode([ResponseContentItem].self, forKey: .content)) ?? []
    }
}

private struct ResponseContentItem: Decodable {
    let text: String?
}

enum OpenAIResponsesClientError: Error {
    case invalidResponse
    case requestFailed(statusCode: Int)
    case missingOutputText
}
