//
//  LoggedEntry.swift
//  track yo calories
//

import Foundation
import SwiftUI

struct LoggedEntry: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var date: Date
    var createdAt: Date = Date()
    var mealType: MealType
    var food: FoodItem
    var servingOption: ServingOption
    var quantity: Double
    
    var totalGrams: Double {
        servingOption.gramWeight * quantity
    }
    
    var portionDescription: String {
        if quantity == 1.0 {
            return servingOption.name
        } else {
            return "\(quantity.formatted()) × \(servingOption.name)"
        }
    }
    
    var nutrients: NutrientInfo {
        food.nutrients(for: servingOption, quantity: quantity)
    }
    
    var calories: Double {
        nutrients.calories
    }
    
    var protein: Double {
        nutrients.protein
    }
    
    var carbs: Double {
        nutrients.carbs
    }
    
    var fat: Double {
        nutrients.fat
    }
    
    var fiber: Double {
        nutrients.fiber ?? 0.0
    }
    
    var sugar: Double {
        nutrients.sugar ?? 0.0
    }
    
    var sodium: Double {
        nutrients.sodium ?? 0.0
    }
}
