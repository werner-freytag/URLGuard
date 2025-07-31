//
//  Item.swift
//  URLWatcher
//
//  Created by Freytag, Werner on 31.07.25.
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
