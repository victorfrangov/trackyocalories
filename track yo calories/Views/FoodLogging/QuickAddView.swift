//
//  QuickAddView.swift
//  track yo calories
//

import SwiftUI

struct QuickAddView: View {
    @ObservedObject var dataStore: DataStore
    var targetDate: Date

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var caloriesText: String = ""
    @State private var proteinText: String = ""
    @State private var carbsText: String = ""
    @State private var fatText: String = ""
    @State private var selectedMeal: MealType
    @FocusState private var focusedField: Field?

    enum Field { case calories, protein, carbs, fat, name }

    init(dataStore: DataStore, preselectedMeal: MealType = .breakfast, targetDate: Date = Date()) {
        self.dataStore = dataStore
        self.targetDate = targetDate
        self._selectedMeal = State(initialValue: preselectedMeal)
    }

    private var protein: Double { Double(userInput: proteinText) ?? 0 }
    private var carbs: Double { Double(userInput: carbsText) ?? 0 }
    private var fat: Double { Double(userInput: fatText) ?? 0 }
    private var macroCalories: Double { protein * 4 + carbs * 4 + fat * 9 }

    /// Typed calories win; otherwise calories are derived from the macros.
    private var calories: Double {
        if let typed = Double(userInput: caloriesText), typed > 0 { return typed }
        return macroCalories
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    numberRow("Calories", unit: "kcal", text: $caloriesText, field: .calories,
                              placeholder: macroCalories > 0 ? macroCalories.roundedString : "0")
                } footer: {
                    if caloriesText.isEmpty && macroCalories > 0 {
                        Text("Calculated from macros: \(macroCalories.roundedString) kcal")
                    }
                }

                Section("Macros (optional)") {
                    numberRow("Protein", unit: "g", text: $proteinText, field: .protein)
                    numberRow("Carbs", unit: "g", text: $carbsText, field: .carbs)
                    numberRow("Fat", unit: "g", text: $fatText, field: .fat)
                }

                Section {
                    TextField("Name (optional)", text: $name)
                        .focused($focusedField, equals: .name)
                    Picker("Meal", selection: $selectedMeal) {
                        ForEach(MealType.allCases) { meal in
                            Text(meal.displayName).tag(meal)
                        }
                    }
                }
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
                        .disabled(calories <= 0)
                }
            }
            .onAppear { focusedField = .calories }
        }
    }

    private func numberRow(_ title: String, unit: String, text: Binding<String>, field: Field, placeholder: String = "0") -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField(placeholder, text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .focused($focusedField, equals: field)
                .frame(maxWidth: 120)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        // Stored "per 100 g" with a single 100 g serving, so one serving equals exactly what was typed.
        let food = FoodItem(
            name: trimmed.isEmpty ? "Quick Add" : trimmed,
            brand: nil,
            category: "Quick Add",
            nutrientsPer100g: NutrientInfo(calories: calories, protein: protein, carbs: carbs, fat: fat),
            servingOptions: [ServingOption(name: "1 serving", gramWeight: 100, isDefault: true)],
            isCustom: true,
            isVerified: false
        )
        dataStore.logFood(food: food, mealType: selectedMeal, serving: food.defaultServing, quantity: 1, date: targetDate, remember: false)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}
