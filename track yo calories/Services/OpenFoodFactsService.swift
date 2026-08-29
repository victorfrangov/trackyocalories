//
//  OpenFoodFactsService.swift
//  track yo calories
//

import Foundation
import SwiftUI

actor OpenFoodFactsService {
    static let shared = OpenFoodFactsService()
    
    private let session: URLSession
    private let userAgent = "TrackYoCalories/1.0 (iOS; v@victorfrangov.com)"
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8.0
        config.timeoutIntervalForResource = 15.0
        self.session = URLSession(configuration: config)
    }
    
    /// Look up product details by barcode
    func fetchProduct(barcode: String) async throws -> FoodItem? {
        let cleanBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBarcode.isEmpty else { return nil }
        
        let endpoints = [
            "https://world.openfoodfacts.net/api/v2/product/\(cleanBarcode).json",
            "https://world.openfoodfacts.org/api/v2/product/\(cleanBarcode).json",
            "https://us.openfoodfacts.org/api/v0/product/\(cleanBarcode).json"
        ]
        
        for urlString in endpoints {
            guard let url = URL(string: urlString) else { continue }
            var request = URLRequest(url: url)
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            if let (data, response) = try? await session.data(for: request),
               let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? Int, status == 1,
               let product = json["product"] as? [String: Any],
               let parsed = parseProduct(product, fallbackBarcode: cleanBarcode) {
                return parsed
            }
        }
        
        return nil
    }
    
    /// Search products by keyword using modern OpenFoodFacts API
    func searchProducts(query: String, page: Int = 1) async throws -> [FoodItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }
        
        let urlStrings = [
            "https://world.openfoodfacts.net/api/v2/search?search_terms=\(encoded)&fields=code,product_name,product_name_en,brands,nutriments,serving_size,serving_quantity,image_front_small_url&page_size=25&page=\(page)",
            "https://us.openfoodfacts.org/api/v2/search?search_terms=\(encoded)&fields=code,product_name,product_name_en,brands,nutriments,serving_size,serving_quantity,image_front_small_url&page_size=25&page=\(page)"
        ]
        
        for urlString in urlStrings {
            guard let url = URL(string: urlString) else { continue }
            var request = URLRequest(url: url)
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            if let (data, response) = try? await session.data(for: request),
               let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let products = json["products"] as? [[String: Any]] {
                let parsedList = products.compactMap { parseProduct($0) }
                if !parsedList.isEmpty {
                    return parsedList
                }
            }
        }
        
        return []
    }
    
    // MARK: - JSON Parser Helper
    private func parseProduct(_ dict: [String: Any], fallbackBarcode: String? = nil) -> FoodItem? {
        let name = (dict["product_name"] as? String)?.trimmingCharacters(in: .whitespaces) ??
                   (dict["product_name_en"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        
        guard !name.isEmpty else { return nil }
        
        let brand = (dict["brands"] as? String)?.trimmingCharacters(in: .whitespaces)
        let barcode = (dict["code"] as? String) ?? fallbackBarcode
        let imageUrl = (dict["image_front_small_url"] as? String) ?? (dict["image_front_url"] as? String)
        
        let nutriments = dict["nutriments"] as? [String: Any] ?? [:]
        
        // Extract calories per 100g
        var calories: Double = 0.0
        if let kcal = getDouble(nutriments, key: "energy-kcal_100g") {
            calories = kcal
        } else if let kcal = getDouble(nutriments, key: "energy-kcal_value") {
            calories = kcal
        } else if let kcal = getDouble(nutriments, key: "energy-kcal") {
            calories = kcal
        } else if let kj = getDouble(nutriments, key: "energy_100g") {
            calories = kj / 4.184
        }
        
        let protein = getDouble(nutriments, key: "proteins_100g") ?? getDouble(nutriments, key: "proteins") ?? 0.0
        let carbs = getDouble(nutriments, key: "carbohydrates_100g") ?? getDouble(nutriments, key: "carbohydrates") ?? 0.0
        let fat = getDouble(nutriments, key: "fat_100g") ?? getDouble(nutriments, key: "fat") ?? 0.0
        let fiber = getDouble(nutriments, key: "fiber_100g") ?? getDouble(nutriments, key: "fiber")
        let sugar = getDouble(nutriments, key: "sugars_100g") ?? getDouble(nutriments, key: "sugars")
        let sodium = getSodiumMg(nutriments)
        let saturatedFat = getDouble(nutriments, key: "saturated-fat_100g") ?? getDouble(nutriments, key: "saturated-fat")
        
        let nutrientInfo = NutrientInfo(
            calories: max(0, calories),
            protein: max(0, protein),
            carbs: max(0, carbs),
            fat: max(0, fat),
            fiber: fiber,
            sugar: sugar,
            saturatedFat: saturatedFat,
            sodium: sodium
        )
        
        // Parse serving size
        var servingOptions: [ServingOption] = []
        
        if let servingQuantity = getDouble(dict, key: "serving_quantity"), servingQuantity > 0 {
            let servingDesc = (dict["serving_size"] as? String) ?? "\(Int(servingQuantity))g"
            servingOptions.append(ServingOption(
                id: UUID(),
                name: servingDesc,
                gramWeight: servingQuantity,
                isDefault: true
            ))
        } else if let servingSizeStr = dict["serving_size"] as? String, !servingSizeStr.isEmpty {
            let parsedGrams = extractGrams(from: servingSizeStr)
            if parsedGrams > 0 {
                servingOptions.append(ServingOption(
                    id: UUID(),
                    name: servingSizeStr,
                    gramWeight: parsedGrams,
                    isDefault: true
                ))
            }
        }
        
        // Standard 100g serving option
        servingOptions.append(ServingOption.grams(100.0))
        
        return FoodItem(
            id: UUID(),
            barcode: barcode,
            name: name,
            brand: brand,
            category: "Scanned / Online",
            nutrientsPer100g: nutrientInfo,
            servingOptions: servingOptions,
            isCustom: false,
            isVerified: false,
            imageUrl: imageUrl
        )
    }
    
    private func getDouble(_ dict: [String: Any], key: String) -> Double? {
        if let val = dict[key] as? Double {
            return val
        } else if let val = dict[key] as? Int {
            return Double(val)
        } else if let valStr = dict[key] as? String, let val = Double(valStr) {
            return val
        }
        return nil
    }
    
    private func getSodiumMg(_ nutriments: [String: Any]) -> Double? {
        if let sodiumG = getDouble(nutriments, key: "sodium_100g") {
            return sodiumG * 1000.0 // convert g to mg
        } else if let saltG = getDouble(nutriments, key: "salt_100g") {
            return (saltG / 2.5) * 1000.0 // salt is approx 40% sodium
        }
        return nil
    }
    
    private func extractGrams(from string: String) -> Double {
        let pattern = "([0-9]+(?:\\.[0-9]+)?)\\s*(?:g|ml|grams?)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
           let range = Range(match.range(at: 1), in: string),
           let val = Double(string[range]) {
            return val
        }
        return 100.0
    }
}
