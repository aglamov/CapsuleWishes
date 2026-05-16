//
//  OpenAIConfiguration.swift
//  CapsuleWishes
//
//  Created by Codex on 25.04.2026.
//

import Foundation

struct OpenAIConfiguration {
    let endpointURL: URL

    static var isAvailable: Bool {
        current != nil
    }

    static var current: OpenAIConfiguration? {
        let defaults = UserDefaults.standard
        let isEnabled = defaults.object(forKey: AIUsagePreferences.enabledKey) as? Bool ?? AIUsagePreferences.defaultEnabled

        guard isEnabled else {
            return nil
        }

        let environment = ProcessInfo.processInfo.environment
        let endpoint = environment["CAPSULE_WISHES_AI_ENDPOINT"] ?? Bundle.main.object(forInfoDictionaryKey: "CAPSULE_WISHES_AI_ENDPOINT") as? String

        guard
            let endpoint,
            let endpointURL = URL(string: endpoint.trimmingCharacters(in: .whitespacesAndNewlines)),
            let scheme = endpointURL.scheme?.lowercased(),
            scheme == "https"
        else {
            return nil
        }

        return OpenAIConfiguration(endpointURL: endpointURL)
    }
}
