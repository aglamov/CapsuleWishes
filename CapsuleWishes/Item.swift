//
//  Item.swift
//  CapsuleWishes
//
//  Created by Рамиль Аглямов on 06.02.2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
