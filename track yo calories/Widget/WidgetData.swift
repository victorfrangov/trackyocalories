//
//  WidgetData.swift
//  track yo calories
//

import Foundation
import WidgetKit

struct CalorieWidgetData: Codable, Sendable {
    var caloriesConsumed: Int
    var calorieBudget: Int
    var caloriesRemaining: Int
    
    var proteinConsumed: Int
    var proteinTarget: Int
    
    var carbsConsumed: Int
    var carbsTarget: Int
    
    var fatConsumed: Int
    var fatTarget: Int
    
    var lastUpdated: Date
    
    static var `default`: CalorieWidgetData {
        CalorieWidgetData(
            caloriesConsumed: 0,
            calorieBudget: 2000,
            caloriesRemaining: 2000,
            proteinConsumed: 0,
            proteinTarget: 150,
            carbsConsumed: 0,
            carbsTarget: 200,
            fatConsumed: 0,
            fatTarget: 65,
            lastUpdated: Date()
        )
    }
    
    static let sharedSuiteKey = "group.app.pineapple3119.elephant7948"
    static let storageKey = "calorie_widget_data"
    
    static var userDefaults: UserDefaults {
        UserDefaults(suiteName: sharedSuiteKey) ?? UserDefaults.standard
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            Self.userDefaults.set(data, forKey: Self.storageKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    static func load() -> CalorieWidgetData {
        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(CalorieWidgetData.self, from: data) {
            return decoded
        }
        return .default
    }
}
