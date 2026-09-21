//
//  MacroEditorView.swift
//  track yo calories
//

import SwiftUI

struct MacroEditorView: View {
    @ObservedObject var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var dietType: DietType
    @State private var calories: Double
    @State private var proteinGrams: Double
    @State private var carbsGrams: Double
    @State private var fatGrams: Double
    
    init(dataStore: DataStore) {
        self.dataStore = dataStore
        let p = dataStore.userProfile
        let currentTargets = NutritionEngine.calculateMacroTargets(profile: p)
        self._dietType = State(initialValue: p.dietType)
        self._calories = State(initialValue: currentTargets.calories)
        self._proteinGrams = State(initialValue: currentTargets.proteinGrams)
        self._carbsGrams = State(initialValue: currentTargets.carbsGrams)
        self._fatGrams = State(initialValue: currentTargets.fatGrams)
    }
    
    var calculatedTotalCaloriesFromMacros: Double {
        proteinGrams * 4 + carbsGrams * 4 + fatGrams * 9
    }

    /// Editing any value switches to the Custom preset instead of requiring the user to pick it first.
    private func customBinding(_ value: Binding<Double>) -> Binding<Double> {
        Binding(
            get: { value.wrappedValue },
            set: { newValue in
                guard newValue != value.wrappedValue else { return }
                value.wrappedValue = newValue
                if dietType != .custom { dietType = .custom }
            }
        )
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Diet Protocol Preset") {
                    Picker("Preset", selection: $dietType) {
                        ForEach(DietType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: dietType) { _, newType in
                        if newType != .custom {
                            var temp = dataStore.userProfile
                            temp.dietType = newType
                            let calculated = NutritionEngine.calculateMacroTargets(profile: temp)
                            calories = calculated.calories
                            proteinGrams = calculated.proteinGrams
                            carbsGrams = calculated.carbsGrams
                            fatGrams = calculated.fatGrams
                        }
                    }
                    
                    Text(dietType.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Section("Daily Target Calories") {
                    HStack {
                        Text("Calories (kcal)")
                        Spacer()
                        DecimalField(title: "Calories", value: customBinding($calories), fractionDigits: 0)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section("Macronutrient Targets (Grams)") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Protein (4 kcal/g)")
                            Spacer()
                            Text("\(Int(proteinGrams))g (\(Int(proteinGrams * 4)) kcal)")
                                .foregroundColor(.orange)
                                .bold()
                        }
                        Slider(value: customBinding($proteinGrams), in: 20...400, step: 5)
                            .tint(.orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Carbohydrates (4 kcal/g)")
                            Spacer()
                            Text("\(Int(carbsGrams))g (\(Int(carbsGrams * 4)) kcal)")
                                .foregroundColor(.blue)
                                .bold()
                        }
                        Slider(value: customBinding($carbsGrams), in: 0...500, step: 5)
                            .tint(.blue)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Fat (9 kcal/g)")
                            Spacer()
                            Text("\(Int(fatGrams))g (\(Int(fatGrams * 9)) kcal)")
                                .foregroundColor(.purple)
                                .bold()
                        }
                        Slider(value: customBinding($fatGrams), in: 10...250, step: 5)
                            .tint(.purple)
                    }
                }
                
                Section("Macro Breakdown Summary") {
                    let total = max(1.0, calculatedTotalCaloriesFromMacros)
                    let pPct = (proteinGrams * 4 / total) * 100
                    let cPct = (carbsGrams * 4 / total) * 100
                    let fPct = (fatGrams * 9 / total) * 100
                    
                    HStack {
                        Text("Macro Distribution")
                        Spacer()
                        Text("P: \(Int(pPct))% • C: \(Int(cPct))% • F: \(Int(fPct))%")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Total Energy from Macros")
                        Spacer()
                        Text("\(Int(calculatedTotalCaloriesFromMacros)) kcal")
                            .bold()
                    }

                    if abs(calculatedTotalCaloriesFromMacros - calories) >= 25 {
                        Button("Set Calorie Target to \(Int(calculatedTotalCaloriesFromMacros)) kcal") {
                            customBinding($calories).wrappedValue = calculatedTotalCaloriesFromMacros.rounded()
                        }
                    }
                }
            }
            .navigationTitle("Calories & Macros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTargets()
                    }
                }
            }
        }
    }
    
    private func saveTargets() {
        dataStore.userProfile.dietType = dietType
        if dietType == .custom {
            dataStore.userProfile.customCalories = calories
            dataStore.userProfile.customProteinGrams = proteinGrams
            dataStore.userProfile.customCarbsGrams = carbsGrams
            dataStore.userProfile.customFatGrams = fatGrams
        } else {
            dataStore.userProfile.customCalories = nil
            dataStore.userProfile.customProteinGrams = nil
            dataStore.userProfile.customCarbsGrams = nil
            dataStore.userProfile.customFatGrams = nil
        }
        dismiss()
    }
}
