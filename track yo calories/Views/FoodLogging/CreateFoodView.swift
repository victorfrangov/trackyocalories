//
//  CreateFoodView.swift
//  track yo calories
//

import SwiftUI

struct CreateFoodView: View {
    @ObservedObject var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss
    
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
    @State private var selectedFoodForIngredient: FoodItem? = nil
    
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
            TextField("Serving Description (e.g. 1 cookie, 1 cup, 1 bar)", text: $servingName)
            HStack {
                Text("Serving Weight (grams)")
                Spacer()
                TextField("100", text: $servingGramsText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        }
        
        Section("Nutritional Info (Per Serving)") {
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
                Text("Carbohydrates (g)")
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
        
        Section("Micronutrients (Optional)") {
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
                        VStack(alignment: .leading) {
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
                Label("Add Ingredient", systemImage: "plus.circle.fill")
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
        
        // Scale to 100g base
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
        // Also save its FoodItem representation into customFoods
        dataStore.addCustomFood(recipe.toFoodItem())
        dismiss()
    }
}

struct IngredientPickerSheet: View {
    @ObservedObject var dataStore: DataStore
    var onAdd: (RecipeIngredient) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var query: String = ""
    @State private var selectedFood: FoodItem? = nil
    @State private var selectedServing: ServingOption = ServingOption.grams(100)
    @State private var quantity: Double = 1.0
    
    var filteredFoods: [FoodItem] {
        if query.isEmpty {
            return LocalFoodDatabaseService.shared.defaultStaples() + dataStore.customFoods
        }
        let dbResults = LocalFoodDatabaseService.shared.search(query: query)
        let customMatches = dataStore.customFoods.filter { $0.name.localizedCaseInsensitiveContains(query) }
        return customMatches + dbResults
    }
    
    var body: some View {
        NavigationStack {
            VStack {
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
                                Text("\(Int(nutrients.protein))g").foregroundColor(.orange)
                            }
                            HStack {
                                Text("Carbs")
                                Spacer()
                                Text("\(Int(nutrients.carbs))g").foregroundColor(.blue)
                            }
                            HStack {
                                Text("Fat")
                                Spacer()
                                Text("\(Int(nutrients.fat))g").foregroundColor(.purple)
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
                    }
                } else {
                    List(filteredFoods) { food in
                        Button(action: {
                            selectedFood = food
                            selectedServing = food.defaultServing
                        }) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(food.displayName)
                                    .font(.system(size: 15, weight: .semibold))
                                Text("\(Int(food.nutrientsPer100g.calories)) kcal per 100g • P:\(Int(food.nutrientsPer100g.protein))g C:\(Int(food.nutrientsPer100g.carbs))g F:\(Int(food.nutrientsPer100g.fat))g")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
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
