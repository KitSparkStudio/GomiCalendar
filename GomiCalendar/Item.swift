//
//  Item.swift
//  GomiCalendar
//
//  Created by KitSpark.Studio on 2026/11/20.
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
