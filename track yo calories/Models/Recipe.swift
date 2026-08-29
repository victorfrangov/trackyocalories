//
//  Recipe.swift
//  track yo calories
//

import Foundation
import SwiftUI

struct RecipeIngredient: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var food: FoodItem
    var servingOption: ServingOption
    var quantity: Double
    
    var nutrients: NutrientInfo {
        food.nutrients(for: servingOption, quantity: quantity)
    }
    
    var totalGrams: Double {
        servingOption.gramWeight * quantity
    }
}

struct Recipe: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var name: String
    var servings: Int = 1
    var ingredients: [RecipeIngredient] = []
    var instructions: String? = nil
    var createdAt: Date = Date()
    
    var totalNutrients: NutrientInfo {
        var cal = 0.0
        var pro = 0.0
        var carb = 0.0
        var fat = 0.0
        var fiber = 0.0
        var sugar = 0.0
        var sodium = 0.0
        
        for ing in ingredients {
            let nut = ing.nutrients
            cal += nut.calories
            pro += nut.protein
            carb += nut.carbs
            fat += nut.fat
            fiber += nut.fiber ?? 0.0
            sugar += nut.sugar ?? 0.0
            sodium += nut.sodium ?? 0.0
        }
        return NutrientInfo(
            calories: cal,
            protein: pro,
            carbs: carb,
            fat: fat,
            fiber: fiber > 0 ? fiber : nil,
            sugar: sugar > 0 ? sugar : nil,
            sodium: sodium > 0 ? sodium : nil
        )
    }
    
    var totalWeightGrams: Double {
        ingredients.reduce(0.0) { $0 + $1.totalGrams }
    }
    
    var nutrientsPerServing: NutrientInfo {
        let count = max(1, Double(servings))
        let total = totalNutrients
        return NutrientInfo(
            calories: total.calories / count,
            protein: total.protein / count,
            carbs: total.carbs / count,
            fat: total.fat / count,
            fiber: total.fiber.map { $0 / count },
            sugar: total.sugar.map { $0 / count },
            sodium: total.sodium.map { $0 / count }
        )
    }
    
    func toFoodItem() -> FoodItem {
        let weightPerServing = totalWeightGrams / max(1.0, Double(servings))
        let nutPer100g = totalWeightGrams > 0 ? totalNutrients.scaled(forGrams: 100.0 * (100.0 / totalWeightGrams)) : nutrientsPerServing
        
        let servingOption = ServingOption(
            id: UUID(),
            name: "1 serving (\(Int(weightPerServing))g)",
            gramWeight: max(1.0, weightPerServing),
            isDefault: true
        )
        
        return FoodItem(
            id: id,
            barcode: nil,
            name: name,
            brand: "Custom Recipe (\(servings) servings)",
            category: "Recipe",
            nutrientsPer100g: nutPer100g,
            servingOptions: [
                servingOption,
                ServingOption.grams(100.0),
                ServingOption(id: UUID(), name: "1g", gramWeight: 1.0, isDefault: false)
            ],
            isCustom: true,
            isVerified: true
        )
    }
}
