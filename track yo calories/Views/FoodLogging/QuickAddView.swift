//
//  QuickAddView.swift
//  track yo calories
//

import SwiftUI

struct QuickAddView: View {
    @ObservedObject var dataStore: DataStore
    var preselectedMeal: MealType
    var targetDate: Date
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var caloriesText: String = ""
    @State private var proteinText: String = ""
    @State private var carbsText: String = ""
    @State private var fatText: String = ""
    @State private var selectedMeal: MealType
    
    init(dataStore: DataStore, preselectedMeal: MealType = .breakfast, targetDate: Date = Date()) {
        self.dataStore = dataStore
        self.preselectedMeal = preselectedMeal
        self.targetDate = targetDate
        self._selectedMeal = State(initialValue: preselectedMeal)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Quick Add", text: $name)
                    
                    Picker("Meal", selection: $selectedMeal) {
                        ForEach(MealType.allCases) { meal in
                            Text(meal.displayName).tag(meal)
                        }
                    }
                }
                
                Section("Calories & Macros") {
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
            }
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        saveQuickAdd()
                    }
                    .disabled(caloriesText.isEmpty && proteinText.isEmpty && carbsText.isEmpty && fatText.isEmpty)
                }
            }
        }
    }
    
    private func saveQuickAdd() {
        let cal = Double(caloriesText) ?? 0
        let pro = Double(proteinText) ?? 0
        let carb = Double(carbsText) ?? 0
        let fat = Double(fatText) ?? 0
        
        let calculatedCals = cal > 0 ? cal : (pro * 4 + carb * 4 + fat * 9)
        let foodName = name.trimmingCharacters(in: .whitespaces).isEmpty ? "Quick Add" : name
        
        let quickFood = FoodItem(
            id: UUID(),
            barcode: nil,
            name: foodName,
            brand: "Quick Entry",
            category: "Manual",
            nutrientsPer100g: NutrientInfo(
                calories: calculatedCals,
                protein: pro,
                carbs: carb,
                fat: fat
            ),
            servingOptions: [
                ServingOption(id: UUID(), name: "1 serving", gramWeight: 100.0, isDefault: true)
            ],
            isCustom: true,
            isVerified: true
        )
        
        dataStore.logFood(
            food: quickFood,
            mealType: selectedMeal,
            serving: quickFood.defaultServing,
            quantity: 1.0,
            date: targetDate
        )
        
        dismiss()
    }
}
