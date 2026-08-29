//
//  NutritionEngine.swift
//  track yo calories
//

import Foundation
import SwiftUI

struct MacroTargets: Equatable {
    var calories: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    
    var proteinCalories: Double { proteinGrams * 4 }
    var carbsCalories: Double { carbsGrams * 4 }
    var fatCalories: Double { fatGrams * 9 }
    
    var proteinPercentage: Double {
        calories > 0 ? (proteinCalories / calories) * 100 : 0
    }
    
    var carbsPercentage: Double {
        calories > 0 ? (carbsCalories / calories) * 100 : 0
    }
    
    var fatPercentage: Double {
        calories > 0 ? (fatCalories / calories) * 100 : 0
    }
}

struct MealBudget: Identifiable, Equatable {
    var mealType: MealType
    var calories: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    
    var id: String { mealType.rawValue }
}

enum NutritionEngine {
    
    /// Calculate Basal Metabolic Rate (BMR) using Mifflin-St Jeor equation
    static func calculateBMR(profile: UserProfile) -> Double {
        let weightComponent = 10.0 * profile.weightKg
        let heightComponent = 6.25 * profile.heightCm
        let ageComponent = 5.0 * Double(profile.age)
        
        switch profile.gender {
        case .male:
            return weightComponent + heightComponent - ageComponent + 5.0
        case .female:
            return weightComponent + heightComponent - ageComponent - 161.0
        }
    }
    
    /// Calculate Total Daily Energy Expenditure (TDEE)
    static func calculateTDEE(profile: UserProfile) -> Double {
        let bmr = calculateBMR(profile: profile)
        return bmr * profile.activityLevel.multiplier
    }
    
    /// Calculate daily target calories based on goal and weekly change
    static func calculateTargetCalories(profile: UserProfile) -> Double {
        if profile.dietType == .custom, let custom = profile.customCalories, custom > 500 {
            return custom
        }
        
        let tdee = calculateTDEE(profile: profile)
        let dailyAdjustment = profile.weeklyChangeKg * (7700.0 / 7.0) // 7700 kcal per kg of fat
        
        let minCal = profile.gender == .male ? 1500.0 : 1200.0
        let target = max(minCal, tdee + dailyAdjustment)
        return round(target)
    }
    
    /// Calculate daily macronutrient targets in grams
    static func calculateMacroTargets(profile: UserProfile) -> MacroTargets {
        let calories = calculateTargetCalories(profile: profile)
        
        if profile.dietType == .custom,
           let p = profile.customProteinGrams,
           let c = profile.customCarbsGrams,
           let f = profile.customFatGrams {
            return MacroTargets(calories: calories, proteinGrams: p, carbsGrams: c, fatGrams: f)
        }
        
        var proteinGrams: Double = 0.0
        var carbsGrams: Double = 0.0
        var fatGrams: Double = 0.0
        
        switch profile.dietType {
        case .balanced:
            // 30% Protein, 40% Carbs, 30% Fat
            proteinGrams = (calories * 0.30) / 4.0
            carbsGrams = (calories * 0.40) / 4.0
            fatGrams = (calories * 0.30) / 9.0
            
        case .highProtein:
            // 2.2g of protein per kg of bodyweight, 25% fat, remainder carbs
            let targetProtein = profile.weightKg * 2.2
            let proteinCals = targetProtein * 4.0
            let fatCals = calories * 0.25
            let remainingForCarbs = max(0, calories - proteinCals - fatCals)
            
            proteinGrams = targetProtein
            fatGrams = fatCals / 9.0
            carbsGrams = remainingForCarbs / 4.0
            
        case .lowCarb:
            // 35% Protein, 20% Carbs, 45% Fat
            proteinGrams = (calories * 0.35) / 4.0
            carbsGrams = (calories * 0.20) / 4.0
            fatGrams = (calories * 0.45) / 9.0
            
        case .keto:
            // 25% Protein, 5% Carbs, 70% Fat
            proteinGrams = (calories * 0.25) / 4.0
            carbsGrams = (calories * 0.05) / 4.0
            fatGrams = (calories * 0.70) / 9.0
            
        case .custom:
            proteinGrams = (calories * 0.30) / 4.0
            carbsGrams = (calories * 0.40) / 4.0
            fatGrams = (calories * 0.30) / 9.0
        }
        
        return MacroTargets(
            calories: calories,
            proteinGrams: round(proteinGrams),
            carbsGrams: round(carbsGrams),
            fatGrams: round(fatGrams)
        )
    }
    
    /// Calculate budget per meal type
    static func calculateMealBudgets(profile: UserProfile) -> [MealBudget] {
        let total = calculateMacroTargets(profile: profile)
        
        let ratios: [MealType: Double] = [
            .breakfast: profile.breakfastRatio,
            .lunch: profile.lunchRatio,
            .dinner: profile.dinnerRatio,
            .snacks: profile.snacksRatio
        ]
        
        return MealType.allCases.map { meal in
            let ratio = ratios[meal] ?? meal.defaultPercentage
            return MealBudget(
                mealType: meal,
                calories: round(total.calories * ratio),
                proteinGrams: round(total.proteinGrams * ratio),
                carbsGrams: round(total.carbsGrams * ratio),
                fatGrams: round(total.fatGrams * ratio)
            )
        }
    }
    
    /// Calculate BMI
    static func calculateBMI(weightKg: Double, heightCm: Double) -> Double {
        guard heightCm > 0 else { return 0 }
        let heightM = heightCm / 100.0
        return weightKg / (heightM * heightM)
    }
    
    /// Get BMI category description
    static func bmiCategory(bmi: Double) -> String {
        switch bmi {
        case ..<18.5: return "Underweight"
        case 18.5..<24.9: return "Normal weight"
        case 25.0..<29.9: return "Overweight"
        default: return "Obese"
        }
    }
}
