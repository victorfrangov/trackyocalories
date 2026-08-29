//
//  UserProfile.swift
//  track yo calories
//

import Foundation
import SwiftUI

enum Gender: String, Codable, CaseIterable, Identifiable, Sendable {
    case male = "Male"
    case female = "Female"
    
    var id: String { rawValue }
}

enum ActivityLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case sedentary = "Sedentary"
    case lightlyActive = "Lightly Active"
    case moderatelyActive = "Moderately Active"
    case veryActive = "Very Active"
    case extraActive = "Extra Active"
    
    var id: String { rawValue }
    
    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .lightlyActive: return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive: return 1.725
        case .extraActive: return 1.9
        }
    }
    
    var subtitle: String {
        switch self {
        case .sedentary: return "Little or no exercise, desk job"
        case .lightlyActive: return "Exercise 1-3 times / week"
        case .moderatelyActive: return "Exercise 3-5 times / week"
        case .veryActive: return "Hard exercise 6-7 times / week"
        case .extraActive: return "Very hard exercise & physical job"
        }
    }
}

enum Goal: String, Codable, CaseIterable, Identifiable, Sendable {
    case fatLoss = "Fat Loss"
    case maintenance = "Maintain Weight"
    case muscleGain = "Muscle Gain"
    
    var id: String { rawValue }
    
    var defaultWeeklyChangeKg: Double {
        switch self {
        case .fatLoss: return -0.5
        case .maintenance: return 0.0
        case .muscleGain: return 0.25
        }
    }
}

enum DietType: String, Codable, CaseIterable, Identifiable, Sendable {
    case balanced = "Balanced"
    case highProtein = "High Protein"
    case lowCarb = "Low Carb"
    case keto = "Keto"
    case custom = "Custom"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .balanced: return "30% Protein, 40% Carbs, 30% Fat"
        case .highProtein: return "High Protein (2.2g/kg), 25% Fat, remaining Carbs"
        case .lowCarb: return "35% Protein, 20% Carbs, 45% Fat"
        case .keto: return "25% Protein, 5% Carbs, 70% Fat"
        case .custom: return "User-defined custom macros"
        }
    }
}

enum UnitSystem: String, Codable, CaseIterable, Identifiable, Sendable {
    case metric = "Metric (kg, cm, ml)"
    case imperial = "Imperial (lbs, in, fl oz)"
    
    var id: String { rawValue }
    
    var weightUnit: String {
        switch self {
        case .metric: return "kg"
        case .imperial: return "lbs"
        }
    }
    
    var heightUnit: String {
        switch self {
        case .metric: return "cm"
        case .imperial: return "in"
        }
    }
    
    var liquidUnit: String {
        switch self {
        case .metric: return "ml"
        case .imperial: return "fl oz"
        }
    }
    
    func kgToDisplay(_ kg: Double) -> Double {
        switch self {
        case .metric: return kg
        case .imperial: return kg * 2.20462
        }
    }
    
    func displayToKg(_ val: Double) -> Double {
        switch self {
        case .metric: return val
        case .imperial: return val / 2.20462
        }
    }
    
    func cmToDisplay(_ cm: Double) -> Double {
        switch self {
        case .metric: return cm
        case .imperial: return cm / 2.54
        }
    }
    
    func displayToCm(_ val: Double) -> Double {
        switch self {
        case .metric: return val
        case .imperial: return val * 2.54
        }
    }
    
    func mlToDisplay(_ ml: Double) -> Double {
        switch self {
        case .metric: return ml
        case .imperial: return ml / 29.5735
        }
    }
    
    func displayToMl(_ val: Double) -> Double {
        switch self {
        case .metric: return val
        case .imperial: return val * 29.5735
        }
    }
}

struct UserProfile: Codable, Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    var isOnboarded: Bool = false
    var name: String = "User"
    var age: Int = 28
    var gender: Gender = .male
    var heightCm: Double = 178.0
    var weightKg: Double = 75.0
    var targetWeightKg: Double = 72.0
    var weeklyChangeKg: Double = -0.5
    var activityLevel: ActivityLevel = .moderatelyActive
    var goal: Goal = .fatLoss
    var dietType: DietType = .highProtein
    
    // Custom overrides if dietType == .custom
    var customCalories: Double? = nil
    var customProteinGrams: Double? = nil
    var customCarbsGrams: Double? = nil
    var customFatGrams: Double? = nil
    
    var waterGoalMl: Double = 2500.0
    var unitSystem: UnitSystem = .metric
    
    // Meal % budget split (Breakfast, Lunch, Dinner, Snacks)
    var breakfastRatio: Double = 0.25
    var lunchRatio: Double = 0.35
    var dinnerRatio: Double = 0.30
    var snacksRatio: Double = 0.10
    
    // Google Gemini AI API Key for Food Vision
    var geminiApiKey: String? = nil
    
    static var `default`: UserProfile {
        UserProfile(
            id: UUID(),
            isOnboarded: false,
            name: "User",
            age: 28,
            gender: .male,
            heightCm: 178.0,
            weightKg: 75.0,
            targetWeightKg: 72.0,
            weeklyChangeKg: -0.5,
            activityLevel: .moderatelyActive,
            goal: .fatLoss,
            dietType: .highProtein,
            customCalories: nil,
            customProteinGrams: nil,
            customCarbsGrams: nil,
            customFatGrams: nil,
            waterGoalMl: 2500.0,
            unitSystem: .metric,
            breakfastRatio: 0.25,
            lunchRatio: 0.35,
            dinnerRatio: 0.30,
            snacksRatio: 0.10,
            geminiApiKey: nil
        )
    }
}
