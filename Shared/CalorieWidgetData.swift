//
//  CalorieWidgetData.swift
//  track yo calories
//
//  Shared by the app and the widget extension. The app writes today's totals into the
//  App Group's UserDefaults; the widget reads them.
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

    /// Sample values for the widget gallery preview.
    static var preview: CalorieWidgetData {
        CalorieWidgetData(
            caloriesConsumed: 1_240,
            calorieBudget: 2_200,
            caloriesRemaining: 960,
            proteinConsumed: 96,
            proteinTarget: 170,
            carbsConsumed: 130,
            carbsTarget: 240,
            fatConsumed: 38,
            fatTarget: 60,
            lastUpdated: Date()
        )
    }

    static let sharedSuiteKey = "group.app.pineapple3119.elephant7948"
    static let storageKey = "calorie_widget_data"

    static var userDefaults: UserDefaults {
        UserDefaults(suiteName: sharedSuiteKey) ?? UserDefaults.standard
    }

    /// Totals as they apply to `date`: if the data was written on an earlier day, nothing has
    /// been eaten yet today, so consumption resets to zero while the targets are kept.
    func asOf(_ date: Date) -> CalorieWidgetData {
        guard !Calendar.current.isDate(lastUpdated, inSameDayAs: date) else { return self }
        var reset = self
        reset.caloriesConsumed = 0
        reset.caloriesRemaining = calorieBudget
        reset.proteinConsumed = 0
        reset.carbsConsumed = 0
        reset.fatConsumed = 0
        reset.lastUpdated = date
        return reset
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        // Skip redundant widget reloads; WidgetKit budgets how often a widget may refresh.
        if Self.userDefaults.data(forKey: Self.storageKey).flatMap({ try? JSONDecoder().decode(CalorieWidgetData.self, from: $0) })?.sameTotals(as: self) == true {
            return
        }
        Self.userDefaults.set(data, forKey: Self.storageKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func load() -> CalorieWidgetData {
        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(CalorieWidgetData.self, from: data) {
            return decoded
        }
        return .default
    }

    private func sameTotals(as other: CalorieWidgetData) -> Bool {
        caloriesConsumed == other.caloriesConsumed && calorieBudget == other.calorieBudget
            && proteinConsumed == other.proteinConsumed && proteinTarget == other.proteinTarget
            && carbsConsumed == other.carbsConsumed && carbsTarget == other.carbsTarget
            && fatConsumed == other.fatConsumed && fatTarget == other.fatTarget
            && Calendar.current.isDate(lastUpdated, inSameDayAs: other.lastUpdated)
    }
}
