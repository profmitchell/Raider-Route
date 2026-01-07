//
//  Item.swift
//  RaiderRoute
//
//  Created by Mitchell Cohen on 1/7/26.
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
