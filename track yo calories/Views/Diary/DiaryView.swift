//
//  DiaryView.swift
//  track yo calories
//

import SwiftUI

struct DiaryView: View {
    @ObservedObject var dataStore: DataStore
    
    @State private var showSearchSheet: Bool = false
    @State private var showScannerSheet: Bool = false
    @State private var showAIScannerSheet: Bool = false
    @State private var showQuickAddSheet: Bool = false
    @State private var showMicronutrientsSheet: Bool = false
    @State private var showMacroEditor: Bool = false
    @State private var showEndDaySheet: Bool = false
    @State private var selectedMealForAdd: MealType = .breakfast
    @State private var editingEntry: LoggedEntry? = nil
    
    var macroTargets: MacroTargets {
        NutritionEngine.calculateMacroTargets(profile: dataStore.userProfile)
    }
    
    var mealBudgets: [MealBudget] {
        NutritionEngine.calculateMealBudgets(profile: dataStore.userProfile)
    }
    
    var totalConsumedCalories: Double {
        dataStore.totalCalories(for: dataStore.selectedDate)
    }
    
    var totalConsumedProtein: Double {
        dataStore.totalProtein(for: dataStore.selectedDate)
    }
    
    var totalConsumedCarbs: Double {
        dataStore.totalCarbs(for: dataStore.selectedDate)
    }
    
    var totalConsumedFat: Double {
        dataStore.totalFat(for: dataStore.selectedDate)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Top Fitia Header + Weekday Strip
                    DateHeaderView(selectedDate: $dataStore.selectedDate, dataStore: dataStore)
                        .padding(.top, 4)
                    
                    // Main Fitia Calorie & Macro Card
                    FitiaCalorieCardView(
                        budgetCalories: macroTargets.calories,
                        consumedCalories: totalConsumedCalories,
                        weeklyAverageCalories: dataStore.weeklyAverageCalories(for: dataStore.selectedDate),
                        proteinConsumed: totalConsumedProtein,
                        proteinTarget: macroTargets.proteinGrams,
                        carbsConsumed: totalConsumedCarbs,
                        carbsTarget: macroTargets.carbsGrams,
                        fatConsumed: totalConsumedFat,
                        fatTarget: macroTargets.fatGrams,
                        onMoreOptions: { showMicronutrientsSheet = true }
                    )
                    .padding(.horizontal)
                    
                    // Water Tracker Card
                    WaterTrackerView(dataStore: dataStore)
                        .padding(.horizontal)
                    
                    // Meals Breakdown (Breakfast, Lunch, Dinner, Snacks)
                    VStack(spacing: 16) {
                        ForEach(MealType.allCases) { meal in
                            let budget = mealBudgets.first(where: { $0.mealType == meal })?.calories ?? 500.0
                            MealSectionView(
                                mealType: meal,
                                budgetCalories: budget,
                                dataStore: dataStore,
                                onAddFood: { targetMeal in
                                    selectedMealForAdd = targetMeal
                                    showSearchSheet = true
                                },
                                onScanBarcode: { targetMeal in
                                    selectedMealForAdd = targetMeal
                                    showScannerSheet = true
                                },
                                onEditEntry: { entry in
                                    editingEntry = entry
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showQuickAddSheet = true }) {
                        Image(systemName: "plus.forwardslash.minus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.orange)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: {
                            selectedMealForAdd = .lunch
                            showAIScannerSheet = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 13, weight: .bold))
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.orange.opacity(0.15))
                            .cornerRadius(12)
                        }
                        
                        Button(action: {
                            selectedMealForAdd = .breakfast
                            showScannerSheet = true
                        }) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .sheet(isPresented: $showSearchSheet) {
                FoodSearchView(
                    dataStore: dataStore,
                    preselectedMeal: selectedMealForAdd,
                    targetDate: dataStore.selectedDate
                )
            }
            .sheet(isPresented: $showScannerSheet) {
                BarcodeScannerView(
                    dataStore: dataStore,
                    targetMeal: selectedMealForAdd,
                    targetDate: dataStore.selectedDate
                )
            }
            .sheet(isPresented: $showAIScannerSheet) {
                AIFoodScannerView(
                    dataStore: dataStore,
                    targetMeal: selectedMealForAdd,
                    targetDate: dataStore.selectedDate
                )
            }
            .sheet(isPresented: $showQuickAddSheet) {
                QuickAddView(
                    dataStore: dataStore,
                    preselectedMeal: selectedMealForAdd,
                    targetDate: dataStore.selectedDate
                )
            }
            .sheet(isPresented: $showMicronutrientsSheet) {
                MicronutrientDetailView(dataStore: dataStore)
            }
            .sheet(isPresented: $showMacroEditor) {
                MacroEditorView(dataStore: dataStore)
            }
            .sheet(isPresented: $showEndDaySheet) {
                EndDaySummarySheet(dataStore: dataStore)
            }
            .sheet(item: $editingEntry) { entry in
                FoodDetailView(
                    food: entry.food,
                    dataStore: dataStore,
                    targetMeal: entry.mealType,
                    targetDate: entry.date,
                    initialServing: entry.servingOption,
                    initialQuantity: entry.quantity,
                    isEditingExisting: true,
                    existingEntryId: entry.id
                )
            }
        }
    }
}

// MARK: - End Day Summary Sheet
struct EndDaySummarySheet: View {
    @ObservedObject var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss
    
    var macroTargets: MacroTargets {
        NutritionEngine.calculateMacroTargets(profile: dataStore.userProfile)
    }
    
    var consumedCalories: Double {
        dataStore.totalCalories(for: dataStore.selectedDate)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .padding(.top, 24)
                
                Text("Great Job Today!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                
                VStack(spacing: 12) {
                    HStack {
                        Text("Calories Consumed")
                        Spacer()
                        Text("\(Int(consumedCalories)) / \(Int(macroTargets.calories)) kcal")
                            .bold()
                    }
                    Divider()
                    HStack {
                        Text("Protein")
                        Spacer()
                        Text("\(Int(dataStore.totalProtein(for: dataStore.selectedDate))) / \(Int(macroTargets.proteinGrams))g")
                            .bold()
                    }
                    Divider()
                    HStack {
                        Text("Carbs")
                        Spacer()
                        Text("\(Int(dataStore.totalCarbs(for: dataStore.selectedDate))) / \(Int(macroTargets.carbsGrams))g")
                            .bold()
                    }
                    Divider()
                    HStack {
                        Text("Fat")
                        Spacer()
                        Text("\(Int(dataStore.totalFat(for: dataStore.selectedDate))) / \(Int(macroTargets.fatGrams))g")
                            .bold()
                    }
                }
                .padding(20)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(18)
                .padding(.horizontal)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Text("Done")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .cornerRadius(16)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Day Complete")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}
