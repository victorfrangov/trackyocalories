//
//  AIEstimateResultSheet.swift
//  track yo calories
//

import SwiftUI

/// Review screen for an AI estimate: every detected food is its own editable item and
/// is logged as a separate diary entry.
struct AIEstimateResultSheet: View {
    @ObservedObject var dataStore: DataStore
    var targetDate: Date = Date()
    var onLogged: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var selectedMeal: MealType
    @State private var items: [AIFoodItemEstimate]
    @State private var itemPendingRemoval: AIFoodItemEstimate? = nil

    init(
        dataStore: DataStore,
        estimate: AIFoodEstimate,
        preselectedMeal: MealType = .breakfast,
        targetDate: Date = Date(),
        onLogged: (() -> Void)? = nil
    ) {
        self.dataStore = dataStore
        self.targetDate = targetDate
        self.onLogged = onLogged
        self._selectedMeal = State(initialValue: preselectedMeal)

        let initialItems = estimate.items.isEmpty ? [
            AIFoodItemEstimate(
                name: estimate.foodName,
                calories: estimate.calories,
                protein: estimate.protein,
                carbs: estimate.carbs,
                fat: estimate.fat,
                portionDescription: estimate.servingDescription,
                gramWeight: estimate.estimatedGrams
            )
        ] : estimate.items
        // Guard against zero/negative weights from the model, which would break portion scaling.
        self._items = State(initialValue: initialItems.map { item in
            var fixed = item
            if !(fixed.gramWeight > 0) { fixed.gramWeight = 100 }
            return fixed
        })
    }

    private var totalCalories: Double { items.reduce(0) { $0 + $1.calories } }
    private var totalProtein: Double { items.reduce(0) { $0 + $1.protein } }
    private var totalCarbs: Double { items.reduce(0) { $0 + $1.carbs } }
    private var totalFat: Double { items.reduce(0) { $0 + $1.fat } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Meal", selection: $selectedMeal) {
                        ForEach(MealType.allCases) { meal in
                            Text(meal.displayName).tag(meal)
                        }
                    }
                    HStack(spacing: 0) {
                        totalColumn(totalCalories.roundedString, "kcal", .secondary)
                        totalColumn("\(totalProtein.roundedString) g", "Protein", .orange)
                        totalColumn("\(totalCarbs.roundedString) g", "Carbs", .blue)
                        totalColumn("\(totalFat.roundedString) g", "Fat", .purple)
                    }
                    .padding(.vertical, 4)
                } footer: {
                    Text("AI estimates can be off. Check the portion sizes before adding.")
                }

                ForEach($items) { $item in
                    Section {
                        TextField("Food name", text: $item.name)
                            .font(.headline)

                        HStack {
                            Text("Weight")
                            Spacer()
                            DecimalField(title: "g", value: gramsBinding($item), fractionDigits: 0)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 70)
                            Text("g").foregroundStyle(.secondary)
                            Stepper("Weight", value: gramsBinding($item), in: 5...5000, step: 10)
                                .labelsHidden()
                        }

                        numberRow("Calories", unit: "kcal", value: $item.calories)
                        numberRow("Protein", unit: "g", value: $item.protein)
                        numberRow("Carbs", unit: "g", value: $item.carbs)
                        numberRow("Fat", unit: "g", value: $item.fat)

                        if items.count > 1 {
                            Button("Remove Item", role: .destructive) {
                                withAnimation { items.removeAll { $0.id == item.id } }
                            }
                        }
                    } header: {
                        Text(item.portionDescription)
                    }
                }

                Section {
                    Button {
                        withAnimation {
                            items.append(AIFoodItemEstimate(name: "", calories: 0, protein: 0, carbs: 0, fat: 0, portionDescription: "100 g", gramWeight: 100))
                        }
                    } label: {
                        Label("Add Item", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle("Review Estimate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button(action: logItems) {
                    Text(items.count == 1
                         ? "Add to \(selectedMeal.displayName) · \(totalCalories.roundedString) kcal"
                         : "Add \(items.count) Items · \(totalCalories.roundedString) kcal")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(validItems.isEmpty)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(.bar)
            }
        }
    }

    private var validItems: [AIFoodItemEstimate] {
        items.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty && $0.gramWeight > 0 }
    }

    private func totalColumn(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func numberRow(_ title: String, unit: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            DecimalField(title: title, value: value, fractionDigits: 1)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
            Text(unit)
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .leading)
        }
    }

    /// Changing the weight scales calories and macros proportionally and keeps the portion label in sync.
    private func gramsBinding(_ item: Binding<AIFoodItemEstimate>) -> Binding<Double> {
        Binding(
            get: { item.wrappedValue.gramWeight },
            set: { newValue in
                let newGrams = max(1, newValue)
                var updated = item.wrappedValue
                let ratio = newGrams / max(1, updated.gramWeight)
                updated.gramWeight = newGrams
                // No rounding here: typing "150" passes through 1 → 15 → 150, and rounding at
                // each step would lose precision. Values are rounded for display only.
                updated.calories *= ratio
                updated.protein *= ratio
                updated.carbs *= ratio
                updated.fat *= ratio
                updated.portionDescription = "\(Int(newGrams)) g"
                item.wrappedValue = updated
            }
        )
    }

    private func logItems() {
        for item in validItems {
            let food = item.toFoodItem()
            dataStore.logFood(food: food, mealType: selectedMeal, serving: food.defaultServing, quantity: 1, date: targetDate)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onLogged?()
        dismiss()
    }
}
