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
                        TextField("Calories", value: $calories, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .disabled(dietType != .custom)
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
                        Slider(value: $proteinGrams, in: 20...400, step: 5)
                            .tint(.orange)
                            .disabled(dietType != .custom)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Carbohydrates (4 kcal/g)")
                            Spacer()
                            Text("\(Int(carbsGrams))g (\(Int(carbsGrams * 4)) kcal)")
                                .foregroundColor(.blue)
                                .bold()
                        }
                        Slider(value: $carbsGrams, in: 0...500, step: 5)
                            .tint(.blue)
                            .disabled(dietType != .custom)
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Fat (9 kcal/g)")
                            Spacer()
                            Text("\(Int(fatGrams))g (\(Int(fatGrams * 9)) kcal)")
                                .foregroundColor(.purple)
                                .bold()
                        }
                        Slider(value: $fatGrams, in: 10...250, step: 5)
                            .tint(.purple)
                            .disabled(dietType != .custom)
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
                }
            }
            .navigationTitle("Adjust Nutrition Targets")
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
