//
//  CapsuleCreationPolicy.swift
//  CapsuleWishes
//
//  Created by Codex on 08.05.2026.
//

import Foundation

enum CapsuleCreationPolicy {
    static let activeCapsuleLimit = 10

    static func activeCapsuleCount(in capsules: [WishCapsule]) -> Int {
        capsules.filter { !$0.hasBeenOpened }.count
    }

    static func canCreateCapsule(with capsules: [WishCapsule]) -> Bool {
        activeCapsuleCount(in: capsules) < activeCapsuleLimit
    }
}
