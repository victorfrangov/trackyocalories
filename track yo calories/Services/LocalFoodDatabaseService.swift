//
//  LocalFoodDatabaseService.swift
//  track yo calories
//

import Foundation
import SQLite3

final class LocalFoodDatabaseService: @unchecked Sendable {
    static let shared = LocalFoodDatabaseService()
    
    private var db: OpaquePointer? = nil
    private let queue = DispatchQueue(label: "app.trackyocalories.localdatabase", qos: .userInitiated)
    
    init() {
        openDatabase()
    }
    
    deinit {
        if let db = db {
            sqlite3_close(db)
        }
    }
    
    private func openDatabase() {
        // Look in Bundle first, then fallback to current directory
        var dbUrl = Bundle.main.url(forResource: "FoodDatabase", withExtension: "sqlite")
        if dbUrl == nil {
            let directPath = "/Users/victor/dev/track yo calories/track yo calories/track yo calories/FoodDatabase.sqlite"
            if FileManager.default.fileExists(atPath: directPath) {
                dbUrl = URL(fileURLWithPath: directPath)
            }
        }
        
        guard let url = dbUrl else {
            print("LocalFoodDatabaseService: FoodDatabase.sqlite not found in bundle.")
            return
        }
        
        if sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) != SQLITE_OK {
            print("LocalFoodDatabaseService: Failed to open SQLite database at \(url.path)")
            db = nil
        } else {
            print("LocalFoodDatabaseService: Successfully opened SQLite database (7,900+ foods ready).")
        }
    }
    
    /// Instant tokenized multi-word search across 7,900+ Swiss, EU & USDA foods
    func search(query: String, limit: Int = 40) -> [FoodItem] {
        guard let db = db else {
            return []
        }
        
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return defaultStaples()
        }
        
        let tokens = trimmed.components(separatedBy: " ").filter { !$0.isEmpty }
        guard !tokens.isEmpty else { return [] }
        
        var whereClauses: [String] = []
        for _ in tokens {
            whereClauses.append("(name LIKE ? OR brand LIKE ? OR category LIKE ?)")
        }
        
        let sql = """
        SELECT id, barcode, name, brand, category, calories, protein, carbs, fat, fiber, sugar, saturated_fat, sodium, potassium, cholesterol, serving_options_json, origin
        FROM foods
        WHERE \(whereClauses.joined(separator: " AND "))
        ORDER BY 
            CASE 
                WHEN name LIKE ? THEN 1
                WHEN name LIKE ? THEN 2
                ELSE 3
            END,
            LENGTH(name) ASC
        LIMIT \(limit);
        """
        
        var statement: OpaquePointer? = nil
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("LocalFoodDatabaseService: SQL error")
            return []
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        var bindIndex: Int32 = 1
        for token in tokens {
            let pattern = "%\(token)%"
            sqlite3_bind_text(statement, bindIndex, (pattern as NSString).utf8String, -1, nil)
            bindIndex += 1
            sqlite3_bind_text(statement, bindIndex, (pattern as NSString).utf8String, -1, nil)
            bindIndex += 1
            sqlite3_bind_text(statement, bindIndex, (pattern as NSString).utf8String, -1, nil)
            bindIndex += 1
        }
        
        // Exact prefix ordering patterns
        let prefixPattern = "\(trimmed)%"
        let subPattern = "%\(trimmed)%"
        sqlite3_bind_text(statement, bindIndex, (prefixPattern as NSString).utf8String, -1, nil)
        bindIndex += 1
        sqlite3_bind_text(statement, bindIndex, (subPattern as NSString).utf8String, -1, nil)
        
        var results: [FoodItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = parseRow(statement) {
                results.append(item)
            }
        }
        
        return results
    }
    
    /// Default staples when search is empty
    func defaultStaples(limit: Int = 35) -> [FoodItem] {
        guard let db = db else {
            return []
        }
        
        let sql = """
        SELECT id, barcode, name, brand, category, calories, protein, carbs, fat, fiber, sugar, saturated_fat, sodium, potassium, cholesterol, serving_options_json, origin
        FROM foods
        WHERE origin IN ('Swiss BLV', 'EuroFIR CIQUAL') OR id IN (
            SELECT id FROM foods LIMIT \(limit)
        )
        ORDER BY origin DESC, name ASC
        LIMIT \(limit);
        """
        
        var statement: OpaquePointer? = nil
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return []
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        var results: [FoodItem] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let item = parseRow(statement) {
                results.append(item)
            }
        }
        
        return results
    }
    
    private func parseRow(_ stmt: OpaquePointer?) -> FoodItem? {
        guard let stmt = stmt else { return nil }
        
        let idStr = String(cString: sqlite3_column_text(stmt, 0))
        let id = UUID(uuidString: idStr) ?? UUID()
        
        let barcode: String? = sqlite3_column_type(stmt, 1) != SQLITE_NULL ? String(cString: sqlite3_column_text(stmt, 1)) : nil
        let name = String(cString: sqlite3_column_text(stmt, 2))
        let brand: String? = sqlite3_column_type(stmt, 3) != SQLITE_NULL ? String(cString: sqlite3_column_text(stmt, 3)) : nil
        let category = String(cString: sqlite3_column_text(stmt, 4))
        
        let calories = sqlite3_column_double(stmt, 5)
        let protein = sqlite3_column_double(stmt, 6)
        let carbs = sqlite3_column_double(stmt, 7)
        let fat = sqlite3_column_double(stmt, 8)
        
        let fiber: Double? = sqlite3_column_type(stmt, 9) != SQLITE_NULL ? sqlite3_column_double(stmt, 9) : nil
        let sugar: Double? = sqlite3_column_type(stmt, 10) != SQLITE_NULL ? sqlite3_column_double(stmt, 10) : nil
        let satFat: Double? = sqlite3_column_type(stmt, 11) != SQLITE_NULL ? sqlite3_column_double(stmt, 11) : nil
        let sodium: Double? = sqlite3_column_type(stmt, 12) != SQLITE_NULL ? sqlite3_column_double(stmt, 12) : nil
        let potassium: Double? = sqlite3_column_type(stmt, 13) != SQLITE_NULL ? sqlite3_column_double(stmt, 13) : nil
        let cholesterol: Double? = sqlite3_column_type(stmt, 14) != SQLITE_NULL ? sqlite3_column_double(stmt, 14) : nil
        
        let servingsJson = String(cString: sqlite3_column_text(stmt, 15))
        var servings: [ServingOption] = []
        if let data = servingsJson.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([ServingOption].self, from: data) {
            servings = decoded
        }
        if servings.isEmpty {
            servings = [ServingOption.grams(100.0)]
        }
        
        let nutrients = NutrientInfo(
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
            sugar: sugar,
            saturatedFat: satFat,
            sodium: sodium,
            potassium: potassium,
            cholesterol: cholesterol
        )
        
        return FoodItem(
            id: id,
            barcode: barcode,
            name: name,
            brand: brand,
            category: category,
            nutrientsPer100g: nutrients,
            servingOptions: servings,
            isCustom: false,
            isVerified: true
        )
    }
}
