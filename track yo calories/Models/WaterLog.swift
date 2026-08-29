//
//  WaterLog.swift
//  track yo calories
//

import Foundation
import SwiftUI

struct WaterLog: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var date: Date
    var amountMl: Double
    var timestamp: Date = Date()
}
