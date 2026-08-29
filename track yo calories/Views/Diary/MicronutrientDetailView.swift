//
//  MicronutrientDetailView.swift
//  track yo calories
//

import SwiftUI

struct MicronutrientDetailView: View {
    @ObservedObject var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss
    
    var entries: [LoggedEntry] {
        dataStore.entries(for: dataStore.selectedDate)
    }
    
    var totalFiber: Double { dataStore.totalFiber(for: dataStore.selectedDate) }
    var totalSugar: Double { dataStore.totalSugar(for: dataStore.selectedDate) }
    var totalSodium: Double { dataStore.totalSodium(for: dataStore.selectedDate) }
    
    var totalSatFat: Double {
        entries.reduce(0.0) { sum, entry in
            sum + (entry.food.nutrientsPer100g.saturatedFat.map { $0 * (entry.totalGrams / 100.0) } ?? 0.0)
        }
    }
    var totalPotassium: Double {
        entries.reduce(0.0) { sum, entry in
            sum + (entry.food.nutrientsPer100g.potassium.map { $0 * (entry.totalGrams / 100.0) } ?? 0.0)
        }
    }
    var totalCholesterol: Double {
        entries.reduce(0.0) { sum, entry in
            sum + (entry.food.nutrientsPer100g.cholesterol.map { $0 * (entry.totalGrams / 100.0) } ?? 0.0)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section("Macronutrient Summary") {
                    HStack {
                        Text("Total Calories")
                        Spacer()
                        Text("\(Int(dataStore.totalCalories(for: dataStore.selectedDate))) kcal")
                            .bold()
                    }
                    HStack {
                        Text("Protein")
                        Spacer()
                        Text("\(Int(dataStore.totalProtein(for: dataStore.selectedDate))) g")
                            .foregroundColor(.orange)
                            .bold()
                    }
                    HStack {
                        Text("Carbohydrates")
                        Spacer()
                        Text("\(Int(dataStore.totalCarbs(for: dataStore.selectedDate))) g")
                            .foregroundColor(.blue)
                            .bold()
                    }
                    HStack {
                        Text("Fat")
                        Spacer()
                        Text("\(Int(dataStore.totalFat(for: dataStore.selectedDate))) g")
                            .foregroundColor(.purple)
                            .bold()
                    }
                }
                
                Section("Key Micronutrients & Guidelines") {
                    MicroNutrientRow(
                        name: "Dietary Fiber",
                        value: "\(String(format: "%.1f", totalFiber)) g",
                        guide: "Target: ≥ 28g / day",
                        status: totalFiber >= 25 ? .good : .neutral
                    )
                    
                    MicroNutrientRow(
                        name: "Sugars",
                        value: "\(String(format: "%.1f", totalSugar)) g",
                        guide: "Recommended: < 50g / day",
                        status: totalSugar > 60 ? .warning : .good
                    )
                    
                    MicroNutrientRow(
                        name: "Saturated Fat",
                        value: "\(String(format: "%.1f", totalSatFat)) g",
                        guide: "Recommended: < 20g / day",
                        status: totalSatFat > 25 ? .warning : .good
                    )
                    
                    MicroNutrientRow(
                        name: "Sodium",
                        value: "\(Int(totalSodium)) mg",
                        guide: "Recommended: < 2300 mg / day",
                        status: totalSodium > 2500 ? .warning : .good
                    )
                    
                    MicroNutrientRow(
                        name: "Potassium",
                        value: "\(Int(totalPotassium)) mg",
                        guide: "Recommended: ~3400 mg / day",
                        status: .neutral
                    )
                    
                    MicroNutrientRow(
                        name: "Cholesterol",
                        value: "\(Int(totalCholesterol)) mg",
                        guide: "Recommended: < 300 mg / day",
                        status: totalCholesterol > 350 ? .warning : .good
                    )
                }
            }
            .navigationTitle("Detailed Nutrition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

enum MicroStatus {
    case good, warning, neutral
    
    var color: Color {
        switch self {
        case .good: return .green
        case .warning: return .orange
        case .neutral: return .secondary
        }
    }
}

struct MicroNutrientRow: View {
    let name: String
    let value: String
    let guide: String
    let status: MicroStatus
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.system(size: 15, weight: .medium))
                Spacer()
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            Text(guide)
                .font(.system(size: 12))
                .foregroundColor(status.color)
        }
        .padding(.vertical, 4)
    }
}
