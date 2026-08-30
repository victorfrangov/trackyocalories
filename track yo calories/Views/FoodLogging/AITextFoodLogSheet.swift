//
//  AITextFoodLogSheet.swift
//  track yo calories
//

import SwiftUI

struct AITextFoodLogSheet: View {
    @ObservedObject var dataStore: DataStore
    var preselectedMeal: MealType = .breakfast
    var targetDate: Date = Date()
    var initialText: String = ""
    var onLogged: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var mealDescription: String = ""
    @State private var selectedMeal: MealType = .breakfast
    @State private var isAnalyzing: Bool = false
    @State private var errorMessage: String? = nil
    @State private var aiEstimate: AIFoodEstimate? = nil
    @State private var showApiKeySheet: Bool = false
    
    // Fine-Tuning State
    @State private var editedFoodName: String = ""
    @State private var portionGrams: Double = 100.0
    @State private var editedCalories: Double = 0.0
    @State private var editedProtein: Double = 0.0
    @State private var editedCarbs: Double = 0.0
    @State private var editedFat: Double = 0.0
    @State private var showCalorieEditSheet: Bool = false
    @State private var customCaloriesInput: String = ""
    
    // Baseline densities for portion scaling
    @State private var baseCalPerGram: Double = 1.0
    @State private var baseProteinPerGram: Double = 0.1
    @State private var baseCarbsPerGram: Double = 0.1
    @State private var baseFatPerGram: Double = 0.05
    
    init(dataStore: DataStore, preselectedMeal: MealType = .breakfast, targetDate: Date = Date(), initialText: String = "", onLogged: (() -> Void)? = nil) {
        self.dataStore = dataStore
        self.preselectedMeal = preselectedMeal
        self.targetDate = targetDate
        self.initialText = initialText
        self.onLogged = onLogged
        self._selectedMeal = State(initialValue: preselectedMeal)
        self._mealDescription = State(initialValue: initialText)
    }
    
    var apiKey: String? {
        dataStore.userProfile.geminiApiKey
    }
    
    private let exampleSuggestions = [
        "2 scrambled eggs, 1 toast with butter, and a black coffee",
        "Chipotle chicken bowl with white rice, black beans, and salsa",
        "Whey protein shake with 1 banana and 2 tbsp peanut butter",
        "Grilled salmon fillet (150g) with jasmine rice and broccoli",
        "Double cheeseburger and medium french fries"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if aiEstimate == nil && !isAnalyzing {
                        inputSection
                    } else if isAnalyzing {
                        analyzingSection
                    } else if aiEstimate != nil {
                        fineTuningSection
                    }
                    
                    if let error = errorMessage {
                        errorSection(error: error)
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(aiEstimate == nil ? "AI Meal Estimator" : "AI Nutrition Estimate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showApiKeySheet = true }) {
                        Image(systemName: apiKey?.isEmpty == false ? "key.fill" : "key")
                            .foregroundColor(apiKey?.isEmpty == false ? .green : .orange)
                    }
                }
            }
            .sheet(isPresented: $showApiKeySheet) {
                ApiKeySetupSheet(dataStore: dataStore) {
                    if !mealDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        estimateMeal()
                    }
                }
            }
            .sheet(isPresented: $showCalorieEditSheet) {
                manualCalorieSheet
            }
            .onAppear {
                if !initialText.isEmpty && aiEstimate == nil {
                    estimateMeal()
                }
            }
        }
    }
    
    // MARK: - Input Section
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 18) {
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
            }
            .padding(.horizontal)
            
            // Big Description Input Box
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.orange)
                        .font(.system(size: 16, weight: .bold))
                    Text("Describe What You Ate")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                
                ZStack(alignment: .topLeading) {
                    if mealDescription.isEmpty {
                        Text("Type anything you ate (e.g. '2 fried eggs on sourdough with avocado, and an iced oat latte')...")
                            .font(.system(size: 15))
                            .foregroundColor(Color(.placeholderText))
                            .padding(.top, 8)
                            .padding(.leading, 5)
                    }
                    
                    TextEditor(text: $mealDescription)
                        .font(.system(size: 15))
                        .frame(minHeight: 120)
                        .scrollContentBackground(.hidden)
                }
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)
            }
            .padding(.horizontal)
            
            // Example Suggestions Carousel
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Examples:")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(exampleSuggestions, id: \.self) { example in
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                mealDescription = example
                            }) {
                                Text(example)
                                    .font(.system(size: 13))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // Action Button: Estimate with AI
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                estimateMeal()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                    Text("Estimate Calories & Macros with AI")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    mealDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? Color.orange.opacity(0.4)
                    : Color.orange
                )
                .cornerRadius(18)
                .shadow(color: Color.orange.opacity(0.3), radius: 8, y: 4)
            }
            .disabled(mealDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.horizontal)
            .padding(.top, 6)
            
            // Free Gemini API Key notice if missing
            if apiKey == nil || apiKey?.isEmpty == true {
                Button(action: { showApiKeySheet = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "key.fill")
                        Text("Set up free Google Gemini API Key")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Analyzing Section
    private var analyzingSection: some View {
        VStack(spacing: 18) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.orange)
                .padding(.top, 40)
            
            Text("Analyzing your meal description...")
                .font(.system(size: 18, weight: .bold, design: .rounded))
            
            Text("\"\(mealDescription)\"")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Text("Estimating portions, ingredients & macronutrients with Gemini AI")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Fine-Tuning Section
    private var fineTuningSection: some View {
        VStack(spacing: 16) {
            // Meal Title (Editable)
            VStack(alignment: .leading, spacing: 6) {
                Text("Detected Meal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                
                TextField("Meal Name", text: $editedFoodName)
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
            
            // Macro Fine-Tuning Columns
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
            if let items = aiEstimate?.ingredientsDetected, !items.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Detected Ingredients:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    
                    ForEach(items, id: \.self) { item in
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
            
            // Action Buttons: Log Food or Try Again
            VStack(spacing: 10) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    logEstimatedMeal()
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
                
                Button(action: {
                    withAnimation {
                        aiEstimate = nil
                    }
                }) {
                    Text("Edit Description & Re-estimate")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 6)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
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
    
    // MARK: - Logic
    private func estimateMeal() {
        let trimmed = mealDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        guard let key = apiKey, !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showApiKeySheet = true
            return
        }
        
        isAnalyzing = true
        errorMessage = nil
        aiEstimate = nil
        
        Task {
            do {
                let estimate = try await AIFoodScannerService.shared.analyzeFoodDescription(text: trimmed, apiKey: key)
                await MainActor.run {
                    self.aiEstimate = estimate
                    self.editedFoodName = estimate.foodName
                    let grams = max(10.0, estimate.estimatedGrams)
                    self.portionGrams = grams
                    self.editedCalories = estimate.calories
                    self.editedProtein = estimate.protein
                    self.editedCarbs = estimate.carbs
                    self.editedFat = estimate.fat
                    
                    self.baseCalPerGram = estimate.calories / grams
                    self.baseProteinPerGram = estimate.protein / grams
                    self.baseCarbsPerGram = estimate.carbs / grams
                    self.baseFatPerGram = estimate.fat / grams
                    
                    self.isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isAnalyzing = false
                }
            }
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
    
    private func logEstimatedMeal() {
        let grams = max(1.0, portionGrams)
        let factor = 100.0 / grams
        
        let nutrients100g = NutrientInfo(
            calories: editedCalories * factor,
            protein: editedProtein * factor,
            carbs: editedCarbs * factor,
            fat: editedFat * factor,
            fiber: aiEstimate?.fiber.map { $0 * factor },
            sugar: aiEstimate?.sugar.map { $0 * factor },
            sodium: aiEstimate?.sodium.map { $0 * factor }
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
    
    // MARK: - Error Section
    private func errorSection(error: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundColor(.red)
            
            Text("Estimation Failed")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.red)
            
            Text(error)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if error.contains("API key") {
                Button("Configure Free Gemini Key") {
                    showApiKeySheet = true
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.orange)
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    // MARK: - Manual Calorie Edit Sheet
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

// MARK: - Macro Stepper Card
struct AITextMacroStepperCard: View {
    let title: String
    @Binding var amount: Double
    let color: Color
    let unit: String
    let step: Double
    var onChanged: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
            
            Text("\(String(format: "%.1f", amount))\(unit)")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)
            
            HStack(spacing: 8) {
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    amount = max(0, amount - step)
                    onChanged?()
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Circle())
                }
                
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    amount += step
                    onChanged?()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(color)
                        .frame(width: 28, height: 28)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Circle())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}
