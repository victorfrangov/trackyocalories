//
//  CreateFoodView.swift
//  track yo calories
//

import SwiftUI

struct CreateFoodView: View {
    @ObservedObject var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss
    
    var initialMode: CreateMode = .customFood
    @State private var mode: CreateMode = .customFood
    
    // Custom Food State
    @State private var name: String = ""
    @State private var brand: String = ""
    @State private var servingName: String = "1 serving"
    @State private var servingGramsText: String = "100"
    @State private var caloriesText: String = ""
    @State private var proteinText: String = ""
    @State private var carbsText: String = ""
    @State private var fatText: String = ""
    @State private var fiberText: String = ""
    @State private var sugarText: String = ""
    @State private var sodiumText: String = ""
    
    // Recipe State
    @State private var recipeName: String = ""
    @State private var recipeServings: Int = 2
    @State private var recipeIngredients: [RecipeIngredient] = []
    @State private var showIngredientPicker: Bool = false
    @State private var showImportMealSheet: Bool = false
    
    enum CreateMode: String, CaseIterable, Identifiable {
        case customFood = "Custom Food"
        case recipe = "Recipe"
        var id: String { rawValue }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $mode) {
                        ForEach(CreateMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                if mode == .customFood {
                    customFoodForm
                } else {
                    recipeForm
                }
            }
            .navigationTitle(mode == .customFood ? "Create Food" : "Create Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if mode == .customFood {
                            saveCustomFood()
                        } else {
                            saveRecipe()
                        }
                    }
                    .disabled(mode == .customFood ? name.trimmingCharacters(in: .whitespaces).isEmpty : (recipeName.trimmingCharacters(in: .whitespaces).isEmpty || recipeIngredients.isEmpty))
                }
            }
            .sheet(isPresented: $showIngredientPicker) {
                IngredientPickerSheet(dataStore: dataStore) { ingredient in
                    recipeIngredients.append(ingredient)
                }
            }
            .sheet(isPresented: $showImportMealSheet) {
                ImportMealSheet(dataStore: dataStore) { name, ingredients in
                    self.recipeName = name
                    self.recipeIngredients = ingredients
                }
            }
        }
    }
    
    // MARK: - Custom Food Form
    @ViewBuilder
    private var customFoodForm: some View {
        Section("General Info") {
            TextField("Food Name (e.g. Grandma's Oatmeal Cookie)", text: $name)
            TextField("Brand / Source (Optional)", text: $brand)
        }
        
        Section("Serving Size") {
            HStack {
                Text("Serving Description")
                Spacer()
                TextField("e.g. 1 cookie", text: $servingName)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Weight (grams)")
                Spacer()
                TextField("100", text: $servingGramsText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
        }
        
        Section("Nutrition Per Serving") {
            HStack {
                Text("Calories (kcal)")
                Spacer()
                TextField("0", text: $caloriesText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Protein (g)")
                Spacer()
                TextField("0", text: $proteinText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Carbs (g)")
                Spacer()
                TextField("0", text: $carbsText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Fat (g)")
                Spacer()
                TextField("0", text: $fatText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        }
        
        Section("Optional Details") {
            HStack {
                Text("Fiber (g)")
                Spacer()
                TextField("0", text: $fiberText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Sugar (g)")
                Spacer()
                TextField("0", text: $sugarText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("Sodium (mg)")
                Spacer()
                TextField("0", text: $sodiumText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
    
    // MARK: - Recipe Form
    @ViewBuilder
    private var recipeForm: some View {
        // Quick 1-Tap Import from Diary
        Section {
            Button {
                showImportMealSheet = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "sparkles")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import from Logged Meal")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        Text("Turn foods you already logged into a recipe")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        
        Section("Recipe Details") {
            TextField("Recipe Name (e.g. Protein Banana Pancakes)", text: $recipeName)
            Stepper("Servings: \(recipeServings)", value: $recipeServings, in: 1...50)
        }
        
        Section("Ingredients") {
            if recipeIngredients.isEmpty {
                Text("No ingredients added yet")
                    .foregroundColor(.secondary)
            } else {
                ForEach(recipeIngredients) { ing in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ing.food.displayName)
                                .font(.system(size: 15, weight: .semibold))
                            Text("\(ing.quantity.formatted())x \(ing.servingOption.name) (\(Int(ing.totalGrams))g)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(Int(ing.nutrients.calories)) kcal")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                }
                .onDelete { indexSet in
                    recipeIngredients.remove(atOffsets: indexSet)
                }
            }
            
            Button(action: { showIngredientPicker = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.orange)
                    Text("Add Ingredient")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.orange)
                }
            }
        }
        
        if !recipeIngredients.isEmpty {
            let tempRecipe = Recipe(id: UUID(), name: recipeName, servings: recipeServings, ingredients: recipeIngredients)
            let perServing = tempRecipe.nutrientsPerServing
            
            Section("Nutrition Per Serving (1 / \(recipeServings))") {
                HStack {
                    Text("Calories")
                    Spacer()
                    Text("\(Int(perServing.calories)) kcal").bold()
                }
                HStack {
                    Text("Protein")
                    Spacer()
                    Text("\(Int(perServing.protein)) g").foregroundColor(.orange).bold()
                }
                HStack {
                    Text("Carbs")
                    Spacer()
                    Text("\(Int(perServing.carbs)) g").foregroundColor(.blue).bold()
                }
                HStack {
                    Text("Fat")
                    Spacer()
                    Text("\(Int(perServing.fat)) g").foregroundColor(.purple).bold()
                }
            }
        }
    }
    
    private func saveCustomFood() {
        let servGrams = Double(servingGramsText) ?? 100.0
        let cal = Double(caloriesText) ?? 0.0
        let pro = Double(proteinText) ?? 0.0
        let carb = Double(carbsText) ?? 0.0
        let fat = Double(fatText) ?? 0.0
        let fib = Double(fiberText)
        let sug = Double(sugarText)
        let sod = Double(sodiumText)
        
        let factor = 100.0 / max(1.0, servGrams)
        let nutrients100g = NutrientInfo(
            calories: cal * factor,
            protein: pro * factor,
            carbs: carb * factor,
            fat: fat * factor,
            fiber: fib.map { $0 * factor },
            sugar: sug.map { $0 * factor },
            sodium: sod.map { $0 * factor }
        )
        
        let desc = servingName.trimmingCharacters(in: .whitespaces).isEmpty ? "1 serving" : servingName
        let servingOption = ServingOption(id: UUID(), name: "\(desc) (\(Int(servGrams))g)", gramWeight: servGrams, isDefault: true)
        
        let newFood = FoodItem(
            id: UUID(),
            barcode: nil,
            name: name.trimmingCharacters(in: .whitespaces),
            brand: brand.trimmingCharacters(in: .whitespaces).isEmpty ? "Custom" : brand.trimmingCharacters(in: .whitespaces),
            category: "Custom Foods",
            nutrientsPer100g: nutrients100g,
            servingOptions: [
                servingOption,
                ServingOption.grams(100.0),
                ServingOption(id: UUID(), name: "1g", gramWeight: 1.0, isDefault: false)
            ],
            isCustom: true,
            isVerified: true
        )
        
        dataStore.addCustomFood(newFood)
        dismiss()
    }
    
    private func saveRecipe() {
        let recipe = Recipe(
            id: UUID(),
            name: recipeName.trimmingCharacters(in: .whitespaces),
            servings: max(1, recipeServings),
            ingredients: recipeIngredients,
            createdAt: Date()
        )
        
        dataStore.addRecipe(recipe)
        dataStore.addCustomFood(recipe.toFoodItem())
        dismiss()
    }
}

// MARK: - Import Past Meal Sheet
struct ImportMealSheet: View {
    @ObservedObject var dataStore: DataStore
    var onSelect: (String, [RecipeIngredient]) -> Void
    @Environment(\.dismiss) private var dismiss
    
    struct PastMealOption: Identifiable {
        let id = UUID()
        let date: Date
        let mealType: MealType
        let entries: [LoggedEntry]
        
        var dateLabel: String {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                return "Today"
            } else if calendar.isDateInYesterday(date) {
                return "Yesterday"
            } else {
                let f = DateFormatter()
                f.dateFormat = "EEE, MMM d"
                return f.string(from: date)
            }
        }
        
        var totalCalories: Int {
            Int(entries.reduce(0.0) { $0 + $1.calories })
        }
    }
    
    private var pastMeals: [PastMealOption] {
        let calendar = Calendar.current
        var groups: [String: (Date, MealType, [LoggedEntry])] = [:]
        
        for entry in dataStore.loggedEntries.reversed() {
            let dayStart = calendar.startOfDay(for: entry.date)
            let key = "\(dayStart.timeIntervalSince1970)_\(entry.mealType.rawValue)"
            if groups[key] == nil {
                groups[key] = (entry.date, entry.mealType, [entry])
            } else {
                groups[key]?.2.append(entry)
            }
        }
        
        return groups.values
            .map { PastMealOption(date: $0.0, mealType: $0.1, entries: $0.2) }
            .sorted { $0.date > $1.date }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if pastMeals.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "fork.knife.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No logged meals found")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Log meals in your diary first to convert them into recipes")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(pastMeals) { meal in
                        Button {
                            let ingredients = meal.entries.map { entry in
                                RecipeIngredient(
                                    id: UUID(),
                                    food: entry.food,
                                    servingOption: entry.servingOption,
                                    quantity: entry.quantity
                                )
                            }
                            let recipeTitle = "\(meal.mealType.displayName) Recipe"
                            onSelect(recipeTitle, ingredients)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("\(meal.dateLabel) — \(meal.mealType.displayName)")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Text("\(meal.totalCalories) kcal")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.orange)
                                }
                                
                                Text(meal.entries.map { "\($0.food.name) (\(Int($0.totalGrams))g)" }.joined(separator: " • "))
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Import from Past Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Ingredient Picker with History & Past Foods First
struct IngredientPickerSheet: View {
    @ObservedObject var dataStore: DataStore
    var onAdd: (RecipeIngredient) -> Void
    @Environment(\.dismiss) private var dismiss
    
    enum Tab: String, CaseIterable, Identifiable {
        case history = "History"
        case favorites = "Favorites"
        case created = "My Foods"
        case database = "Database"
        var id: String { rawValue }
    }
    
    @State private var selectedTab: Tab = .history
    @State private var query: String = ""
    @State private var selectedFood: FoodItem? = nil
    @State private var selectedServing: ServingOption = ServingOption.grams(100)
    @State private var quantity: Double = 1.0
    
    // Ingredients the user has already put/logged before (most recent first, deduplicated)
    private var historyFoods: [FoodItem] {
        var seen = Set<String>()
        var list: [FoodItem] = []
        
        for entry in dataStore.loggedEntries.reversed() {
            let key = entry.food.name.lowercased().trimmingCharacters(in: .whitespaces)
            if !seen.contains(key) {
                seen.insert(key)
                list.append(entry.food)
            }
        }
        
        for food in dataStore.recentFoods {
            let key = food.name.lowercased().trimmingCharacters(in: .whitespaces)
            if !seen.contains(key) {
                seen.insert(key)
                list.append(food)
            }
        }
        
        for food in dataStore.customFoods {
            let key = food.name.lowercased().trimmingCharacters(in: .whitespaces)
            if !seen.contains(key) {
                seen.insert(key)
                list.append(food)
            }
        }
        
        return list
    }
    
    private var displayedFoods: [FoodItem] {
        let clean = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if clean.isEmpty {
            switch selectedTab {
            case .history:
                let h = historyFoods
                return h.isEmpty ? LocalFoodDatabaseService.shared.defaultStaples() : h
            case .favorites:
                return dataStore.favoriteFoods
            case .created:
                return dataStore.customFoods
            case .database:
                return LocalFoodDatabaseService.shared.defaultStaples()
            }
        }
        
        // When searching, prioritize history foods first!
        let histMatches = historyFoods.filter { $0.name.localizedCaseInsensitiveContains(clean) }
        let customMatches = dataStore.customFoods.filter { $0.name.localizedCaseInsensitiveContains(clean) }
        let favMatches = dataStore.favoriteFoods.filter { $0.name.localizedCaseInsensitiveContains(clean) }
        let dbResults = LocalFoodDatabaseService.shared.search(query: clean)
        
        var combined: [FoodItem] = []
        var seen = Set<String>()
        for item in (histMatches + customMatches + favMatches + dbResults) {
            let key = item.name.lowercased().trimmingCharacters(in: .whitespaces)
            if !seen.contains(key) {
                seen.insert(key)
                combined.append(item)
            }
        }
        return combined
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab filter: History, Favorites, My Foods, Database
                Picker("Source", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                
                if let food = selectedFood {
                    Form {
                        Section("Ingredient: \(food.name)") {
                            Picker("Serving Unit", selection: $selectedServing) {
                                ForEach(food.effectiveServingOptions) { option in
                                    Text("\(option.name) (\(Int(option.gramWeight))g)").tag(option)
                                }
                            }
                            
                            Stepper("Quantity: \(quantity.formatted())", value: $quantity, in: 0.1...50.0, step: 0.5)
                        }
                        
                        let nutrients = food.nutrients(for: selectedServing, quantity: quantity)
                        Section("Calculated Nutrition") {
                            HStack {
                                Text("Calories")
                                Spacer()
                                Text("\(Int(nutrients.calories)) kcal").bold()
                            }
                            HStack {
                                Text("Protein")
                                Spacer()
                                Text(String(format: "%.1fg", nutrients.protein)).foregroundColor(.orange)
                            }
                            HStack {
                                Text("Carbs")
                                Spacer()
                                Text(String(format: "%.1fg", nutrients.carbs)).foregroundColor(.blue)
                            }
                            HStack {
                                Text("Fat")
                                Spacer()
                                Text(String(format: "%.1fg", nutrients.fat)).foregroundColor(.purple)
                            }
                        }
                        
                        Button("Add to Recipe") {
                            let ing = RecipeIngredient(
                                id: UUID(),
                                food: food,
                                servingOption: selectedServing,
                                quantity: quantity
                            )
                            onAdd(ing)
                            dismiss()
                        }
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                } else {
                    List {
                        if displayedFoods.isEmpty {
                            VStack(spacing: 8) {
                                Text(selectedTab == .history ? "No past foods found yet" : "No foods found")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text("Foods you've previously logged will automatically appear here")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(displayedFoods) { food in
                                Button(action: {
                                    selectedFood = food
                                    selectedServing = food.defaultServing
                                }) {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 6) {
                                                Text(food.displayName)
                                                    .font(.system(size: 15, weight: .semibold))
                                                    .foregroundColor(.primary)
                                                
                                                if historyFoods.contains(where: { $0.id == food.id || $0.name.lowercased() == food.name.lowercased() }) {
                                                    Text("Past")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .padding(.horizontal, 5)
                                                        .padding(.vertical, 2)
                                                        .background(Color.orange.opacity(0.15))
                                                        .foregroundColor(.orange)
                                                        .cornerRadius(4)
                                                }
                                            }
                                            
                                            let def = food.defaultServing
                                            let cals = Int((food.nutrientsPer100g.calories * def.gramWeight / 100.0).rounded())
                                            Text("\(def.name) • \(cals) kcal • P:\(Int(food.nutrientsPer100g.protein))g C:\(Int(food.nutrientsPer100g.carbs))g F:\(Int(food.nutrientsPer100g.fat))g")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundColor(.orange)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    .searchable(text: $query, prompt: "Search ingredient...")
                }
            }
            .navigationTitle("Select Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
