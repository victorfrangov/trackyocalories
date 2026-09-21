//
//  FoodDetailView.swift
//  track yo calories
//

import SwiftUI

struct FoodDetailView: View {
    let food: FoodItem
    @ObservedObject var dataStore: DataStore

    var isEditingExisting: Bool = false
    var existingEntryId: UUID? = nil
    var onLogged: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var targetMeal: MealType
    @State private var targetDate: Date
    @State private var servingOptions: [ServingOption]
    @State private var selectedServing: ServingOption
    @State private var quantity: Double
    @State private var quantityText: String
    @State private var showCalorieEditor: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @FocusState private var quantityFocused: Bool

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
        self.isEditingExisting = isEditingExisting
        self.existingEntryId = existingEntryId
        self.onLogged = onLogged

        // Build the option list once so picker tags stay stable (effectiveServingOptions
        // creates fresh ids on every call when a food has no stored servings).
        var options = food.effectiveServingOptions
        if let initialServing, !options.contains(initialServing) {
            options.insert(initialServing, at: 0)
        }
        if !options.contains(where: { $0.gramWeight == 1 }) {
            options.append(ServingOption(name: "g", gramWeight: 1, isDefault: false))
        }
        let serving = initialServing ?? options.first(where: { $0.isDefault }) ?? options[0]

        self._targetMeal = State(initialValue: targetMeal)
        self._targetDate = State(initialValue: targetDate)
        self._servingOptions = State(initialValue: options)
        self._selectedServing = State(initialValue: serving)
        self._quantity = State(initialValue: initialQuantity)
        self._quantityText = State(initialValue: initialQuantity.cleanString)
    }

    private var isGramServing: Bool { selectedServing.gramWeight == 1 }
    private var totalGrams: Double { selectedServing.gramWeight * quantity }
    private var nutrients: NutrientInfo { food.nutrients(for: selectedServing, quantity: quantity) }
    private var isValid: Bool { quantity > 0 }

    var body: some View {
        NavigationStack {
            Form {
                headerSection
                amountSection

                Section {
                    Picker("Meal", selection: $targetMeal) {
                        ForEach(MealType.allCases) { meal in
                            Text(meal.displayName).tag(meal)
                        }
                    }
                    DatePicker("Date", selection: $targetDate, displayedComponents: .date)
                }

                nutritionSection

                if isEditingExisting {
                    Section {
                        Button("Delete Entry", role: .destructive) {
                            showDeleteConfirm = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(isEditingExisting ? "Edit Entry" : "Add Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        dataStore.toggleFavorite(food)
                    } label: {
                        Label("Favorite", systemImage: dataStore.isFavorite(food) ? "heart.fill" : "heart")
                    }
                    .tint(.pink)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { quantityFocused = false }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: save) {
                    Text(isEditingExisting
                         ? "Save · \(nutrients.calories.roundedString) kcal"
                         : "Add to \(targetMeal.displayName) · \(nutrients.calories.roundedString) kcal")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isValid)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(.bar)
            }
            .sheet(isPresented: $showCalorieEditor) {
                CalorieDirectEditSheet(currentCalories: nutrients.calories) { target in
                    applyExactCalories(target)
                }
            }
            .confirmationDialog("Delete this entry?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete Entry", role: .destructive) {
                    if let id = existingEntryId { dataStore.deleteEntry(id: id) }
                    dismiss()
                }
            }
        }
    }

    // MARK: - Sections
    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.title3.weight(.semibold))
                if let brand = food.brand, !brand.isEmpty {
                    Text(brand)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)

            HStack(spacing: 0) {
                summaryColumn(value: nutrients.calories.roundedString, label: "kcal", color: .primary)
                summaryColumn(value: nutrients.protein.cleanString(max: 1), label: "Protein", color: .orange)
                summaryColumn(value: nutrients.carbs.cleanString(max: 1), label: "Carbs", color: .blue)
                summaryColumn(value: nutrients.fat.cleanString(max: 1), label: "Fat", color: .purple)
            }
            .padding(.vertical, 4)
        }
    }

    private func summaryColumn(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(color == .primary ? Color.secondary : color)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var amountSection: some View {
        Section {
            Picker("Unit", selection: $selectedServing) {
                ForEach(servingOptions) { option in
                    Text(servingLabel(option)).tag(option)
                }
            }
            .onChange(of: selectedServing) { oldValue, newValue in
                convertQuantity(from: oldValue, to: newValue)
            }

            HStack {
                Text(isGramServing ? "Grams" : "Servings")
                Spacer()
                TextField("Amount", text: $quantityText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(.body.monospacedDigit())
                    .frame(maxWidth: 90)
                    .focused($quantityFocused)
                    .onChange(of: quantityText) { _, newValue in
                        if let value = Double(userInput: newValue), value >= 0 {
                            quantity = value
                        }
                    }
                Stepper("Amount", value: Binding(
                    get: { quantity },
                    set: { newValue in
                        quantity = max(stepSize, newValue)
                        quantityText = quantity.cleanString
                    }
                ), in: 0...10_000, step: stepSize)
                .labelsHidden()
            }

            Button {
                showCalorieEditor = true
            } label: {
                Label("Set Amount by Calories", systemImage: "flame")
            }
        } header: {
            Text("Amount")
        } footer: {
            if !isGramServing {
                Text("Total: \(totalGrams.roundedString) g")
            }
        }
    }

    private var nutritionSection: some View {
        Section("Nutrition for This Amount") {
            NutrientRow(label: "Protein", value: "\(nutrients.protein.cleanString(max: 1)) g")
            NutrientRow(label: "Carbohydrates", value: "\(nutrients.carbs.cleanString(max: 1)) g")
            NutrientRow(label: "Fiber", value: nutrients.fiber.map { "\($0.cleanString(max: 1)) g" } ?? "–", indent: true)
            NutrientRow(label: "Sugar", value: nutrients.sugar.map { "\($0.cleanString(max: 1)) g" } ?? "–", indent: true)
            NutrientRow(label: "Fat", value: "\(nutrients.fat.cleanString(max: 1)) g")
            NutrientRow(label: "Saturated Fat", value: nutrients.saturatedFat.map { "\($0.cleanString(max: 1)) g" } ?? "–", indent: true)
            NutrientRow(label: "Sodium", value: nutrients.sodium.map { "\($0.roundedString) mg" } ?? "–")
            NutrientRow(label: "Potassium", value: nutrients.potassium.map { "\($0.roundedString) mg" } ?? "–")
            NutrientRow(label: "Cholesterol", value: nutrients.cholesterol.map { "\($0.roundedString) mg" } ?? "–")
        }
    }

    // MARK: - Helpers
    private var stepSize: Double {
        if isGramServing { return 10 }
        return selectedServing.gramWeight >= 100 && selectedServing.name.lowercased().contains("100") ? 0.25 : 0.5
    }

    private func servingLabel(_ option: ServingOption) -> String {
        if option.gramWeight == 1 { return "grams" }
        // Avoid "100g (100g)" when the name already states the weight.
        let grams = "\(option.gramWeight.roundedString)g"
        return option.name.replacingOccurrences(of: " ", with: "").contains(grams) ? option.name : "\(option.name) (\(grams))"
    }

    /// Keeps the same total weight when switching units (e.g. 1 × 100 g → 100 grams).
    private func convertQuantity(from old: ServingOption, to new: ServingOption) {
        guard old.gramWeight > 0, new.gramWeight > 0, old != new else { return }
        let grams = old.gramWeight * quantity
        var converted = grams / new.gramWeight
        converted = new.gramWeight == 1 ? converted.rounded() : (converted * 4).rounded() / 4
        quantity = max(new.gramWeight == 1 ? 1 : 0.25, converted)
        quantityText = quantity.cleanString
    }

    private func applyExactCalories(_ targetCalories: Double) {
        let perServing = food.nutrients(for: selectedServing, quantity: 1).calories
        guard perServing > 0, targetCalories > 0 else { return }
        quantity = targetCalories / perServing
        quantityText = quantity.cleanString
    }

    private func save() {
        guard isValid else { return }
        if isEditingExisting, let id = existingEntryId {
            dataStore.updateEntry(id: id, mealType: targetMeal, serving: selectedServing, quantity: quantity, date: targetDate)
        } else {
            dataStore.logFood(food: food, mealType: targetMeal, serving: selectedServing, quantity: quantity, date: targetDate)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onLogged?()
        dismiss()
    }
}

// MARK: - Set-by-calories Sheet
struct CalorieDirectEditSheet: View {
    var onSave: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var caloriesText: String
    @FocusState private var focused: Bool

    init(currentCalories: Double, onSaveCalories: @escaping (Double) -> Void) {
        self._caloriesText = State(initialValue: String(Int(currentCalories.rounded())))
        self.onSave = onSaveCalories
    }

    private var value: Double? {
        guard let v = Double(userInput: caloriesText), v > 0 else { return nil }
        return v
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Calories", text: $caloriesText)
                            .keyboardType(.numberPad)
                            .font(.title2.weight(.semibold).monospacedDigit())
                            .focused($focused)
                        Text("kcal").foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("The amount is adjusted so this portion has the calories you enter.")
                }
            }
            .navigationTitle("Set by Calories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        if let value { onSave(value) }
                        dismiss()
                    }
                    .disabled(value == nil)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.height(240)])
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
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(grams.roundedString) g")
                .font(.headline.monospacedDigit())
            Capsule()
                .fill(color)
                .frame(height: 3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Nutrient Row Component
struct NutrientRow: View {
    let label: String
    let value: String
    var indent: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(indent ? .secondary : .primary)
                .padding(.leading, indent ? 16 : 0)
            Spacer()
            Text(value)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
