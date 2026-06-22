//
//  Item.swift
//  LIVE
//
//  Created by Andrej Laptev on 6/17/26.
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
