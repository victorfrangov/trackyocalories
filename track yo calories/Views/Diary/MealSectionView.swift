//
//  MealSectionView.swift
//  track yo calories
//

import SwiftUI

struct MealSectionView: View {
    let mealType: MealType
    let budgetCalories: Double
    @ObservedObject var dataStore: DataStore
    var onAddFood: (MealType) -> Void
    var onScanBarcode: (MealType) -> Void
    var onEditEntry: (LoggedEntry) -> Void
    
    var entries: [LoggedEntry] {
        dataStore.entries(for: dataStore.selectedDate, meal: mealType)
    }
    
    var consumedCalories: Double {
        entries.reduce(0.0) { $0 + $1.calories }
    }
    
    var consumedProtein: Double {
        entries.reduce(0.0) { $0 + $1.protein }
    }
    
    var consumedCarbs: Double {
        entries.reduce(0.0) { $0 + $1.carbs }
    }
    
    var consumedFat: Double {
        entries.reduce(0.0) { $0 + $1.fat }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Meal Header: "Breakfast" + "🔥 0 kcal • 0 P | 0 C | 0 F"
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mealType.displayName)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                        
                        Text("\(Int(consumedCalories)) kcal")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        Text("\(Int(consumedProtein)) P | \(Int(consumedCarbs)) C | \(Int(consumedFat)) F")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Meal menu
                Menu {
                    Button(action: { duplicateFromYesterday() }) {
                        Label("Copy from Yesterday", systemImage: "doc.on.doc")
                    }
                    
                    if !entries.isEmpty {
                        Button(role: .destructive, action: { clearMeal() }) {
                            Label("Clear \(mealType.displayName)", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 32, height: 32)
                }
            }
            
            // Logged Food Items List
            if !entries.isEmpty {
                VStack(spacing: 8) {
                    ForEach(entries) { entry in
                        FoodEntryRow(entry: entry, onEdit: { onEditEntry(entry) }, onDelete: {
                            withAnimation {
                                dataStore.deleteEntry(id: entry.id)
                            }
                        })
                    }
                }
            }
            
            // Fitia Large "+" Add Food Button
            Button(action: { onAddFood(mealType) }) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .cornerRadius(16)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(24)
    }
    
    private func duplicateFromYesterday() {
        if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: dataStore.selectedDate) {
            withAnimation {
                dataStore.duplicateMeal(mealType: mealType, from: yesterday, to: dataStore.selectedDate)
            }
        }
    }
    
    private func clearMeal() {
        withAnimation {
            dataStore.clearMeal(mealType: mealType, on: dataStore.selectedDate)
        }
    }
}

// MARK: - Food Item Row
struct FoodEntryRow: View {
    let entry: LoggedEntry
    var onEdit: () -> Void
    var onDelete: () -> Void
    
    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.food.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(entry.portionDescription)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(entry.calories)) kcal")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("P: \(Int(entry.protein))g • C: \(Int(entry.carbs))g • F: \(Int(entry.fat))g")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit Portion", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
