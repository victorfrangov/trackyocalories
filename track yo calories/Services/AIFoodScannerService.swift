//
//  AIFoodScannerService.swift
//  track yo calories
//

import Foundation
import SwiftUI
import UIKit

struct AIFoodItemEstimate: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var name: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var portionDescription: String
    var gramWeight: Double
    
    // Baseline densities for portion scaling
    var baseCalPerGram: Double {
        let g = max(1.0, gramWeight)
        return calories / g
    }
    var baseProteinPerGram: Double {
        let g = max(1.0, gramWeight)
        return protein / g
    }
    var baseCarbsPerGram: Double {
        let g = max(1.0, gramWeight)
        return carbs / g
    }
    var baseFatPerGram: Double {
        let g = max(1.0, gramWeight)
        return fat / g
    }
    
    enum CodingKeys: String, CodingKey {
        case name, calories, protein, carbs, fat, portionDescription, gramWeight
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        portionDescription: String = "1 serving",
        gramWeight: Double = 100.0
    ) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.portionDescription = portionDescription
        self.gramWeight = gramWeight
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.calories = try container.decode(Double.self, forKey: .calories)
        self.protein = try container.decode(Double.self, forKey: .protein)
        self.carbs = try container.decode(Double.self, forKey: .carbs)
        self.fat = try container.decode(Double.self, forKey: .fat)
        self.portionDescription = try container.decodeIfPresent(String.self, forKey: .portionDescription) ?? "1 serving"
        self.gramWeight = try container.decodeIfPresent(Double.self, forKey: .gramWeight) ?? 100.0
    }
    
    func toFoodItem() -> FoodItem {
        let grams = max(1.0, gramWeight)
        let factor = 100.0 / grams
        
        let nutrients100g = NutrientInfo(
            calories: calories * factor,
            protein: protein * factor,
            carbs: carbs * factor,
            fat: fat * factor
        )
        
        let serving = ServingOption(
            id: UUID(),
            name: portionDescription.isEmpty ? "1 portion (\(Int(grams))g)" : portionDescription,
            gramWeight: grams,
            isDefault: true
        )
        
        return FoodItem(
            id: UUID(),
            barcode: nil,
            name: name,
            brand: "AI Estimated",
            category: "AI Meal Log",
            nutrientsPer100g: nutrients100g,
            servingOptions: [
                serving,
                ServingOption.grams(100.0),
                ServingOption(id: UUID(), name: "1g", gramWeight: 1.0, isDefault: false)
            ],
            isCustom: true,
            isVerified: true
        )
    }
}

struct AIFoodEstimate: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var mealName: String
    var items: [AIFoodItemEstimate]
    
    // Computed totals across all constituent items
    var totalCalories: Double { items.reduce(0.0) { $0 + $1.calories } }
    var totalProtein: Double { items.reduce(0.0) { $0 + $1.protein } }
    var totalCarbs: Double { items.reduce(0.0) { $0 + $1.carbs } }
    var totalFat: Double { items.reduce(0.0) { $0 + $1.fat } }
    var totalGrams: Double { items.reduce(0.0) { $0 + $1.gramWeight } }
    
    // Convenience accessors
    var foodName: String {
        mealName.isEmpty ? (items.first?.name ?? "AI Meal") : mealName
    }
    var calories: Double { totalCalories }
    var protein: Double { totalProtein }
    var carbs: Double { totalCarbs }
    var fat: Double { totalFat }
    var estimatedGrams: Double { totalGrams }
    var servingDescription: String {
        items.count == 1 ? (items.first?.portionDescription ?? "1 serving") : "\(items.count) items"
    }
    var ingredientsDetected: [String] {
        items.map { "\($0.name) (\($0.portionDescription))" }
    }
    var confidence: String = "High"
    var fiber: Double? = nil
    var sugar: Double? = nil
    var sodium: Double? = nil
    
    enum CodingKeys: String, CodingKey {
        case mealName, items, fiber, sugar, sodium, confidence
        // Fallback decoding keys
        case foodName, calories, protein, carbs, fat, servingDescription, estimatedGrams
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mealName, forKey: .mealName)
        try container.encode(items, forKey: .items)
        try container.encodeIfPresent(fiber, forKey: .fiber)
        try container.encodeIfPresent(sugar, forKey: .sugar)
        try container.encodeIfPresent(sodium, forKey: .sodium)
        try container.encode(confidence, forKey: .confidence)
    }
    
    init(mealName: String, items: [AIFoodItemEstimate]) {
        self.id = UUID()
        self.mealName = mealName
        self.items = items
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        
        if let decodedItems = try container.decodeIfPresent([AIFoodItemEstimate].self, forKey: .items), !decodedItems.isEmpty {
            self.items = decodedItems
            self.mealName = try container.decodeIfPresent(String.self, forKey: .mealName) ?? (decodedItems.first?.name ?? "AI Meal")
        } else {
            // Single-item fallback for backwards compatibility
            let name = try container.decodeIfPresent(String.self, forKey: .foodName)
                ?? (try container.decodeIfPresent(String.self, forKey: .mealName) ?? "AI Meal")
            let cals = try container.decodeIfPresent(Double.self, forKey: .calories) ?? 0.0
            let p = try container.decodeIfPresent(Double.self, forKey: .protein) ?? 0.0
            let c = try container.decodeIfPresent(Double.self, forKey: .carbs) ?? 0.0
            let f = try container.decodeIfPresent(Double.self, forKey: .fat) ?? 0.0
            let desc = try container.decodeIfPresent(String.self, forKey: .servingDescription) ?? "1 serving"
            let grams = try container.decodeIfPresent(Double.self, forKey: .estimatedGrams) ?? 100.0
            
            let single = AIFoodItemEstimate(
                name: name,
                calories: cals,
                protein: p,
                carbs: c,
                fat: f,
                portionDescription: desc,
                gramWeight: grams
            )
            self.mealName = name
            self.items = [single]
        }
        
        self.fiber = try container.decodeIfPresent(Double.self, forKey: .fiber)
        self.sugar = try container.decodeIfPresent(Double.self, forKey: .sugar)
        self.sodium = try container.decodeIfPresent(Double.self, forKey: .sodium)
        self.confidence = try container.decodeIfPresent(String.self, forKey: .confidence) ?? "High"
    }
    
    func toFoodItem() -> FoodItem {
        if items.count == 1, let first = items.first {
            return first.toFoodItem()
        }
        
        let grams = max(10.0, totalGrams)
        let factor = 100.0 / grams
        
        let nutrients100g = NutrientInfo(
            calories: totalCalories * factor,
            protein: totalProtein * factor,
            carbs: totalCarbs * factor,
            fat: totalFat * factor,
            fiber: fiber.map { $0 * factor },
            sugar: sugar.map { $0 * factor },
            sodium: sodium.map { $0 * factor }
        )
        
        let defaultServing = ServingOption(
            id: UUID(),
            name: "\(Int(grams))g (\(items.count) items)",
            gramWeight: grams,
            isDefault: true
        )
        
        return FoodItem(
            id: UUID(),
            barcode: nil,
            name: mealName,
            brand: "AI Estimated",
            category: "AI Meal Scan",
            nutrientsPer100g: nutrients100g,
            servingOptions: [
                defaultServing,
                ServingOption.grams(100.0),
                ServingOption(id: UUID(), name: "1g", gramWeight: 1.0, isDefault: false)
            ],
            isCustom: true,
            isVerified: true
        )
    }
}

enum AIScannerError: LocalizedError {
    case missingApiKey
    case imageCompressionFailed
    case invalidResponse
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingApiKey:
            return "Please enter your free Google AI Studio Gemini API key in Profile settings."
        case .imageCompressionFailed:
            return "Failed to process image format."
        case .invalidResponse:
            return "Could not identify food items or parse nutritional values. Please try phrasing your meal description differently or taking a clearer photo."
        case .apiError(let msg):
            return msg
        }
    }
}

actor AIFoodScannerService {
    static let shared = AIFoodScannerService()
    
    private var preferredModel: String = "gemini-3.5-flash-lite"
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12.0
        config.timeoutIntervalForResource = 20.0
        config.httpShouldUsePipelining = true
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()
    
    // MARK: - Natural Language Text Description Analysis (Separated Items)
    func analyzeFoodDescription(text: String, apiKey: String) async throws -> AIFoodEstimate {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            throw AIScannerError.missingApiKey
        }
        
        let candidateModels = [
            preferredModel,
            "gemini-3.5-flash-lite",
            "gemini-3.5-flash",
            "gemini-3.7-flash",
            "gemini-flash-latest-high-res-exp",
            "gemini-2.0-flash",
            "gemini-1.5-flash"
        ]
        
        var lastError: Error = AIScannerError.invalidResponse
        
        for model in candidateModels {
            do {
                let result = try await executeGeminiTextRequest(model: model, description: text, apiKey: cleanKey)
                self.preferredModel = model
                return result
            } catch {
                lastError = error
                if let apiErr = error as? AIScannerError, case .apiError(let msg) = apiErr {
                    if msg.contains("API key is invalid") || msg.contains("Rate limit") {
                        throw error
                    }
                }
                continue
            }
        }
        
        throw lastError
    }
    
    private func executeGeminiTextRequest(model: String, description: String, apiKey: String) async throws -> AIFoodEstimate {
        let cleanModel = model.hasPrefix("models/") ? String(model.dropFirst(7)) : model
        
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(cleanModel):generateContent?key=\(apiKey)") else {
            throw AIScannerError.apiError("Invalid API endpoint URL")
        }
        
        let promptText = """
        You are an expert clinical dietitian and calorie tracker.
        The user describes what they ate: "\(description)".
        Identify EVERY separate food item mentioned (e.g. eggs, bacon bits, olive oil, toast).
        For EACH item separately, accurately determine:
        - Concise item name
        - Realistic portion size description (e.g. "3 large eggs (150g)")
        - Weight in grams
        - Calories (kcal)
        - Macronutrients: protein, carbs, fat in grams
        
        Return ONLY valid JSON matching this schema:
        {
          "mealName": "Concise overall meal title",
          "items": [
            {
              "name": "Food item name",
              "calories": 215,
              "protein": 18.0,
              "carbs": 1.0,
              "fat": 15.0,
              "portionDescription": "Portion text (e.g. 3 large eggs)",
              "gramWeight": 150.0
            }
          ]
        }
        """
        
        let requestPayload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": promptText]
                    ]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.2
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestPayload)
        
        let (data, response) = try await session.data(for: request)
        return try parseGeminiResponse(data: data, response: response, cleanModel: cleanModel)
    }
    
    // MARK: - Photo Analysis (Separated Items)
    func analyzeFood(image: UIImage, apiKey: String) async throws -> AIFoodEstimate {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            throw AIScannerError.missingApiKey
        }
        
        let resized = resizeImage(image, maxDimension: 512)
        guard let jpegData = resized.jpegData(compressionQuality: 0.6) else {
            throw AIScannerError.imageCompressionFailed
        }
        let base64String = jpegData.base64EncodedString()
        
        let candidateModels = [
            preferredModel,
            "gemini-3.5-flash",
            "gemini-3.5-flash-lite",
            "gemini-3.7-flash",
            "gemini-flash-latest-high-res-exp",
            "gemini-2.0-flash",
            "gemini-1.5-flash"
        ]
        
        var lastError: Error = AIScannerError.invalidResponse
        
        for model in candidateModels {
            do {
                let result = try await executeGeminiVisionRequest(model: model, base64Image: base64String, apiKey: cleanKey)
                self.preferredModel = model
                return result
            } catch {
                lastError = error
                if let apiErr = error as? AIScannerError, case .apiError(let msg) = apiErr {
                    if msg.contains("API key is invalid") || msg.contains("Rate limit") {
                        throw error
                    }
                }
                continue
            }
        }
        
        throw lastError
    }
    
    private func executeGeminiVisionRequest(model: String, base64Image: String, apiKey: String) async throws -> AIFoodEstimate {
        let cleanModel = model.hasPrefix("models/") ? String(model.dropFirst(7)) : model
        
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(cleanModel):generateContent?key=\(apiKey)") else {
            throw AIScannerError.apiError("Invalid API endpoint URL")
        }
        
        let promptText = """
        You are an expert clinical dietitian and nutritionist.
        Analyze all food items visible in this image.
        Identify EVERY separate food item (e.g. 3 eggs, bacon bits, olive oil, salad).
        For EACH item separately, estimate:
        - Concise item name
        - Realistic portion size description
        - Weight in grams
        - Calories (kcal)
        - Macronutrients: protein, carbs, fat in grams
        
        Return ONLY valid JSON matching this schema:
        {
          "mealName": "Overall meal name",
          "items": [
            {
              "name": "Food item name",
              "calories": 250,
              "protein": 30.0,
              "carbs": 0.0,
              "fat": 5.0,
              "portionDescription": "1 breast (180g)",
              "gramWeight": 180.0
            }
          ]
        }
        """
        
        let requestPayload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": promptText],
                        [
                            "inlineData": [
                                "mimeType": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.2
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestPayload)
        
        let (data, response) = try await session.data(for: request)
        return try parseGeminiResponse(data: data, response: response, cleanModel: cleanModel)
    }
    
    private func parseGeminiResponse(data: Data, response: URLResponse, cleanModel: String) throws -> AIFoodEstimate {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIScannerError.invalidResponse
        }
        
        if httpResponse.statusCode == 400 || httpResponse.statusCode == 403 {
            let errorText = String(data: data, encoding: .utf8) ?? ""
            if errorText.contains("API_KEY_INVALID") || errorText.contains("key is not valid") {
                throw AIScannerError.apiError("Google AI Studio API key is invalid. Please verify your API key.")
            }
        }
        
        if httpResponse.statusCode == 429 {
            throw AIScannerError.apiError("Rate limit reached. Please wait a moment and try again.")
        }
        
        guard httpResponse.statusCode == 200 else {
            if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let err = root["error"] as? [String: Any],
               let msg = err["message"] as? String {
                throw AIScannerError.apiError(msg)
            }
            let errorText = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw AIScannerError.apiError("AI Service Error (\(httpResponse.statusCode)): \(errorText)")
        }
        
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = root["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let jsonText = firstPart["text"] as? String else {
            throw AIScannerError.invalidResponse
        }
        
        var cleanJson = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanJson.hasPrefix("```json") {
            cleanJson = cleanJson.replacingOccurrences(of: "```json", with: "")
        }
        if cleanJson.hasPrefix("```") {
            cleanJson = cleanJson.replacingOccurrences(of: "```", with: "")
        }
        cleanJson = cleanJson.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = cleanJson.data(using: .utf8) else {
            throw AIScannerError.invalidResponse
        }
        
        let estimate = try JSONDecoder().decode(AIFoodEstimate.self, from: jsonData)
        return estimate
    }
    
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxCurrent = max(size.width, size.height)
        guard maxCurrent > maxDimension else { return image }
        
        let scale = maxDimension / maxCurrent
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resized = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return resized
    }
}
