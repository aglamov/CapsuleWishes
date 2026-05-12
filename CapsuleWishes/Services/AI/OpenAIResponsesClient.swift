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
        let body = ResponseRequest(
            instructions: instructions,
            input: input,
            maxOutputTokens: maxOutputTokens
        )

        var request = URLRequest(url: configuration.endpointURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 6
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            AppLog.ai.error("AI backend prompt failed: invalid response")
            throw OpenAIResponsesClientError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            AppLog.ai.error("AI backend prompt failed: status=\(httpResponse.statusCode, privacy: .public)")
            throw OpenAIResponsesClientError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let decoded = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        guard let text = decoded.outputText else {
            AppLog.ai.error("AI backend prompt failed: missing output text")
            throw OpenAIResponsesClientError.missingOutputText
        }

        AppLog.ai.debug("AI backend prompt succeeded")
        return text
    }
}

private struct ResponseRequest: Encodable {
    let instructions: String
    let input: String
    let maxOutputTokens: Int

    enum CodingKeys: String, CodingKey {
        case instructions
        case input
        case maxOutputTokens = "max_output_tokens"
    }
}

private struct ResponseEnvelope: Decodable {
    private let text: String?
    private let outputTextValue: String?
    private let output: [ResponseOutputItem]

    var outputText: String? {
        let directText = text ?? outputTextValue
        if let directText {
            let trimmedText = directText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedText.isEmpty {
                return trimmedText
            }
        }

        let nestedText = output
            .flatMap(\.content)
            .compactMap(\.text)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return nestedText.isEmpty ? nil : nestedText
    }

    enum CodingKeys: String, CodingKey {
        case text
        case outputTextValue = "output_text"
        case output
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try? container.decode(String.self, forKey: .text)
        outputTextValue = try? container.decode(String.self, forKey: .outputTextValue)
        output = (try? container.decode([ResponseOutputItem].self, forKey: .output)) ?? []
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
