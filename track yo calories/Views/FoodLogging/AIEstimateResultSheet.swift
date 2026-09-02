//
//  AIEstimateResultSheet.swift
//  track yo calories
//

import SwiftUI

struct AIEstimateResultSheet: View {
    @ObservedObject var dataStore: DataStore
    let initialEstimate: AIFoodEstimate
    var preselectedMeal: MealType = .breakfast
    var targetDate: Date = Date()
    var onLogged: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedMeal: MealType
    @State private var editedFoodName: String
    @State private var portionGrams: Double
    @State private var editedCalories: Double
    @State private var editedProtein: Double
    @State private var editedCarbs: Double
    @State private var editedFat: Double
    
    // Baseline densities for portion scaling
    @State private var baseCalPerGram: Double
    @State private var baseProteinPerGram: Double
    @State private var baseCarbsPerGram: Double
    @State private var baseFatPerGram: Double
    
    @State private var showCalorieEditSheet: Bool = false
    @State private var customCaloriesInput: String = ""
    
    init(
        dataStore: DataStore,
        estimate: AIFoodEstimate,
        preselectedMeal: MealType = .breakfast,
        targetDate: Date = Date(),
        onLogged: (() -> Void)? = nil
    ) {
        self.dataStore = dataStore
        self.initialEstimate = estimate
        self.preselectedMeal = preselectedMeal
        self.targetDate = targetDate
        self.onLogged = onLogged
        
        self._selectedMeal = State(initialValue: preselectedMeal)
        self._editedFoodName = State(initialValue: estimate.foodName)
        let grams = max(10.0, estimate.estimatedGrams)
        self._portionGrams = State(initialValue: grams)
        self._editedCalories = State(initialValue: estimate.calories)
        self._editedProtein = State(initialValue: estimate.protein)
        self._editedCarbs = State(initialValue: estimate.carbs)
        self._editedFat = State(initialValue: estimate.fat)
        
        self._baseCalPerGram = State(initialValue: estimate.calories / grams)
        self._baseProteinPerGram = State(initialValue: estimate.protein / grams)
        self._baseCarbsPerGram = State(initialValue: estimate.carbs / grams)
        self._baseFatPerGram = State(initialValue: estimate.fat / grams)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Meal Picker Pill
                    HStack {
                        Text("Log to")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Picker("Meal", selection: $selectedMeal) {
                            ForEach(MealType.allCases) { meal in
                                Text(meal.displayName).tag(meal)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Food Title (Editable)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Detected Food")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        TextField("Food Name", text: $editedFoodName)
                            .font(.system(size: 18, weight: .bold))
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(14)
                    }
                    .padding(.horizontal)
                    
                    // Main Calorie Card (Tap to scale)
                    VStack(spacing: 10) {
                        Text("Total Calories (Tap to Change)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            customCaloriesInput = "\(Int(editedCalories))"
                            showCalorieEditSheet = true
                        }) {
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text("\(Int(editedCalories))")
                                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                Text("kcal")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        // Quick Stepper Buttons: [-50] [-10] [+10] [+50]
                        HStack(spacing: 10) {
                            quickCalorieButton(delta: -50)
                            quickCalorieButton(delta: -10)
                            quickCalorieButton(delta: 10)
                            quickCalorieButton(delta: 50)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(18)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(20)
                    .padding(.horizontal)
                    
                    // Macro Stepper Columns
                    HStack(spacing: 10) {
                        AITextMacroStepperCard(
                            title: "Protein",
                            amount: $editedProtein,
                            color: .orange,
                            unit: "g",
                            step: 1.0,
                            onChanged: { syncCaloriesFromMacros() }
                        )
                        AITextMacroStepperCard(
                            title: "Carbs",
                            amount: $editedCarbs,
                            color: .blue,
                            unit: "g",
                            step: 1.0,
                            onChanged: { syncCaloriesFromMacros() }
                        )
                        AITextMacroStepperCard(
                            title: "Fat",
                            amount: $editedFat,
                            color: .purple,
                            unit: "g",
                            step: 1.0,
                            onChanged: { syncCaloriesFromMacros() }
                        )
                    }
                    .padding(.horizontal)
                    
                    // Portion Size Stepper
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Portion Weight")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Scales all macros automatically")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Button(action: { applyPortionDelta(-25) }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(.secondary)
                            }
                            
                            Text("\(Int(portionGrams))g")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .frame(minWidth: 50)
                            
                            Button(action: { applyPortionDelta(25) }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 26))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(18)
                    .padding(.horizontal)
                    
                    // Detected Ingredients Breakdown
                    if !initialEstimate.ingredientsDetected.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Detected Ingredients:")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                            
                            ForEach(initialEstimate.ingredientsDetected, id: \.self) { item in
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.green)
                                    Text(item)
                                        .font(.system(size: 14))
                                    Spacer()
                                }
                            }
                        }
                        .padding(16)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(18)
                        .padding(.horizontal)
                    }
                    
                    // Action Button: Log to Meal
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        logMeal()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18, weight: .bold))
                            Text("Log to \(selectedMeal.displayName)")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.orange)
                        .cornerRadius(18)
                        .shadow(color: Color.orange.opacity(0.35), radius: 8, y: 4)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("AI Nutrition Estimate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showCalorieEditSheet) {
                manualCalorieSheet
            }
        }
    }
    
    private func quickCalorieButton(delta: Double) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            applyCalorieDelta(delta)
        }) {
            Text(delta > 0 ? "+\(Int(delta))" : "\(Int(delta))")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(10)
        }
    }
    
    private func applyPortionDelta(_ delta: Double) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let newGrams = max(10.0, portionGrams + delta)
        portionGrams = newGrams
        editedCalories = max(0, (newGrams * baseCalPerGram).rounded())
        editedProtein = max(0, (newGrams * baseProteinPerGram * 10).rounded() / 10)
        editedCarbs = max(0, (newGrams * baseCarbsPerGram * 10).rounded() / 10)
        editedFat = max(0, (newGrams * baseFatPerGram * 10).rounded() / 10)
    }
    
    private func applyCalorieDelta(_ delta: Double) {
        let currentCals = editedCalories
        let newCals = max(0, currentCals + delta)
        scaleAllMacrosToCalories(newCalories: newCals)
    }
    
    private func scaleAllMacrosToCalories(newCalories: Double) {
        guard newCalories >= 0 else { return }
        let currentCals = max(1.0, editedCalories)
        let ratio = newCalories / currentCals
        
        editedCalories = newCalories.rounded()
        editedProtein = max(0, (editedProtein * ratio * 10).rounded() / 10)
        editedCarbs = max(0, (editedCarbs * ratio * 10).rounded() / 10)
        editedFat = max(0, (editedFat * ratio * 10).rounded() / 10)
        
        let newGrams = max(10.0, (portionGrams * ratio).rounded())
        portionGrams = newGrams
    }
    
    private func syncCaloriesFromMacros() {
        editedCalories = max(0, (editedProtein * 4.0 + editedCarbs * 4.0 + editedFat * 9.0).rounded())
    }
    
    private func logMeal() {
        let grams = max(1.0, portionGrams)
        let factor = 100.0 / grams
        
        let nutrients100g = NutrientInfo(
            calories: editedCalories * factor,
            protein: editedProtein * factor,
            carbs: editedCarbs * factor,
            fat: editedFat * factor,
            fiber: initialEstimate.fiber.map { $0 * factor },
            sugar: initialEstimate.sugar.map { $0 * factor },
            sodium: initialEstimate.sodium.map { $0 * factor }
        )
        
        let serving = ServingOption(
            id: UUID(),
            name: "1 portion (\(Int(grams))g)",
            gramWeight: grams,
            isDefault: true
        )
        
        let food = FoodItem(
            id: UUID(),
            barcode: nil,
            name: editedFoodName.trimmingCharacters(in: .whitespaces).isEmpty ? "AI Meal" : editedFoodName,
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
        
        dataStore.logFood(
            food: food,
            mealType: selectedMeal,
            serving: serving,
            quantity: 1.0,
            date: targetDate
        )
        
        onLogged?()
        dismiss()
    }
    
    private var manualCalorieSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Calories", text: $customCaloriesInput)
                        .keyboardType(.numberPad)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                } header: {
                    Text("Exact Total Calories (kcal)")
                } footer: {
                    Text("Protein, carbs, fat, and portion size will automatically scale proportionally with your calories.")
                }
            }
            .navigationTitle("Set Calories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showCalorieEditSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        if let newCals = Double(customCaloriesInput) {
                            scaleAllMacrosToCalories(newCalories: newCals)
                        }
                        showCalorieEditSheet = false
                    }
                }
            }
        }
        .presentationDetents([.height(230)])
    }
}
