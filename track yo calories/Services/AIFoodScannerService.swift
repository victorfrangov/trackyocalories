//
//  AIFoodScannerService.swift
//  track yo calories
//

import Foundation
import SwiftUI
import UIKit

struct AIFoodEstimate: Identifiable, Codable, Sendable {
    var id: UUID = UUID()
    var foodName: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double?
    var sugar: Double?
    var sodium: Double?
    var servingDescription: String
    var estimatedGrams: Double
    var ingredientsDetected: [String]
    var confidence: String
    
    enum CodingKeys: String, CodingKey {
        case foodName, calories, protein, carbs, fat, fiber, sugar, sodium, servingDescription, estimatedGrams, ingredientsDetected, confidence
    }
    
    init(
        foodName: String,
        calories: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        fiber: Double? = nil,
        sugar: Double? = nil,
        sodium: Double? = nil,
        servingDescription: String = "1 serving",
        estimatedGrams: Double = 100.0,
        ingredientsDetected: [String] = [],
        confidence: String = "High"
    ) {
        self.id = UUID()
        self.foodName = foodName
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.sugar = sugar
        self.sodium = sodium
        self.servingDescription = servingDescription
        self.estimatedGrams = estimatedGrams
        self.ingredientsDetected = ingredientsDetected
        self.confidence = confidence
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.foodName = try container.decode(String.self, forKey: .foodName)
        self.calories = try container.decode(Double.self, forKey: .calories)
        self.protein = try container.decode(Double.self, forKey: .protein)
        self.carbs = try container.decode(Double.self, forKey: .carbs)
        self.fat = try container.decode(Double.self, forKey: .fat)
        self.fiber = try container.decodeIfPresent(Double.self, forKey: .fiber)
        self.sugar = try container.decodeIfPresent(Double.self, forKey: .sugar)
        self.sodium = try container.decodeIfPresent(Double.self, forKey: .sodium)
        self.servingDescription = try container.decodeIfPresent(String.self, forKey: .servingDescription) ?? "1 serving"
        self.estimatedGrams = try container.decodeIfPresent(Double.self, forKey: .estimatedGrams) ?? 100.0
        self.ingredientsDetected = try container.decodeIfPresent([String].self, forKey: .ingredientsDetected) ?? []
        self.confidence = try container.decodeIfPresent(String.self, forKey: .confidence) ?? "Medium"
    }
    
    func toFoodItem() -> FoodItem {
        let grams = max(10.0, estimatedGrams)
        let factor = 100.0 / grams
        
        let nutrients100g = NutrientInfo(
            calories: calories * factor,
            protein: protein * factor,
            carbs: carbs * factor,
            fat: fat * factor,
            fiber: fiber.map { $0 * factor },
            sugar: sugar.map { $0 * factor },
            sodium: sodium.map { $0 * factor }
        )
        
        let defaultServing = ServingOption(
            id: UUID(),
            name: servingDescription.isEmpty ? "1 serving (\(Int(grams))g)" : servingDescription,
            gramWeight: grams,
            isDefault: true
        )
        
        return FoodItem(
            id: UUID(),
            barcode: nil,
            name: foodName,
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
    
    private var preferredModel: String = "gemini-2.0-flash"
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 12.0
        config.timeoutIntervalForResource = 20.0
        config.httpShouldUsePipelining = true
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()
    
    // MARK: - Natural Language Text Description Analysis
    func analyzeFoodDescription(text: String, apiKey: String) async throws -> AIFoodEstimate {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            throw AIScannerError.missingApiKey
        }
        
        let candidateModels = [
            preferredModel,
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
        You are an expert clinical dietitian, nutritionist, and calorie tracker.
        The user describes what they ate: "\(description)".
        Accurately determine all ingredients/items mentioned, realistic standard portion sizes, total weight in grams, total calories (kcal), and macronutrients (protein, carbs, fat, fiber, sugar, sodium).
        Return ONLY valid JSON matching this schema:
        {
          "foodName": "Concise descriptive meal name",
          "calories": 450,
          "protein": 35,
          "carbs": 40,
          "fat": 12,
          "fiber": 5,
          "sugar": 4,
          "sodium": 500,
          "servingDescription": "Total portion (e.g. 1 bowl (350g) or 2 eggs + 1 toast)",
          "estimatedGrams": 350,
          "ingredientsDetected": ["2 scrambled eggs", "1 slice sourdough", "10g butter"],
          "confidence": "High"
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
    
    // MARK: - Photo Analysis
    func analyzeFood(image: UIImage, apiKey: String) async throws -> AIFoodEstimate {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKey.isEmpty else {
            throw AIScannerError.missingApiKey
        }
        
        // Fast, light 512px image payload (~30KB)
        let resized = resizeImage(image, maxDimension: 512)
        guard let jpegData = resized.jpegData(compressionQuality: 0.6) else {
            throw AIScannerError.imageCompressionFailed
        }
        let base64String = jpegData.base64EncodedString()
        
        let candidateModels = [
            preferredModel,
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
        You are an expert nutritionist. Analyze the food in this image.
        Estimate total portion in grams, calories, and macros (protein, carbs, fat, fiber, sugar, sodium).
        Return ONLY valid JSON matching this schema:
        {
          "foodName": "Meal name",
          "calories": 450,
          "protein": 35,
          "carbs": 40,
          "fat": 12,
          "fiber": 5,
          "sugar": 4,
          "sodium": 500,
          "servingDescription": "1 plate (320g)",
          "estimatedGrams": 320,
          "ingredientsDetected": ["item 1", "item 2"],
          "confidence": "High"
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
            let errorText = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw AIScannerError.apiError("Model \(cleanModel) error: \(errorText)")
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
