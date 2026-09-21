//
//  Formatting.swift
//  track yo calories
//

import Foundation

extension Double {
    /// Parses user-typed numbers regardless of locale ("1.5", "1,5", " 72,4 kg").
    /// The decimal keypad shows a comma in many European locales, which `Double(_:)` rejects.
    init?(userInput: String) {
        let cleaned = userInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
            .filter { "0123456789.-".contains($0) }
        guard !cleaned.isEmpty, let value = Double(cleaned), value.isFinite else { return nil }
        self = value
    }

    /// "1", "1.5", "0.25" – no trailing zeros, locale-aware separator.
    var cleanString: String {
        cleanString(max: 2)
    }

    func cleanString(max digits: Int) -> String {
        formatted(.number.precision(.fractionLength(0...digits)).grouping(.never))
    }

    /// Whole-number kcal / gram display with grouping ("2,207").
    var roundedString: String {
        Int(self.rounded()).formatted()
    }
}

extension MealType {
    /// The meal that best matches the current time of day. Used as the default target
    /// when logging from a global "Add" button instead of a specific meal section.
    static func suggested(for date: Date = Date()) -> MealType {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 4..<11: return .breakfast
        case 11..<15: return .lunch
        case 17..<22: return .dinner
        default: return .snacks
        }
    }
}
