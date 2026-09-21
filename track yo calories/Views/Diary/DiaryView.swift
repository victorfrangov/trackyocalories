//
//  DiaryView.swift
//  track yo calories
//

import SwiftUI

struct DiaryView: View {
    @ObservedObject var dataStore: DataStore

    @State private var activeSheet: DiarySheet? = nil
    @State private var showCalendar: Bool = false
    @State private var recipeMeal: MealType? = nil
    @State private var recipeTitle: String = ""
    @State private var toastMessage: String? = nil

    enum DiarySheet: Identifiable {
        case search(MealType)
        case barcode(MealType)
        case photo(MealType)
        case quickAdd(MealType)
        case nutrients
        case edit(LoggedEntry)

        var id: String {
            switch self {
            case .search(let m): return "search-\(m.rawValue)"
            case .barcode(let m): return "barcode-\(m.rawValue)"
            case .photo(let m): return "photo-\(m.rawValue)"
            case .quickAdd(let m): return "quick-\(m.rawValue)"
            case .nutrients: return "nutrients"
            case .edit(let entry): return "edit-\(entry.id)"
            }
        }
    }

    private var date: Date { dataStore.selectedDate }

    private var macroTargets: MacroTargets {
        NutritionEngine.calculateMacroTargets(profile: dataStore.userProfile)
    }

    private var titleText: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    /// Meal used by the global "+" menu, based on the time of day.
    private var defaultMeal: MealType {
        MealType.suggested()
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    WeekStripView(selectedDate: $dataStore.selectedDate, loggedDays: dataStore.loggedDays)
                }
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)

                Section {
                    DailySummaryView(
                        budget: macroTargets.calories,
                        consumed: dataStore.totalCalories(for: date),
                        weeklyAverage: dataStore.weeklyAverageCalories(for: date),
                        protein: dataStore.totalProtein(for: date),
                        proteinTarget: macroTargets.proteinGrams,
                        carbs: dataStore.totalCarbs(for: date),
                        carbsTarget: macroTargets.carbsGrams,
                        fat: dataStore.totalFat(for: date),
                        fatTarget: macroTargets.fatGrams
                    )

                    Button {
                        activeSheet = .nutrients
                    } label: {
                        HStack {
                            Label("Nutrition Details", systemImage: "list.bullet.clipboard")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                }

                ForEach(MealType.allCases) { meal in
                    mealSection(meal)
                }

                Section("Water") {
                    WaterTrackerView(dataStore: dataStore)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(titleText)
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .bottom) { bannerView }
            .sheet(item: $activeSheet) { sheet in
                sheetContent(sheet)
            }
            .sheet(isPresented: $showCalendar) {
                CalendarPickerSheet(selectedDate: $dataStore.selectedDate, loggedDays: dataStore.loggedDays)
            }
            .alert("Save Meal as Recipe", isPresented: Binding(
                get: { recipeMeal != nil },
                set: { if !$0 { recipeMeal = nil } }
            )) {
                TextField("Recipe name", text: $recipeTitle)
                Button("Save") {
                    if let meal = recipeMeal { saveMealAsRecipe(meal) }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Saves every food in this meal as one reusable recipe.")
            }
        }
    }

    // MARK: - Meal Section
    @ViewBuilder
    private func mealSection(_ meal: MealType) -> some View {
        let entries = dataStore.entries(for: date, meal: meal)
        let budget = NutritionEngine.calculateMealBudgets(profile: dataStore.userProfile)
            .first(where: { $0.mealType == meal })?.calories ?? 0

        Section {
            ForEach(entries) { entry in
                Button {
                    activeSheet = .edit(entry)
                } label: {
                    FoodEntryRow(entry: entry)
                }
                .foregroundStyle(.primary)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        withAnimation { dataStore.deleteEntry(id: entry.id) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu {
                    Button {
                        activeSheet = .edit(entry)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        withAnimation { dataStore.deleteEntry(id: entry.id) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            Button {
                activeSheet = .search(meal)
            } label: {
                Label("Add Food", systemImage: "plus.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        } header: {
            MealHeaderView(
                meal: meal,
                consumed: entries.reduce(0) { $0 + $1.calories },
                budget: budget,
                hasEntries: !entries.isEmpty,
                onCopyYesterday: { copyFromYesterday(meal) },
                onSaveRecipe: {
                    recipeTitle = "\(meal.displayName) \(date.formatted(.dateTime.month(.abbreviated).day()))"
                    recipeMeal = meal
                },
                onClear: { withAnimation { dataStore.clearMeal(mealType: meal, on: date) } }
            )
        } footer: {
            if !entries.isEmpty {
                let p = entries.reduce(0) { $0 + $1.protein }
                let c = entries.reduce(0) { $0 + $1.carbs }
                let f = entries.reduce(0) { $0 + $1.fat }
                Text("Protein \(p.roundedString) g · Carbs \(c.roundedString) g · Fat \(f.roundedString) g")
            }
        }
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            let streak = dataStore.currentStreak
            if streak > 0 {
                Label("\(streak) day streak", systemImage: "flame.fill")
                    .labelStyle(StreakLabelStyle())
                    .accessibilityLabel("\(streak) day logging streak")
            }
        }

        ToolbarItemGroup(placement: .topBarTrailing) {
            if !Calendar.current.isDateInToday(date) {
                Button("Today") {
                    withAnimation { dataStore.selectedDate = Date() }
                }
            }

            Button {
                showCalendar = true
            } label: {
                Label("Choose Date", systemImage: "calendar")
            }

            Menu {
                let meal = defaultMeal
                Section("Add to \(meal.displayName)") {
                    Button { activeSheet = .search(meal) } label: {
                        Label("Search Foods", systemImage: "magnifyingglass")
                    }
                    Button { activeSheet = .barcode(meal) } label: {
                        Label("Scan Barcode", systemImage: "barcode.viewfinder")
                    }
                    Button { activeSheet = .photo(meal) } label: {
                        Label("Photo (AI Estimate)", systemImage: "camera")
                    }
                    Button { activeSheet = .quickAdd(meal) } label: {
                        Label("Quick Add Calories", systemImage: "bolt")
                    }
                }
            } label: {
                Label("Add", systemImage: "plus")
            }
        }
    }

    // MARK: - Sheets
    @ViewBuilder
    private func sheetContent(_ sheet: DiarySheet) -> some View {
        switch sheet {
        case .search(let meal):
            FoodSearchView(dataStore: dataStore, preselectedMeal: meal, targetDate: date)
        case .barcode(let meal):
            BarcodeScannerView(dataStore: dataStore, targetMeal: meal, targetDate: date)
        case .photo(let meal):
            AIFoodScannerView(dataStore: dataStore, targetMeal: meal, targetDate: date)
        case .quickAdd(let meal):
            QuickAddView(dataStore: dataStore, preselectedMeal: meal, targetDate: date)
        case .nutrients:
            MicronutrientDetailView(dataStore: dataStore)
        case .edit(let entry):
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

    // MARK: - Banner (Undo / confirmations)
    @ViewBuilder
    private var bannerView: some View {
        if let undo = dataStore.undoAction {
            BannerView(message: undo.message, actionTitle: "Undo") {
                withAnimation { dataStore.undo() }
            }
            .task(id: undo.id) {
                try? await Task.sleep(for: .seconds(5))
                withAnimation { dataStore.dismissUndo(undo.id) }
            }
        } else if let message = toastMessage {
            BannerView(message: message, actionTitle: nil, action: nil)
                .task(id: message) {
                    try? await Task.sleep(for: .seconds(3))
                    withAnimation { toastMessage = nil }
                }
        }
    }

    // MARK: - Actions
    private func copyFromYesterday(_ meal: MealType) {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date) else { return }
        let count = withAnimation {
            dataStore.duplicateMeal(mealType: meal, from: yesterday, to: date)
        }
        withAnimation {
            toastMessage = count == 0
                ? "Nothing was logged for \(meal.displayName.lowercased()) the day before"
                : "Copied \(count) food\(count == 1 ? "" : "s") to \(meal.displayName)"
        }
    }

    private func saveMealAsRecipe(_ meal: MealType) {
        let entries = dataStore.entries(for: date, meal: meal)
        guard !entries.isEmpty else { return }
        let ingredients = entries.map {
            RecipeIngredient(food: $0.food, servingOption: $0.servingOption, quantity: $0.quantity)
        }
        let trimmed = recipeTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let recipe = Recipe(
            name: trimmed.isEmpty ? "\(meal.displayName) Recipe" : trimmed,
            servings: 1,
            ingredients: ingredients
        )
        dataStore.addRecipe(recipe)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { toastMessage = "Saved “\(recipe.name)” to My Foods" }
        recipeMeal = nil
    }
}

// MARK: - Meal Header
struct MealHeaderView: View {
    let meal: MealType
    let consumed: Double
    let budget: Double
    let hasEntries: Bool
    var onCopyYesterday: () -> Void
    var onSaveRecipe: () -> Void
    var onClear: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Label(meal.displayName, systemImage: meal.iconName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(.label))
                .labelStyle(MealLabelStyle(color: meal.themeColor))

            Spacer()

            Text("\(consumed.roundedString) / \(budget.roundedString) kcal")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(consumed > budget * 1.1 && budget > 0 ? Color.red : Color.secondary)

            Menu {
                Button(action: onCopyYesterday) {
                    Label("Copy from Previous Day", systemImage: "doc.on.doc")
                }
                if hasEntries {
                    Button(action: onSaveRecipe) {
                        Label("Save as Recipe", systemImage: "book.closed")
                    }
                    Button(role: .destructive, action: onClear) {
                        Label("Clear \(meal.displayName)", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .frame(minWidth: 44, minHeight: 32)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("\(meal.displayName) options")
        }
        .textCase(nil)
    }
}

private struct MealLabelStyle: LabelStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
                .font(.subheadline)
                .foregroundStyle(color)
            configuration.title
        }
    }
}

private struct StreakLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.foregroundStyle(.orange)
            configuration.title
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
    }
}

// MARK: - Food Entry Row
struct FoodEntryRow: View {
    let entry: LoggedEntry

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.food.name)
                    .font(.body)
                    .lineLimit(2)
                Text("\(entry.portionDescription) · P \(entry.protein.roundedString) · C \(entry.carbs.roundedString) · F \(entry.fat.roundedString)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(entry.calories.roundedString)
                .font(.body.weight(.semibold).monospacedDigit())
            + Text(" kcal")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the entry to edit")
    }
}

// MARK: - Banner
struct BannerView: View {
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.subheadline)
                .lineLimit(2)
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
