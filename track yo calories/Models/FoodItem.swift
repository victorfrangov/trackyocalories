//
//  FoodItem.swift
//  track yo calories
//

import Foundation
import SwiftUI

struct ServingOption: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID = UUID()
    var name: String // e.g. "100 grams", "1 medium (182g)", "1 scoop (30g)", "1 tbsp (14g)"
    var gramWeight: Double // weight in grams
    var isDefault: Bool = false
    
    static func grams(_ amount: Double = 100.0) -> ServingOption {
        ServingOption(id: UUID(), name: "\(Int(amount))g", gramWeight: amount, isDefault: true)
    }
}

struct NutrientInfo: Codable, Equatable, Hashable, Sendable {
    var calories: Double // kcal per 100g
    var protein: Double  // grams per 100g
    var carbs: Double    // grams per 100g
    var fat: Double      // grams per 100g
    
    // Optional micronutrients per 100g
    var fiber: Double? = nil
    var sugar: Double? = nil
    var saturatedFat: Double? = nil
    var sodium: Double? = nil // in mg
    var potassium: Double? = nil // in mg
    var cholesterol: Double? = nil // in mg
    
    static var zero: NutrientInfo {
        NutrientInfo(calories: 0, protein: 0, carbs: 0, fat: 0)
    }
    
    func scaled(forGrams grams: Double) -> NutrientInfo {
        let factor = grams / 100.0
        return NutrientInfo(
            calories: calories * factor,
            protein: protein * factor,
            carbs: carbs * factor,
            fat: fat * factor,
            fiber: fiber.map { $0 * factor },
            sugar: sugar.map { $0 * factor },
            saturatedFat: saturatedFat.map { $0 * factor },
            sodium: sodium.map { $0 * factor },
            potassium: potassium.map { $0 * factor },
            cholesterol: cholesterol.map { $0 * factor }
        )
    }
}

struct FoodItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID = UUID()
    var barcode: String? = nil
    var name: String
    var brand: String? = nil
    var category: String = "General"
    var nutrientsPer100g: NutrientInfo
    var servingOptions: [ServingOption] = []
    var isCustom: Bool = false
    var isVerified: Bool = true
    var imageUrl: String? = nil
    
    var displayName: String {
        if let brand = brand, !brand.trimmingCharacters(in: .whitespaces).isEmpty {
            return "\(brand) - \(name)"
        }
        return name
    }
    
    var effectiveServingOptions: [ServingOption] {
        if servingOptions.isEmpty {
            return [
                ServingOption(id: UUID(), name: "100g", gramWeight: 100.0, isDefault: true),
                ServingOption(id: UUID(), name: "1g", gramWeight: 1.0, isDefault: false)
            ]
        }
        return servingOptions
    }
    
    var defaultServing: ServingOption {
        effectiveServingOptions.first(where: { $0.isDefault }) ?? effectiveServingOptions.first ?? ServingOption.grams(100)
    }
    
    func nutrients(for serving: ServingOption, quantity: Double) -> NutrientInfo {
        let totalGrams = serving.gramWeight * quantity
        return nutrientsPer100g.scaled(forGrams: totalGrams)
    }
    
    func nutrients(forGrams grams: Double) -> NutrientInfo {
        return nutrientsPer100g.scaled(forGrams: grams)
    }
}
