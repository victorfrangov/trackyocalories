//
//  WeightEntry.swift
//  track yo calories
//

import Foundation
import SwiftUI

struct WeightEntry: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var date: Date = Date()
    var weightKg: Double
    var bodyFatPercentage: Double? = nil
    var waistCm: Double? = nil
    var chestCm: Double? = nil
    var hipsCm: Double? = nil
    var armsCm: Double? = nil
    var thighsCm: Double? = nil
    var notes: String? = nil
}
