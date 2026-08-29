//
//  DataStore.swift
//  track yo calories
//

import SwiftUI
import Combine
import WidgetKit

@MainActor
final class DataStore: ObservableObject {
    static let shared = DataStore()
    
    // MARK: - Published State
    @Published var userProfile: UserProfile = .default {
        didSet {
            saveProfile()
            updateWidgetData()
        }
    }
    
    @Published var selectedDate: Date = Date()
    
    @Published var loggedEntries: [LoggedEntry] = [] {
        didSet {
            saveEntries()
            updateWidgetData()
        }
    }
    
    @Published var waterLogs: [WaterLog] = [] {
        didSet { saveWater() }
    }
    
    @Published var weightEntries: [WeightEntry] = [] {
        didSet { saveWeight() }
    }
    
    @Published var customFoods: [FoodItem] = [] {
        didSet { saveCustomFoods() }
    }
    
    @Published var favoriteFoods: [FoodItem] = [] {
        didSet { saveFavorites() }
    }
    
    @Published var recentFoods: [FoodItem] = [] {
        didSet { saveRecents() }
    }
    
    @Published var recipes: [Recipe] = [] {
        didSet { saveRecipes() }
    }
    
    // MARK: - File Storage Paths
    private let fileManager = FileManager.default
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var profileURL: URL { documentsDirectory.appendingPathComponent("user_profile.json") }
    private var entriesURL: URL { documentsDirectory.appendingPathComponent("logged_entries.json") }
    private var waterURL: URL { documentsDirectory.appendingPathComponent("water_logs.json") }
    private var weightURL: URL { documentsDirectory.appendingPathComponent("weight_entries.json") }
    private var customFoodsURL: URL { documentsDirectory.appendingPathComponent("custom_foods.json") }
    private var favoritesURL: URL { documentsDirectory.appendingPathComponent("favorite_foods.json") }
    private var recentsURL: URL { documentsDirectory.appendingPathComponent("recent_foods.json") }
    private var recipesURL: URL { documentsDirectory.appendingPathComponent("recipes.json") }
    
    // MARK: - Initialization
    init() {
        loadAll()
        
        // If first launch, create an initial weight entry matching the default profile
        if weightEntries.isEmpty {
            let initialWeight = WeightEntry(date: Date(), weightKg: userProfile.weightKg)
            weightEntries.append(initialWeight)
            saveWeight()
        }
        
        updateWidgetData()
    }
    
    // MARK: - Widget Synchronization
    func updateWidgetData() {
        let today = Date()
        let consumedCals = Int(totalCalories(for: today))
        let targets = NutritionEngine.calculateMacroTargets(profile: userProfile)
        let budgetCals = Int(targets.calories)
        let remainingCals = max(0, budgetCals - consumedCals)
        
        let pConsumed = Int(totalProtein(for: today))
        let pTarget = Int(targets.proteinGrams)
        
        let cConsumed = Int(totalCarbs(for: today))
        let cTarget = Int(targets.carbsGrams)
        
        let fConsumed = Int(totalFat(for: today))
        let fTarget = Int(targets.fatGrams)
        
        let widgetData = CalorieWidgetData(
            caloriesConsumed: consumedCals,
            calorieBudget: budgetCals,
            caloriesRemaining: remainingCals,
            proteinConsumed: pConsumed,
            proteinTarget: pTarget,
            carbsConsumed: cConsumed,
            carbsTarget: cTarget,
            fatConsumed: fConsumed,
            fatTarget: fTarget,
            lastUpdated: Date()
        )
        
        widgetData.save()
    }
    
    // MARK: - Daily Filtering & Computations
    func entries(for date: Date) -> [LoggedEntry] {
        let calendar = Calendar.current
        return loggedEntries.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    func entries(for date: Date, meal: MealType) -> [LoggedEntry] {
        let calendar = Calendar.current
        return loggedEntries.filter { calendar.isDate($0.date, inSameDayAs: date) && $0.mealType == meal }
    }
    
    func totalCalories(for date: Date) -> Double {
        entries(for: date).reduce(0.0) { $0 + $1.calories }
    }
    
    func weeklyAverageCalories(for date: Date) -> Double {
        let calendar = Calendar.current
        var startOfWeek = date
        var interval: TimeInterval = 0
        _ = calendar.dateInterval(of: .weekOfYear, start: &startOfWeek, interval: &interval, for: date)
        
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
        let total = days.reduce(0.0) { $0 + totalCalories(for: $1) }
        let activeDays = days.filter { !entries(for: $0).isEmpty }.count
        
        return activeDays > 0 ? (total / Double(activeDays)) : totalCalories(for: date)
    }
    
    func totalProtein(for date: Date) -> Double {
        entries(for: date).reduce(0.0) { $0 + $1.protein }
    }
    
    func totalCarbs(for date: Date) -> Double {
        entries(for: date).reduce(0.0) { $0 + $1.carbs }
    }
    
    func totalFat(for date: Date) -> Double {
        entries(for: date).reduce(0.0) { $0 + $1.fat }
    }
    
    func totalFiber(for date: Date) -> Double {
        entries(for: date).reduce(0.0) { $0 + $1.fiber }
    }
    
    func totalSugar(for date: Date) -> Double {
        entries(for: date).reduce(0.0) { $0 + $1.sugar }
    }
    
    func totalSodium(for date: Date) -> Double {
        entries(for: date).reduce(0.0) { $0 + $1.sodium }
    }
    
    func waterIntake(for date: Date) -> Double {
        let calendar = Calendar.current
        return waterLogs
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .reduce(0.0) { $0 + $1.amountMl }
    }
    
    // MARK: - Mutations
    func logFood(food: FoodItem, mealType: MealType, serving: ServingOption, quantity: Double, date: Date) {
        let entry = LoggedEntry(
            id: UUID(),
            date: date,
            createdAt: Date(),
            mealType: mealType,
            food: food,
            servingOption: serving,
            quantity: quantity
        )
        loggedEntries.append(entry)
        
        // Add to recents (keep last 30 unique)
        addToRecents(food)
    }
    
    func deleteEntry(id: UUID) {
        loggedEntries.removeAll { $0.id == id }
    }
    
    func duplicateMeal(mealType: MealType, from sourceDate: Date, to targetDate: Date) {
        let sourceEntries = entries(for: sourceDate, meal: mealType)
        for item in sourceEntries {
            let newEntry = LoggedEntry(
                id: UUID(),
                date: targetDate,
                createdAt: Date(),
                mealType: mealType,
                food: item.food,
                servingOption: item.servingOption,
                quantity: item.quantity
            )
            loggedEntries.append(newEntry)
        }
    }
    
    func clearMeal(mealType: MealType, on date: Date) {
        let calendar = Calendar.current
        loggedEntries.removeAll { calendar.isDate($0.date, inSameDayAs: date) && $0.mealType == mealType }
    }
    
    func logWater(amountMl: Double, date: Date) {
        let log = WaterLog(id: UUID(), date: date, amountMl: amountMl, timestamp: Date())
        waterLogs.append(log)
    }
    
    func logWeight(weightKg: Double, bodyFat: Double? = nil, waistCm: Double? = nil, chestCm: Double? = nil, hipsCm: Double? = nil, notes: String? = nil, date: Date = Date()) {
        let entry = WeightEntry(
            id: UUID(),
            date: date,
            weightKg: weightKg,
            bodyFatPercentage: bodyFat,
            waistCm: waistCm,
            chestCm: chestCm,
            hipsCm: hipsCm,
            notes: notes
        )
        
        weightEntries.append(entry)
        weightEntries.sort(by: { $0.date < $1.date })
        
        userProfile.weightKg = weightKg
    }
    
    func deleteWeightEntry(id: UUID) {
        weightEntries.removeAll { $0.id == id }
        if let last = weightEntries.sorted(by: { $0.date < $1.date }).last {
            userProfile.weightKg = last.weightKg
        }
    }
    
    func addToRecents(_ food: FoodItem) {
        var list = recentFoods.filter { $0.id != food.id && $0.name.lowercased() != food.name.lowercased() }
        list.insert(food, at: 0)
        recentFoods = Array(list.prefix(30))
    }
    
    func toggleFavorite(_ food: FoodItem) {
        if let idx = favoriteFoods.firstIndex(where: { $0.id == food.id || $0.name.lowercased() == food.name.lowercased() }) {
            favoriteFoods.remove(at: idx)
        } else {
            favoriteFoods.insert(food, at: 0)
        }
    }
    
    func isFavorite(_ food: FoodItem) -> Bool {
        favoriteFoods.contains { $0.id == food.id || $0.name.lowercased() == food.name.lowercased() }
    }
    
    func addCustomFood(_ food: FoodItem) {
        customFoods.insert(food, at: 0)
    }
    
    func addRecipe(_ recipe: Recipe) {
        recipes.insert(recipe, at: 0)
    }
    
    func deleteRecipe(id: UUID) {
        recipes.removeAll { $0.id == id }
    }
    
    // MARK: - Persistence IO
    private func saveProfile() {
        saveJSON(userProfile, to: profileURL)
    }
    
    private func saveEntries() {
        saveJSON(loggedEntries, to: entriesURL)
    }
    
    private func saveWater() {
        saveJSON(waterLogs, to: waterURL)
    }
    
    private func saveWeight() {
        saveJSON(weightEntries, to: weightURL)
    }
    
    private func saveCustomFoods() {
        saveJSON(customFoods, to: customFoodsURL)
    }
    
    private func saveFavorites() {
        saveJSON(favoriteFoods, to: favoritesURL)
    }
    
    private func saveRecents() {
        saveJSON(recentFoods, to: recentsURL)
    }
    
    private func saveRecipes() {
        saveJSON(recipes, to: recipesURL)
    }
    
    private func loadAll() {
        if let p: UserProfile = loadJSON(from: profileURL) { self.userProfile = p }
        if let e: [LoggedEntry] = loadJSON(from: entriesURL) { self.loggedEntries = e }
        if let w: [WaterLog] = loadJSON(from: waterURL) { self.waterLogs = w }
        if let we: [WeightEntry] = loadJSON(from: weightURL) { self.weightEntries = we }
        if let c: [FoodItem] = loadJSON(from: customFoodsURL) { self.customFoods = c }
        if let f: [FoodItem] = loadJSON(from: favoritesURL) { self.favoriteFoods = f }
        if let r: [FoodItem] = loadJSON(from: recentsURL) { self.recentFoods = r }
        if let rec: [Recipe] = loadJSON(from: recipesURL) { self.recipes = rec }
    }
    
    private func saveJSON<T: Encodable>(_ object: T, to url: URL) {
        do {
            let data = try JSONEncoder().encode(object)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to save JSON to \(url.lastPathComponent): \(error)")
        }
    }
    
    private func loadJSON<T: Decodable>(from url: URL) -> T? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("Failed to load JSON from \(url.lastPathComponent): \(error)")
            return nil
        }
    }
}
