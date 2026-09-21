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

    /// Last destructive change, kept so the UI can offer "Undo".
    @Published private(set) var undoAction: UndoAction? = nil

    struct UndoAction: Identifiable {
        let id = UUID()
        let message: String
        fileprivate let restore: @MainActor (DataStore) -> Void
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

        // Seed the weight history from the profile once the user has actually onboarded
        // (previously a placeholder 75 kg entry was created before onboarding).
        if weightEntries.isEmpty && userProfile.isOnboarded {
            weightEntries.append(WeightEntry(date: Date(), weightKg: userProfile.weightKg))
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

        let widgetData = CalorieWidgetData(
            caloriesConsumed: consumedCals,
            calorieBudget: budgetCals,
            caloriesRemaining: remainingCals,
            proteinConsumed: Int(totalProtein(for: today)),
            proteinTarget: Int(targets.proteinGrams),
            carbsConsumed: Int(totalCarbs(for: today)),
            carbsTarget: Int(targets.carbsGrams),
            fatConsumed: Int(totalFat(for: today)),
            fatTarget: Int(targets.fatGrams),
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

    /// Start-of-day dates that have at least one logged entry.
    var loggedDays: Set<Date> {
        let calendar = Calendar.current
        return Set(loggedEntries.map { calendar.startOfDay(for: $0.date) })
    }

    /// Consecutive days with logged food, ending today (or yesterday while today is still empty).
    var currentStreak: Int {
        let calendar = Calendar.current
        let days = loggedDays
        var check = calendar.startOfDay(for: Date())
        if !days.contains(check) {
            check = calendar.date(byAdding: .day, value: -1, to: check) ?? check
        }
        var streak = 0
        while days.contains(check) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: check) else { break }
            check = prev
        }
        return streak
    }

    func totalCalories(for date: Date) -> Double {
        entries(for: date).reduce(0.0) { $0 + $1.calories }
    }

    /// Average daily calories over the logged days of the selected date's week.
    func weeklyAverageCalories(for date: Date) -> Double {
        let calendar = Calendar.current
        var startOfWeek = date
        var interval: TimeInterval = 0
        _ = calendar.dateInterval(of: .weekOfYear, start: &startOfWeek, interval: &interval, for: date)

        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
        let totals = days.map { totalCalories(for: $0) }.filter { $0 > 0 }
        return totals.isEmpty ? 0 : totals.reduce(0, +) / Double(totals.count)
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

    func waterLogs(for date: Date) -> [WaterLog] {
        let calendar = Calendar.current
        return waterLogs.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func waterIntake(for date: Date) -> Double {
        waterLogs(for: date).reduce(0.0) { $0 + $1.amountMl }
    }

    // MARK: - Mutations
    /// - Parameter remember: add the food to "Recent" (off for one-off quick entries).
    @discardableResult
    func logFood(food: FoodItem, mealType: MealType, serving: ServingOption, quantity: Double, date: Date, remember: Bool = true) -> UUID {
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

        if remember {
            addToRecents(food)
        }
        return entry.id
    }

    /// Edits an entry in place so it keeps its position and identity.
    func updateEntry(id: UUID, mealType: MealType, serving: ServingOption, quantity: Double, date: Date) {
        guard let idx = loggedEntries.firstIndex(where: { $0.id == id }) else { return }
        var entry = loggedEntries[idx]
        entry.mealType = mealType
        entry.servingOption = serving
        entry.quantity = quantity
        entry.date = date
        loggedEntries[idx] = entry
    }

    func deleteEntry(id: UUID) {
        guard let entry = loggedEntries.first(where: { $0.id == id }) else { return }
        loggedEntries.removeAll { $0.id == id }
        registerUndo("Deleted \(entry.food.name)") { store in
            store.loggedEntries.append(entry)
        }
    }

    /// Copies a meal from another day. Returns the number of foods copied.
    @discardableResult
    func duplicateMeal(mealType: MealType, from sourceDate: Date, to targetDate: Date) -> Int {
        let sourceEntries = entries(for: sourceDate, meal: mealType)
        let copies = sourceEntries.map { item in
            LoggedEntry(
                id: UUID(),
                date: targetDate,
                createdAt: Date(),
                mealType: mealType,
                food: item.food,
                servingOption: item.servingOption,
                quantity: item.quantity
            )
        }
        loggedEntries.append(contentsOf: copies)
        return copies.count
    }

    func clearMeal(mealType: MealType, on date: Date) {
        let removed = entries(for: date, meal: mealType)
        guard !removed.isEmpty else { return }
        let ids = Set(removed.map(\.id))
        loggedEntries.removeAll { ids.contains($0.id) }
        registerUndo("Cleared \(mealType.displayName)") { store in
            store.loggedEntries.append(contentsOf: removed)
        }
    }

    func logWater(amountMl: Double, date: Date) {
        let log = WaterLog(id: UUID(), date: date, amountMl: amountMl, timestamp: Date())
        waterLogs.append(log)
    }

    /// Removes the most recent water log of the given day (the "−" button).
    func removeLastWater(on date: Date) {
        guard let last = waterLogs(for: date).max(by: { $0.timestamp < $1.timestamp }) else { return }
        waterLogs.removeAll { $0.id == last.id }
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
        syncProfileWeight()
    }

    func deleteWeightEntry(id: UUID) {
        guard let entry = weightEntries.first(where: { $0.id == id }) else { return }
        weightEntries.removeAll { $0.id == id }
        syncProfileWeight()
        registerUndo("Deleted weigh-in") { store in
            store.weightEntries.append(entry)
            store.weightEntries.sort(by: { $0.date < $1.date })
            store.syncProfileWeight()
        }
    }

    /// The profile weight (which drives calorie targets) follows the most recent weigh-in,
    /// so back-dating an entry no longer overwrites the current weight.
    private func syncProfileWeight() {
        if let latest = weightEntries.max(by: { $0.date < $1.date }), latest.weightKg != userProfile.weightKg {
            userProfile.weightKg = latest.weightKg
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

    func deleteCustomFood(id: UUID) {
        customFoods.removeAll { $0.id == id }
        favoriteFoods.removeAll { $0.id == id }
    }

    func addRecipe(_ recipe: Recipe) {
        recipes.insert(recipe, at: 0)
    }

    func deleteRecipe(id: UUID) {
        recipes.removeAll { $0.id == id }
        // Older versions also stored each recipe as a custom food with the same id.
        customFoods.removeAll { $0.id == id }
        favoriteFoods.removeAll { $0.id == id }
    }

    // MARK: - Undo
    func undo() {
        guard let action = undoAction else { return }
        undoAction = nil
        action.restore(self)
    }

    /// Hides the undo banner. Passing an id only hides it if it is still the current action.
    func dismissUndo(_ id: UUID? = nil) {
        if id == nil || undoAction?.id == id {
            undoAction = nil
        }
    }

    private func registerUndo(_ message: String, restore: @escaping @MainActor (DataStore) -> Void) {
        undoAction = UndoAction(message: message, restore: restore)
    }

    // MARK: - Backup & Restore
    struct Backup: Codable {
        var version: Int = 1
        var exportedAt: Date = Date()
        var userProfile: UserProfile
        var loggedEntries: [LoggedEntry]
        var waterLogs: [WaterLog]
        var weightEntries: [WeightEntry]
        var customFoods: [FoodItem]
        var favoriteFoods: [FoodItem]
        var recentFoods: [FoodItem]
        var recipes: [Recipe]
    }

    /// Writes a complete backup of all user data to a temporary file and returns its URL.
    func exportBackup() throws -> URL {
        var profile = userProfile
        profile.geminiApiKey = nil // never put the API key in a file that gets shared
        let backup = Backup(
            userProfile: profile,
            loggedEntries: loggedEntries,
            waterLogs: waterLogs,
            weightEntries: weightEntries,
            customFoods: customFoods,
            favoriteFoods: favoriteFoods,
            recentFoods: recentFoods,
            recipes: recipes
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let stamp = Date().formatted(.iso8601.year().month().day())
        let url = fileManager.temporaryDirectory.appendingPathComponent("TrackYoCalories-Backup-\(stamp).json")
        try encoder.encode(backup).write(to: url, options: .atomic)
        return url
    }

    /// Replaces all data with the contents of a backup file. The current API key is kept.
    func importBackup(from url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(Backup.self, from: Data(contentsOf: url))

        var profile = backup.userProfile
        profile.geminiApiKey = userProfile.geminiApiKey
        profile.isOnboarded = true
        userProfile = profile
        loggedEntries = backup.loggedEntries
        waterLogs = backup.waterLogs
        weightEntries = backup.weightEntries.sorted(by: { $0.date < $1.date })
        customFoods = backup.customFoods
        favoriteFoods = backup.favoriteFoods
        recentFoods = backup.recentFoods
        recipes = backup.recipes
        undoAction = nil
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
            // Keep a copy of unreadable files instead of silently overwriting them on the next save.
            let backupURL = url.deletingPathExtension().appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
            try? fileManager.copyItem(at: url, to: backupURL)
            print("Failed to load JSON from \(url.lastPathComponent): \(error)")
            return nil
        }
    }
}
