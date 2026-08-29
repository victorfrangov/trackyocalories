//
//  FoodDetailView.swift
//  track yo calories
//

import SwiftUI

struct FoodDetailView: View {
    let food: FoodItem
    @ObservedObject var dataStore: DataStore
    
    @State var targetMeal: MealType
    @State var targetDate: Date
    @State var selectedServing: ServingOption
    @State var quantity: Double
    
    var isEditingExisting: Bool = false
    var existingEntryId: UUID? = nil
    var onLogged: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var quantityText: String = "1"
    @State private var calorieInputText: String = ""
    @State private var showCalorieEditModal: Bool = false
    @State private var isEditingCaloriesInline: Bool = false
    
    init(
        food: FoodItem,
        dataStore: DataStore,
        targetMeal: MealType = .breakfast,
        targetDate: Date = Date(),
        initialServing: ServingOption? = nil,
        initialQuantity: Double = 1.0,
        isEditingExisting: Bool = false,
        existingEntryId: UUID? = nil,
        onLogged: (() -> Void)? = nil
    ) {
        self.food = food
        self.dataStore = dataStore
        self._targetMeal = State(initialValue: targetMeal)
        self._targetDate = State(initialValue: targetDate)
        let serving = initialServing ?? food.defaultServing
        self._selectedServing = State(initialValue: serving)
        self._quantity = State(initialValue: initialQuantity)
        self._quantityText = State(initialValue: initialQuantity == floor(initialQuantity) ? "\(Int(initialQuantity))" : String(format: "%.2f", initialQuantity))
        self.isEditingExisting = isEditingExisting
        self.existingEntryId = existingEntryId
        self.onLogged = onLogged
    }
    
    var totalGrams: Double {
        selectedServing.gramWeight * quantity
    }
    
    var currentNutrients: NutrientInfo {
        food.nutrients(for: selectedServing, quantity: quantity)
    }
    
    var isFav: Bool {
        dataStore.isFavorite(food)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Food Header Card
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(food.name)
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                if let brand = food.brand, !brand.isEmpty {
                                    Text(brand)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                withAnimation {
                                    dataStore.toggleFavorite(food)
                                }
                            }) {
                                Image(systemName: isFav ? "star.fill" : "star")
                                    .font(.system(size: 22))
                                    .foregroundColor(isFav ? .yellow : .secondary)
                            }
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(18)
                    .padding(.horizontal)
                    
                    // Interactive Nutrition Card (Tap calories to change & auto-scale macros)
                    VStack(spacing: 16) {
                        // Interactive Calories Header
                        Button(action: { showCalorieEditModal = true }) {
                            HStack(alignment: .center) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("\(Int(currentNutrients.calories))")
                                            .font(.system(size: 40, weight: .bold, design: .rounded))
                                            .foregroundColor(.primary)
                                        
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.system(size: 18))
                                            .foregroundColor(.orange)
                                    }
                                    
                                    Text("CALORIES • TAP TO EDIT")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.orange)
                                        .tracking(1)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(Int(totalGrams)) g")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundColor(.primary)
                                    
                                    Text("portion")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        
                        // Quick Calorie Adjust Stepper Row
                        HStack(spacing: 8) {
                            CalorieQuickButton(label: "-50", delta: -50, onApply: applyCalorieDelta)
                            CalorieQuickButton(label: "-10", delta: -10, onApply: applyCalorieDelta)
                            CalorieQuickButton(label: "+10", delta: 10, onApply: applyCalorieDelta)
                            CalorieQuickButton(label: "+50", delta: 50, onApply: applyCalorieDelta)
                        }
                        
                        Divider()
                        
                        // 3 Macro Badges (Auto-scaling with calories)
                        HStack(spacing: 10) {
                            MacroCard(name: "Protein", grams: currentNutrients.protein, color: .orange)
                            MacroCard(name: "Carbs", grams: currentNutrients.carbs, color: .blue)
                            MacroCard(name: "Fat", grams: currentNutrients.fat, color: .purple)
                        }
                    }
                    .padding(18)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    // Portion & Serving Controls
                    VStack(spacing: 16) {
                        // Serving Size Unit Picker
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Serving Unit")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            Picker("Serving Unit", selection: $selectedServing) {
                                ForEach(food.effectiveServingOptions) { option in
                                    Text("\(option.name) (\(Int(option.gramWeight))g)").tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .onChange(of: selectedServing) { _, _ in
                                syncQuantityText()
                            }
                        }
                        
                        // Number of Servings / Quantity Stepper
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Number of Servings")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 12) {
                                Button(action: { adjustQuantity(by: -0.25) }) {
                                    Image(systemName: "minus")
                                        .font(.system(size: 16, weight: .bold))
                                        .frame(width: 44, height: 44)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                }
                                
                                TextField("Quantity", text: $quantityText)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.center)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .padding(.vertical, 10)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                                    .onChange(of: quantityText) { _, newValue in
                                        if let val = Double(newValue), val > 0 {
                                            quantity = val
                                        }
                                    }
                                
                                Button(action: { adjustQuantity(by: 0.25) }) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .bold))
                                        .frame(width: 44, height: 44)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                }
                            }
                        }
                        
                        // Meal Selector
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Meal")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            Picker("Meal", selection: $targetMeal) {
                                ForEach(MealType.allCases) { meal in
                                    Text(meal.displayName).tag(meal)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .padding(18)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    // Detailed Micronutrients List
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Detailed Micronutrients")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.secondary)
                        
                        NutrientRow(label: "Fiber", value: currentNutrients.fiber.map { String(format: "%.1f g", $0) } ?? "-")
                        NutrientRow(label: "Sugar", value: currentNutrients.sugar.map { String(format: "%.1f g", $0) } ?? "-")
                        NutrientRow(label: "Saturated Fat", value: currentNutrients.saturatedFat.map { String(format: "%.1f g", $0) } ?? "-")
                        NutrientRow(label: "Sodium", value: currentNutrients.sodium.map { "\(Int($0)) mg" } ?? "-")
                        NutrientRow(label: "Potassium", value: currentNutrients.potassium.map { "\(Int($0)) mg" } ?? "-")
                        NutrientRow(label: "Cholesterol", value: currentNutrients.cholesterol.map { "\(Int($0)) mg" } ?? "-")
                    }
                    .padding(18)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    // Action Buttons
                    Button(action: logOrUpdateFood) {
                        Text(isEditingExisting ? "Update Entry (\(Int(currentNutrients.calories)) kcal)" : "Log Food (\(Int(currentNutrients.calories)) kcal)")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.accentColor)
                            .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    
                    if isEditingExisting, let id = existingEntryId {
                        Button(role: .destructive, action: {
                            dataStore.deleteEntry(id: id)
                            dismiss()
                        }) {
                            Text("Delete Entry")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.red)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(isEditingExisting ? "Edit Entry" : "Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showCalorieEditModal) {
                CalorieDirectEditSheet(
                    currentCalories: currentNutrients.calories,
                    onSaveCalories: { targetCals in
                        applyExactCalories(targetCals)
                    }
                )
            }
        }
    }
    
    // MARK: - Auto-scaling Calculations
    private func applyExactCalories(_ targetCalories: Double) {
        let singleServingCalories = food.nutrients(for: selectedServing, quantity: 1.0).calories
        guard singleServingCalories > 0 else { return }
        
        let newQty = max(0.05, targetCalories / singleServingCalories)
        self.quantity = newQty
        syncQuantityText()
    }
    
    private func applyCalorieDelta(_ delta: Double) {
        let targetCalories = max(10, currentNutrients.calories + delta)
        applyExactCalories(targetCalories)
    }
    
    private func adjustQuantity(by delta: Double) {
        let newQ = max(0.25, quantity + delta)
        quantity = newQ
        syncQuantityText()
    }
    
    private func syncQuantityText() {
        quantityText = quantity == floor(quantity) ? "\(Int(quantity))" : String(format: "%.2f", quantity)
    }
    
    private func logOrUpdateFood() {
        if isEditingExisting, let id = existingEntryId {
            dataStore.deleteEntry(id: id)
        }
        
        dataStore.logFood(
            food: food,
            mealType: targetMeal,
            serving: selectedServing,
            quantity: quantity,
            date: targetDate
        )
        
        onLogged?()
        dismiss()
    }
}

// MARK: - Calorie Quick Button
struct CalorieQuickButton: View {
    let label: String
    let delta: Double
    let onApply: (Double) -> Void
    
    var body: some View {
        Button(action: { onApply(delta) }) {
            Text(label)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Color(.systemGray6))
                .cornerRadius(9)
        }
    }
}

// MARK: - Direct Calorie Edit Sheet
struct CalorieDirectEditSheet: View {
    @State var inputCalories: Double
    var onSaveCalories: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    
    init(currentCalories: Double, onSaveCalories: @escaping (Double) -> Void) {
        self._inputCalories = State(initialValue: currentCalories)
        self.onSaveCalories = onSaveCalories
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 6) {
                    Text("Set Target Calories")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    
                    Text("The portion size, protein, carbs, and fat will automatically scale to match.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 16)
                
                HStack(spacing: 8) {
                    TextField("Calories", value: $inputCalories, format: .number)
                        .keyboardType(.numberPad)
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(18)
                    
                    Text("kcal")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
                
                HStack(spacing: 10) {
                    Button("+10") { inputCalories += 10 }
                    Button("+50") { inputCalories += 50 }
                    Button("+100") { inputCalories += 100 }
                    Button("+200") { inputCalories += 200 }
                }
                .font(.system(size: 14, weight: .bold))
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: {
                    onSaveCalories(inputCalories)
                    dismiss()
                }) {
                    Text("Apply & Auto-Scale Macros")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Macro Card Component
struct MacroCard: View {
    let name: String
    let grams: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
            
            Text("\(String(format: "%.1f", grams)) g")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
            
            Capsule()
                .fill(color)
                .frame(height: 3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Nutrient Row Component
struct NutrientRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}
