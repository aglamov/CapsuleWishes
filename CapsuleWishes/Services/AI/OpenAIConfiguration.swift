//
//  OpenAIConfiguration.swift
//  CapsuleWishes
//
//  Created by Codex on 25.04.2026.
//

import Foundation

struct OpenAIConfiguration {
    let apiKey: String
    let model: String

    static var current: OpenAIConfiguration? {
        let environment = ProcessInfo.processInfo.environment
        let apiKey = environment["OPENAI_API_KEY"] ?? Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String
        let model = environment["OPENAI_MODEL"] ?? Bundle.main.object(forInfoDictionaryKey: "OPENAI_MODEL") as? String ?? "gpt-5.4-mini"

        guard let apiKey, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }

        return OpenAIConfiguration(apiKey: apiKey, model: model)
    }
}
