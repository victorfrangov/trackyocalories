//
//  FoodSearchView.swift
//  track yo calories
//

import SwiftUI

struct FoodSearchView: View {
    @ObservedObject var dataStore: DataStore
    var targetDate: Date

    @Environment(\.dismiss) private var dismiss

    @State private var meal: MealType
    @State private var scope: Scope = .recent
    @State private var searchText: String = ""
    @State private var localResults: [FoodItem] = []
    @State private var onlineResults: [FoodItem] = []
    @State private var isSearchingOnline: Bool = false
    @State private var onlineSearchFailed: Bool = false

    @State private var selectedFood: FoodItem? = nil
    @State private var activeSheet: ToolSheet? = nil
    @State private var pendingMealGroup: RecentMealGroup? = nil
    @State private var lastAdded: (id: UUID, message: String)? = nil

    enum Scope: String, CaseIterable, Identifiable {
        case recent = "Recent"
        case favorites = "Favorites"
        case myFoods = "My Foods"
        var id: String { rawValue }
    }

    enum ToolSheet: String, Identifiable {
        case barcode, photo, describe, quickAdd, createFood
        var id: String { rawValue }
    }

    init(dataStore: DataStore, preselectedMeal: MealType = .breakfast, targetDate: Date = Date()) {
        self.dataStore = dataStore
        self.targetDate = targetDate
        self._meal = State(initialValue: preselectedMeal)
    }

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Recipes and custom foods. Older versions saved each recipe twice, so dedupe by id.
    private var myFoods: [FoodItem] {
        var seen = Set<UUID>()
        return (dataStore.recipes.map { $0.toFoodItem() } + dataStore.customFoods).filter { seen.insert($0.id).inserted }
    }

    var body: some View {
        NavigationStack {
            List {
                if trimmedQuery.isEmpty {
                    toolsSection

                    Section {
                        Picker("Show", selection: $scope) {
                            ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    switch scope {
                    case .recent: recentContent
                    case .favorites: favoritesContent
                    case .myFoods: myFoodsContent
                    }
                } else {
                    searchResultsContent
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search foods & brands")
            .autocorrectionDisabled()
            .task(id: trimmedQuery) {
                await runSearch(trimmedQuery)
            }
            .navigationTitle("Add to \(meal.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarTitleMenu {
                Picker("Meal", selection: $meal) {
                    ForEach(MealType.allCases) { m in
                        Label(m.displayName, systemImage: m.iconName).tag(m)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let lastAdded {
                    BannerView(message: lastAdded.message, actionTitle: "Undo") {
                        dataStore.deleteEntry(id: lastAdded.id)
                        dataStore.dismissUndo()
                        withAnimation { self.lastAdded = nil }
                    }
                    .task(id: lastAdded.id) {
                        try? await Task.sleep(for: .seconds(4))
                        withAnimation { self.lastAdded = nil }
                    }
                }
            }
            .sheet(item: $selectedFood) { food in
                FoodDetailView(
                    food: food,
                    dataStore: dataStore,
                    targetMeal: meal,
                    targetDate: targetDate,
                    onLogged: { dismiss() }
                )
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .barcode:
                    BarcodeScannerView(dataStore: dataStore, targetMeal: meal, targetDate: targetDate)
                case .photo:
                    AIFoodScannerView(dataStore: dataStore, targetMeal: meal, targetDate: targetDate, onLogged: { dismiss() })
                case .describe:
                    DescribeMealSheet(dataStore: dataStore, meal: meal, targetDate: targetDate, onLogged: { dismiss() })
                case .quickAdd:
                    QuickAddView(dataStore: dataStore, preselectedMeal: meal, targetDate: targetDate)
                case .createFood:
                    CreateFoodView(dataStore: dataStore)
                }
            }
            .confirmationDialog(
                pendingMealGroup.map { "Add \($0.entries.count) foods (\($0.totalCalories.roundedString) kcal) to \(meal.displayName)?" } ?? "",
                isPresented: Binding(get: { pendingMealGroup != nil }, set: { if !$0 { pendingMealGroup = nil } }),
                titleVisibility: .visible
            ) {
                Button("Add All") {
                    if let group = pendingMealGroup { logMealGroup(group) }
                }
            } message: {
                if let group = pendingMealGroup {
                    Text(group.subtitle)
                }
            }
        }
    }

    // MARK: - Tools
    private var toolsSection: some View {
        Section {
            HStack(spacing: 8) {
                toolButton("Barcode", systemImage: "barcode.viewfinder", sheet: .barcode)
                toolButton("Photo", systemImage: "camera", sheet: .photo)
                toolButton("Describe", systemImage: "text.bubble", sheet: .describe)
                toolButton("Quick Add", systemImage: "bolt", sheet: .quickAdd)
            }
            .padding(.vertical, 4)
        } footer: {
            Text("Photo and Describe use Gemini AI to estimate calories.")
        }
    }

    private func toolButton(_ title: String, systemImage: String, sheet: ToolSheet) -> some View {
        Button {
            activeSheet = sheet
        } label: {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.title3)
                    .frame(height: 24)
                Text(title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.bordered)
        .tint(.accentColor)
    }

    // MARK: - Scope Contents
    @ViewBuilder
    private var recentContent: some View {
        let groups = recentMealGroups()
        if !groups.isEmpty {
            Section("Recent Meals") {
                ForEach(groups) { group in
                    Button {
                        pendingMealGroup = group
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(group.title)
                                Text(group.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text("\(group.totalCalories.roundedString) kcal")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .foregroundStyle(.primary)
                }
            }
        }

        Section("Recent Foods") {
            if dataStore.recentFoods.isEmpty {
                ContentUnavailableView(
                    "No Recent Foods",
                    systemImage: "clock",
                    description: Text("Search above or scan a barcode. Foods you log will show up here.")
                )
            } else {
                ForEach(dataStore.recentFoods) { foodRow($0) }
            }
        }
    }

    @ViewBuilder
    private var favoritesContent: some View {
        Section {
            if dataStore.favoriteFoods.isEmpty {
                ContentUnavailableView(
                    "No Favorites",
                    systemImage: "heart",
                    description: Text("Tap the heart on any food to keep it here.")
                )
            } else {
                ForEach(dataStore.favoriteFoods) { item in
                    foodRow(item)
                        .swipeActions {
                            Button("Remove", role: .destructive) {
                                dataStore.toggleFavorite(item)
                            }
                        }
                }
            }
        }
    }

    @ViewBuilder
    private var myFoodsContent: some View {
        Section {
            Button {
                activeSheet = .createFood
            } label: {
                Label("Create Food or Recipe", systemImage: "plus.circle.fill")
            }

            ForEach(myFoods) { item in
                foodRow(item)
                    .swipeActions {
                        Button("Delete", role: .destructive) {
                            if dataStore.recipes.contains(where: { $0.id == item.id }) {
                                dataStore.deleteRecipe(id: item.id)
                            } else {
                                dataStore.deleteCustomFood(id: item.id)
                            }
                        }
                    }
            }
        } footer: {
            if myFoods.isEmpty {
                Text("Foods and recipes you create appear here. You can also save any logged meal as a recipe from the Diary.")
            }
        }
    }

    // MARK: - Search Results
    @ViewBuilder
    private var searchResultsContent: some View {
        let q = trimmedQuery
        let mine = (myFoods + dataStore.favoriteFoods).filter {
            $0.name.localizedCaseInsensitiveContains(q) || ($0.brand?.localizedCaseInsensitiveContains(q) ?? false)
        }
        let mineUnique = mine.reduce(into: [FoodItem]()) { acc, f in
            if !acc.contains(where: { $0.id == f.id }) { acc.append(f) }
        }

        if !mineUnique.isEmpty {
            Section("My Foods") {
                ForEach(mineUnique) { foodRow($0) }
            }
        }

        if !localResults.isEmpty {
            Section("Food Database") {
                ForEach(localResults) { foodRow($0) }
            }
        }

        Section {
            if isSearchingOnline {
                HStack {
                    ProgressView()
                    Text("Searching Open Food Facts…")
                        .foregroundStyle(.secondary)
                        .padding(.leading, 6)
                }
            } else if onlineSearchFailed {
                Label("Couldn’t reach Open Food Facts. Check your connection.", systemImage: "wifi.exclamationmark")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(onlineResults) { foodRow($0) }
            }
        } header: {
            if isSearchingOnline || onlineSearchFailed || !onlineResults.isEmpty {
                Text("Packaged Products")
            }
        }

        if mineUnique.isEmpty && localResults.isEmpty && onlineResults.isEmpty && !isSearchingOnline {
            Section {
                ContentUnavailableView.search(text: q)
                Button {
                    activeSheet = .createFood
                } label: {
                    Label("Create “\(q)”", systemImage: "plus.circle")
                }
                Button {
                    activeSheet = .describe
                } label: {
                    Label("Estimate with AI", systemImage: "sparkles")
                }
            }
        }
    }

    // MARK: - Row
    private func foodRow(_ item: FoodItem) -> some View {
        let serving = item.defaultServing
        let kcal = item.nutrients(for: serving, quantity: 1).calories
        let subtitle = [item.brand, serving.name].compactMap { $0?.isEmpty == false ? $0 : nil }.joined(separator: " · ")

        return HStack(spacing: 12) {
            Button {
                selectedFood = item
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.name)
                            .lineLimit(2)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Text("\(kcal.roundedString) kcal")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                quickLog(item)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Add \(item.name) to \(meal.displayName)")
        }
    }

    // MARK: - Actions
    private func quickLog(_ item: FoodItem) {
        let id = dataStore.logFood(food: item, mealType: meal, serving: item.defaultServing, quantity: 1, date: targetDate)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation {
            lastAdded = (id, "Added \(item.name) to \(meal.displayName)")
        }
    }

    private func runSearch(_ query: String) async {
        guard !query.isEmpty else {
            localResults = []
            onlineResults = []
            isSearchingOnline = false
            onlineSearchFailed = false
            return
        }

        // Debounce typing; the task is cancelled when the query changes.
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        localResults = LocalFoodDatabaseService.shared.search(query: query)

        guard query.count >= 3 else {
            onlineResults = []
            return
        }
        isSearchingOnline = true
        onlineSearchFailed = false
        defer { if !Task.isCancelled { isSearchingOnline = false } }
        do {
            let results = try await OpenFoodFactsService.shared.searchProducts(query: query)
            guard !Task.isCancelled else { return }
            let localNames = Set(localResults.map { $0.name.lowercased() })
            onlineResults = results.filter { !localNames.contains($0.name.lowercased()) }
        } catch {
            guard !Task.isCancelled else { return }
            onlineResults = []
            onlineSearchFailed = true
        }
    }

    struct RecentMealGroup: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let totalCalories: Double
        let entries: [LoggedEntry]
    }

    /// The last few distinct meals (day + meal), newest first. Meals with a single food are
    /// skipped since those foods are already one tap away in Recent Foods.
    private func recentMealGroups(limit: Int = 4) -> [RecentMealGroup] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: dataStore.loggedEntries) { entry in
            "\(calendar.startOfDay(for: entry.date).timeIntervalSinceReferenceDate)-\(entry.mealType.rawValue)"
        }
        return grouped
            .filter { $0.value.count > 1 }
            .sorted { ($0.value.first?.date ?? .distantPast) > ($1.value.first?.date ?? .distantPast) }
            .prefix(limit)
            .map { key, items in
                let day = items[0].date
                let dayText: String
                if calendar.isDateInToday(day) { dayText = "Today" }
                else if calendar.isDateInYesterday(day) { dayText = "Yesterday" }
                else { dayText = day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) }
                return RecentMealGroup(
                    id: key,
                    title: "\(items[0].mealType.displayName) · \(dayText)",
                    subtitle: items.map(\.food.name).joined(separator: ", "),
                    totalCalories: items.reduce(0) { $0 + $1.calories },
                    entries: items
                )
            }
    }

    private func logMealGroup(_ group: RecentMealGroup) {
        for entry in group.entries {
            dataStore.logFood(food: entry.food, mealType: meal, serving: entry.servingOption, quantity: entry.quantity, date: targetDate)
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        pendingMealGroup = nil
        dismiss()
    }
}

// MARK: - Describe a Meal (AI)
/// Type one food per line ("2 eggs", "toast with butter"); Return moves to a new line.
struct DescribeMealSheet: View {
    @ObservedObject var dataStore: DataStore
    let meal: MealType
    let targetDate: Date
    var onLogged: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var lines: [String] = [""]
    @FocusState private var focusedLine: Int?
    @State private var isEstimating: Bool = false
    @State private var estimate: AIFoodEstimate? = nil
    @State private var errorMessage: String? = nil
    @State private var showApiKeySheet: Bool = false
    @State private var estimateTask: Task<Void, Never>? = nil

    private var items: [String] {
        lines.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private var hasKey: Bool {
        !(dataStore.userProfile.geminiApiKey ?? "").trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(lines.indices, id: \.self) { idx in
                        TextField(idx == 0 ? "e.g. 2 scrambled eggs" : "Another food", text: Binding(
                            get: { idx < lines.count ? lines[idx] : "" },
                            set: { if idx < lines.count { lines[idx] = $0 } }
                        ))
                        .focused($focusedLine, equals: idx)
                        .submitLabel(.next)
                        .onSubmit { addLine(after: idx) }
                    }
                    .onDelete { offsets in
                        lines.remove(atOffsets: offsets)
                        if lines.isEmpty { lines = [""] }
                    }

                    Button {
                        addLine(after: lines.count - 1)
                    } label: {
                        Label("Add Line", systemImage: "plus")
                    }
                } header: {
                    Text("What did you eat?")
                } footer: {
                    Text("One food per line, with amounts if you know them. You can review and adjust every item before it’s added to \(meal.displayName).")
                }

                if !hasKey {
                    Section {
                        Button("Set Up Gemini API Key") { showApiKeySheet = true }
                    } footer: {
                        Text("AI estimates need a free Google Gemini API key.")
                    }
                }
            }
            .navigationTitle("Describe Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        estimateTask?.cancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isEstimating {
                        ProgressView()
                    } else {
                        Button("Estimate") { runEstimate() }
                            .disabled(items.isEmpty)
                    }
                }
            }
            .onAppear { focusedLine = 0 }
            .sheet(item: $estimate) { result in
                AIEstimateResultSheet(
                    dataStore: dataStore,
                    estimate: result,
                    preselectedMeal: meal,
                    targetDate: targetDate,
                    onLogged: {
                        dismiss()
                        onLogged?()
                    }
                )
            }
            .sheet(isPresented: $showApiKeySheet) {
                ApiKeySetupSheet(dataStore: dataStore)
            }
            .alert("Couldn’t Estimate Meal", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func addLine(after idx: Int) {
        if idx == lines.count - 1 {
            lines.append("")
        }
        focusedLine = idx + 1
    }

    private func runEstimate() {
        guard let key = dataStore.userProfile.geminiApiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
            showApiKeySheet = true
            return
        }
        focusedLine = nil
        isEstimating = true
        let prompt = items.joined(separator: ", ")
        estimateTask = Task {
            do {
                let result = try await AIFoodScannerService.shared.analyzeFoodDescription(text: prompt, apiKey: key)
                guard !Task.isCancelled else { return }
                estimate = result
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = error.localizedDescription
            }
            isEstimating = false
        }
    }
}
