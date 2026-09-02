//
//  AIEstimateResultSheet.swift
//  track yo calories
//

import SwiftUI

struct AIEstimateResultSheet: View {
    @ObservedObject var dataStore: DataStore
    let initialEstimate: AIFoodEstimate
    var preselectedMeal: MealType = .breakfast
    var targetDate: Date = Date()
    var onLogged: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedMeal: MealType
    @State private var mealTitle: String
    @State private var items: [AIFoodItemEstimate]
    
    // Manual item editing
    @State private var editingItemId: UUID? = nil
    @State private var showAddItemSheet: Bool = false
    @State private var newItemName: String = ""
    @State private var newItemCalories: String = ""
    @State private var newItemProtein: String = ""
    @State private var newItemCarbs: String = ""
    @State private var newItemFat: String = ""
    @State private var newItemGrams: String = "100"
    
    init(
        dataStore: DataStore,
        estimate: AIFoodEstimate,
        preselectedMeal: MealType = .breakfast,
        targetDate: Date = Date(),
        onLogged: (() -> Void)? = nil
    ) {
        self.dataStore = dataStore
        self.initialEstimate = estimate
        self.preselectedMeal = preselectedMeal
        self.targetDate = targetDate
        self.onLogged = onLogged
        
        self._selectedMeal = State(initialValue: preselectedMeal)
        self._mealTitle = State(initialValue: estimate.mealName)
        self._items = State(initialValue: estimate.items.isEmpty ? [
            AIFoodItemEstimate(
                name: estimate.foodName,
                calories: estimate.calories,
                protein: estimate.protein,
                carbs: estimate.carbs,
                fat: estimate.fat,
                portionDescription: estimate.servingDescription,
                gramWeight: max(10.0, estimate.estimatedGrams)
            )
        ] : estimate.items)
    }
    
    private var totalCalories: Double {
        items.reduce(0.0) { $0 + $1.calories }
    }
    
    private var totalProtein: Double {
        items.reduce(0.0) { $0 + $1.protein }
    }
    
    private var totalCarbs: Double {
        items.reduce(0.0) { $0 + $1.carbs }
    }
    
    private var totalFat: Double {
        items.reduce(0.0) { $0 + $1.fat }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 20) {
                        // Top Summary Card
                        mealSummaryCard
                        
                        // Separated Items Section
                        itemsListSection
                        
                        // Add Another Item Button
                        Button {
                            showAddItemSheet = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Add Another Item")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.orange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.orange.opacity(0.12))
                            .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        
                        // Bottom spacing for sticky action button
                        Spacer()
                            .frame(height: 90)
                    }
                    .padding(.vertical, 16)
                }
                
                // Sticky Log Button
                bottomActionBar
            }
            .navigationTitle("Review Estimated Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
                }
            }
            .sheet(isPresented: $showAddItemSheet) {
                addItemSheet
            }
        }
    }
    
    // MARK: - Meal Summary Card
    private var mealSummaryCard: some View {
        VStack(spacing: 14) {
            // Meal destination picker
            // Header Row: "Log to Meal" & Item Count
            HStack {
                Text("Log to Meal")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(items.count) \(items.count == 1 ? "item" : "items") found")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(10)
            }
            
            // Segmented Meal Selector: completely smooth, zero jumping
            Picker("Meal", selection: $selectedMeal) {
                ForEach(MealType.allCases) { meal in
                    Text(meal.displayName).tag(meal)
                }
            }
            .pickerStyle(.segmented)
            
            Divider()
            
            // Total Calories & Macros
            VStack(spacing: 6) {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(Int(totalCalories.rounded()))")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                    Text("kcal total")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                // Macro Pills
                HStack(spacing: 12) {
                    macroTotalPill(label: "Protein", value: totalProtein, color: .red)
                    macroTotalPill(label: "Carbs", value: totalCarbs, color: .blue)
                    macroTotalPill(label: "Fat", value: totalFat, color: .orange)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(18)
        .padding(.horizontal)
    }
    
    private func macroTotalPill(label: String, value: Double, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(label):")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Text(String(format: "%.1fg", value))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(0.08))
        .cornerRadius(8)
    }
    
    // MARK: - Items List Section
    private var itemsListSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("SEPARATED INGREDIENTS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Adjust each below")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            
            ForEach(items.indices, id: \.self) { idx in
                itemCard(index: idx)
            }
        }
    }
    
    // MARK: - Item Card Component
    private func itemCard(index: Int) -> some View {
        let item = items[index]
        
        return VStack(spacing: 12) {
            // Header Row: Emoji, Name, Delete
            HStack(spacing: 10) {
                Text(foodEmoji(for: item.name))
                    .font(.system(size: 24))
                    .frame(width: 32)
                
                TextField("Ingredient Name", text: Binding(
                    get: { self.items[index].name },
                    set: { self.items[index].name = $0 }
                ))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.primary)
                
                Spacer()
                
                if items.count > 1 {
                    Button {
                        withAnimation {
                            _ = self.items.remove(at: index)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Portion description & Calories row
            HStack {
                Text(item.portionDescription)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Button {
                        adjustCalories(index: index, delta: -10)
                    } label: {
                        Text("-10")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    Text("\(Int(item.calories.rounded())) kcal")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Button {
                        adjustCalories(index: index, delta: 10)
                    } label: {
                        Text("+10")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Divider()
            
            // Macro Steppers for this item
            HStack(spacing: 8) {
                macroStepper(label: "Protein", color: .red, value: item.protein) { delta in
                    items[index].protein = max(0.0, (items[index].protein + delta).rounded(toPlaces: 1))
                }
                
                macroStepper(label: "Carbs", color: .blue, value: item.carbs) { delta in
                    items[index].carbs = max(0.0, (items[index].carbs + delta).rounded(toPlaces: 1))
                }
                
                macroStepper(label: "Fat", color: .orange, value: item.fat) { delta in
                    items[index].fat = max(0.0, (items[index].fat + delta).rounded(toPlaces: 1))
                }
            }
            
            // Portion Weight Stepper
            HStack {
                Text("Portion Weight")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button {
                        adjustWeight(index: index, delta: -10)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    
                    Text("\(Int(item.gramWeight))g")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .frame(minWidth: 44, alignment: .center)
                    
                    Button {
                        adjustWeight(index: index, delta: 10)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(10)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .padding(.horizontal)
    }
    
    private func macroStepper(label: String, color: Color, value: Double, onAdjust: @escaping (Double) -> Void) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                Button {
                    onAdjust(-1.0)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                Text(String(format: "%.1fg", value))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .frame(minWidth: 38, alignment: .center)
                
                Button {
                    onAdjust(1.0)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(color.opacity(0.06))
        .cornerRadius(10)
    }
    
    private func adjustCalories(index: Int, delta: Double) {
        let current = items[index].calories
        items[index].calories = max(0.0, current + delta)
    }
    
    private func adjustWeight(index: Int, delta: Double) {
        let oldGrams = items[index].gramWeight
        let newGrams = max(5.0, oldGrams + delta)
        let ratio = newGrams / oldGrams
        
        items[index].gramWeight = newGrams
        items[index].calories = max(0.0, (items[index].calories * ratio).rounded())
        items[index].protein = max(0.0, (items[index].protein * ratio).rounded(toPlaces: 1))
        items[index].carbs = max(0.0, (items[index].carbs * ratio).rounded(toPlaces: 1))
        items[index].fat = max(0.0, (items[index].fat * ratio).rounded(toPlaces: 1))
    }
    
    // MARK: - Sticky Bottom Action Bar
    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            Button {
                logSeparatedItems()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                    
                    if items.count == 1 {
                        Text("Log to \(selectedMeal.displayName) · \(Int(totalCalories.rounded())) kcal")
                    } else {
                        Text("Log \(items.count) Items to \(selectedMeal.displayName) · \(Int(totalCalories.rounded())) kcal")
                    }
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.orange)
                .cornerRadius(16)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .buttonStyle(.plain)
            .background(.ultraThinMaterial)
        }
    }
    
    // MARK: - Logging Action (Separate Entries into Meal)
    private func logSeparatedItems() {
        for item in items {
            let foodItem = item.toFoodItem()
            let serving = foodItem.servingOptions.first(where: { $0.isDefault }) ?? ServingOption.grams(item.gramWeight)
            dataStore.logFood(
                food: foodItem,
                mealType: selectedMeal,
                serving: serving,
                quantity: 1.0,
                date: targetDate
            )
        }
        
        onLogged?()
        dismiss()
    }
    
    // MARK: - Add Item Modal
    private var addItemSheet: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Name (e.g. Toast, Butter)", text: $newItemName)
                    TextField("Calories (kcal)", text: $newItemCalories)
                        .keyboardType(.numberPad)
                    TextField("Portion Weight (g)", text: $newItemGrams)
                        .keyboardType(.numberPad)
                }
                
                Section("Macros (Optional)") {
                    TextField("Protein (g)", text: $newItemProtein)
                        .keyboardType(.decimalPad)
                    TextField("Carbs (g)", text: $newItemCarbs)
                        .keyboardType(.decimalPad)
                    TextField("Fat (g)", text: $newItemFat)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Add Food Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showAddItemSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let cals = Double(newItemCalories) ?? 100.0
                        let p = Double(newItemProtein) ?? 0.0
                        let c = Double(newItemCarbs) ?? 0.0
                        let f = Double(newItemFat) ?? 0.0
                        let g = Double(newItemGrams) ?? 100.0
                        let name = newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Custom Food" : newItemName
                        
                        let item = AIFoodItemEstimate(
                            name: name,
                            calories: cals,
                            protein: p,
                            carbs: c,
                            fat: f,
                            portionDescription: "1 serving (\(Int(g))g)",
                            gramWeight: g
                        )
                        items.append(item)
                        newItemName = ""
                        newItemCalories = ""
                        newItemProtein = ""
                        newItemCarbs = ""
                        newItemFat = ""
                        newItemGrams = "100"
                        showAddItemSheet = false
                    }
                    .disabled(newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func foodEmoji(for name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("egg") { return "🥚" }
        if lower.contains("bacon") || lower.contains("pork") || lower.contains("ham") { return "🥓" }
        if lower.contains("oil") || lower.contains("olive") { return "🫒" }
        if lower.contains("bread") || lower.contains("toast") { return "🍞" }
        if lower.contains("croissant") { return "🥐" }
        if lower.contains("butter") || lower.contains("cheese") { return "🧀" }
        if lower.contains("chicken") || lower.contains("poultry") { return "🍗" }
        if lower.contains("beef") || lower.contains("steak") || lower.contains("meat") { return "🥩" }
        if lower.contains("rice") { return "🍚" }
        if lower.contains("salad") || lower.contains("lettuce") || lower.contains("spinach") { return "🥗" }
        if lower.contains("avocado") { return "🥑" }
        if lower.contains("coffee") { return "☕️" }
        if lower.contains("milk") || lower.contains("yogurt") { return "🥛" }
        if lower.contains("apple") { return "🍎" }
        if lower.contains("banana") { return "🍌" }
        if lower.contains("fish") || lower.contains("salmon") || lower.contains("tuna") { return "🐟" }
        if lower.contains("potato") || lower.contains("fries") { return "🥔" }
        if lower.contains("pasta") || lower.contains("spaghetti") { return "🍝" }
        if lower.contains("pizza") { return "🍕" }
        if lower.contains("burger") { return "🍔" }
        return "🍽️"
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
